"""StartBacktestHandler — Command Bus handler for backtest execution."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from decimal import Decimal
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.ledger import ExecutionLedgerEvent
from app.domain.mtf_guard import MTFGuardBacktestStats
from app.models.strategy import BacktestRun
from app.repositories.ledger_repository import LedgerRepository
from app.services.backtest_runner import (
    FreqtradeBacktestRunner,
    BacktestResult,
    MTFGuardReplayEngine,
)
from app.workers.handlers import CommandHandler

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


class StartBacktestHandler(CommandHandler):
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        payload = command.payload
        dsl = payload["dsl"]
        timerange = payload["timerange"]
        symbols = payload.get("symbols", ["BTC/USDT"])
        initial_capital = payload.get("initial_capital", 10000)
        stake_amount = payload.get("stake_amount", 100)
        max_open_trades = payload.get("max_open_trades", 5)
        exchange = payload.get("exchange", "binance")
        fee = payload.get("fee")
        timeout_sec = command.timeout_sec or 600
        include_mtf_guard = payload.get("include_mtf_guard", False)

        run_id = str(command.id).replace("-", "")[:16]

        dates = timerange.split("-")
        start_date = f"{dates[0][:4]}-{dates[0][4:6]}-{dates[0][6:8]}" if len(dates) >= 1 else ""
        end_date = f"{dates[1][:4]}-{dates[1][4:6]}-{dates[1][6:8]}" if len(dates) >= 2 else ""

        backtest_run = BacktestRun(
            strategy_id=payload.get("strategy_id", 0),
            strategy_version_id=payload.get("strategy_version_id"),
            command_id=str(command.id),
            dsl_hash=payload.get("dsl_hash", ""),
            status="running",
            start_date=start_date,
            end_date=end_date,
            initial_capital=initial_capital,
            symbols=symbols,
            config={
                "timerange": timerange,
                "stake_amount": stake_amount,
                "max_open_trades": max_open_trades,
                "exchange": exchange,
                "fee": fee,
                "include_mtf_guard": include_mtf_guard,
            },
        )
        session.add(backtest_run)
        session.flush()

        ledger = LedgerRepository(session)
        self._write_ledger(
            ledger, command, "FREQTRADE_BACKTEST_STARTED",
            {"backtest_run_id": backtest_run.id, "timerange": timerange, "symbols": symbols},
        )

        runner = FreqtradeBacktestRunner()
        result = runner.run(
            dsl=dsl,
            timerange=timerange,
            symbols=symbols,
            initial_capital=initial_capital,
            stake_amount=stake_amount,
            max_open_trades=max_open_trades,
            exchange=exchange,
            fee=fee,
            timeout_sec=timeout_sec,
            run_id=run_id,
        )

        if result.success:
            self._handle_success(session, ledger, command, backtest_run, result)
        else:
            self._handle_failure(session, ledger, command, backtest_run, result)
            raise RuntimeError(result.error_message or "backtest failed")

        response = {
            "backtest_run_id": backtest_run.id,
            "total_trades": result.metrics.total_trades,
            "total_return_pct": result.metrics.total_return_pct,
            "sharpe_ratio": result.metrics.sharpe_ratio,
            "max_drawdown_pct": result.metrics.max_drawdown_pct,
            "win_rate": result.metrics.win_rate,
        }

        # ── MTF Guard Replay ──
        if include_mtf_guard and result.success and result.trades:
            try:
                mtf_guard_config = payload.get("mtf_guard_config", {})
                guard_stats = self._run_mtf_guard_replay(
                    session=session,
                    backtest_run=backtest_run,
                    trades=result.trades,
                    symbols=symbols,
                    mtf_guard_config=mtf_guard_config,
                )
                response["mtf_guard_stats"] = guard_stats
            except Exception:
                logger.exception(
                    "MTF Guard replay failed for backtest_run_id=%s",
                    backtest_run.id,
                )
                # Non-fatal: backtest itself succeeded

        return response

    def _run_mtf_guard_replay(
        self,
        session: Session,
        backtest_run: BacktestRun,
        trades: list[dict[str, Any]],
        symbols: list[str],
        mtf_guard_config: dict[str, Any],
    ) -> dict[str, Any]:
        """Run MTF Guard replay over trades and persist stats."""
        engine = MTFGuardReplayEngine()
        primary_symbol = symbols[0] if symbols else "BTC/USDT"

        fast_tf = mtf_guard_config.get("fast_timeframe", "5m")
        slow_tf = mtf_guard_config.get("slow_timeframe", "1h")
        zone_top = mtf_guard_config.get("zone_top", 0.0)
        zone_bottom = mtf_guard_config.get("zone_bottom", 0.0)
        zone_direction = mtf_guard_config.get("zone_direction", "bullish")

        replay = engine.replay(
            trades=trades,
            symbol=primary_symbol,
            fast_timeframe=fast_tf,
            slow_timeframe=slow_tf,
            zone_top=zone_top,
            zone_bottom=zone_bottom,
            zone_direction=zone_direction,
            guard_config=mtf_guard_config.get("guard_config"),
        )

        # Convert backtest_run.id (int) to a deterministic UUID for the FK
        backtest_uuid = uuid.uuid5(
            uuid.NAMESPACE_URL,
            f"backtest_run:{backtest_run.id}",
        )
        strategy_uuid = uuid.uuid5(
            uuid.NAMESPACE_URL,
            f"strategy:{backtest_run.strategy_id}",
        )

        stats_row = MTFGuardBacktestStats(
            id=uuid.uuid4(),
            backtest_id=backtest_uuid,
            strategy_id=strategy_uuid,
            symbol=primary_symbol,
            blocked_entries_count=replay.blocked_entries,
            reduced_size_count=replay.reduced_size,
            temporary_violation_count=replay.temporary_violation_count,
            reclaim_confirmed_count=replay.reclaim_confirmed_count,
            invalidated_count=replay.invalidated_count,
            pnl_delta=Decimal(str(round(replay.pnl_delta, 6))),
            max_drawdown_delta=Decimal(str(round(replay.max_drawdown_delta, 6))),
            false_breakout_avoided_count=replay.false_breakout_avoided_count,
        )
        session.add(stats_row)
        session.flush()

        # Store replay events in the backtest result JSON for retrieval
        existing_result = backtest_run.result or {}
        existing_result["mtf_guard_replay"] = {
            "stats_id": str(stats_row.id),
            "events": replay.replay_events,
            "summary": {
                "total_candles_evaluated": len(replay.replay_events),
                "violations_detected": replay.temporary_violation_count,
                "entries_blocked": replay.blocked_entries,
                "sizes_reduced": replay.reduced_size,
                "reclaims_confirmed": replay.reclaim_confirmed_count,
                "structures_invalidated": replay.invalidated_count,
                "false_breakouts_avoided": replay.false_breakout_avoided_count,
                "pnl_delta": replay.pnl_delta,
                "max_drawdown_delta": replay.max_drawdown_delta,
            },
        }
        backtest_run.result = existing_result
        session.flush()

        logger.info(
            "MTF Guard replay complete: backtest=%s blocked=%d avoided=%d pnl_delta=%.4f",
            backtest_run.id,
            replay.blocked_entries,
            replay.false_breakout_avoided_count,
            replay.pnl_delta,
        )

        return {
            "stats_id": str(stats_row.id),
            "blocked_entries": replay.blocked_entries,
            "reduced_size": replay.reduced_size,
            "temporary_violation_count": replay.temporary_violation_count,
            "reclaim_confirmed_count": replay.reclaim_confirmed_count,
            "invalidated_count": replay.invalidated_count,
            "false_breakout_avoided_count": replay.false_breakout_avoided_count,
            "pnl_delta": replay.pnl_delta,
            "max_drawdown_delta": replay.max_drawdown_delta,
        }

    def _handle_success(
        self,
        session: Session,
        ledger: LedgerRepository,
        command: CommandBusCommand,
        backtest_run: BacktestRun,
        result: BacktestResult,
    ) -> None:
        m = result.metrics
        backtest_run.status = "completed"
        backtest_run.sharpe_ratio = m.sharpe_ratio
        backtest_run.max_drawdown = m.max_drawdown_pct
        backtest_run.win_rate = m.win_rate
        backtest_run.total_return = m.total_return_pct
        backtest_run.profit_factor = m.profit_factor
        backtest_run.total_trades = m.total_trades
        backtest_run.result = {
            "metrics": {
                "total_return": m.total_return_pct,
                "sharpe_ratio": m.sharpe_ratio,
                "max_drawdown": m.max_drawdown_pct,
                "win_rate": m.win_rate,
                "profit_factor": m.profit_factor,
                "total_trades": m.total_trades,
                "avg_trade_duration": m.avg_trade_duration,
                "best_trade": m.best_trade_pct,
                "worst_trade": m.worst_trade_pct,
            },
            "trade_count": len(result.trades),
        }
        backtest_run.completed_at = _utcnow()
        session.flush()

        self._write_ledger(
            ledger, command, "FREQTRADE_BACKTEST_COMPLETED",
            {
                "backtest_run_id": backtest_run.id,
                "total_trades": m.total_trades,
                "sharpe_ratio": m.sharpe_ratio,
                "total_return_pct": m.total_return_pct,
                "max_drawdown_pct": m.max_drawdown_pct,
            },
        )

    def _handle_failure(
        self,
        session: Session,
        ledger: LedgerRepository,
        command: CommandBusCommand,
        backtest_run: BacktestRun,
        result: BacktestResult,
    ) -> None:
        backtest_run.status = "failed"
        backtest_run.error_message = (result.error_message or "unknown error")[:2000]
        backtest_run.completed_at = _utcnow()
        session.flush()

        self._write_ledger(
            ledger, command, "FREQTRADE_BACKTEST_FAILED",
            {
                "backtest_run_id": backtest_run.id,
                "exit_code": result.exit_code,
                "error_message": backtest_run.error_message,
            },
        )

    def _write_ledger(
        self,
        ledger: LedgerRepository,
        command: CommandBusCommand,
        event_type: str,
        payload: dict[str, Any],
    ) -> None:
        now = _utcnow()
        full_payload = {
            "command_id": str(command.id),
            "command_type": command.command_type,
            **payload,
        }
        event_hash = LedgerRepository.compute_event_hash(
            "freqtrade", str(command.id), event_type, full_payload, now,
        )
        evt = ExecutionLedgerEvent(
            id=uuid.uuid4(),
            event_time=now,
            event_type=event_type,
            source_system="freqtrade",
            source_event_id=str(command.id),
            event_hash=event_hash,
            command_id=command.id,
            strategy_run_id=command.aggregate_id,
            correlation_id=command.correlation_id,
            causation_id=command.id,
            normalized_payload=full_payload,
        )
        ledger.append(evt)

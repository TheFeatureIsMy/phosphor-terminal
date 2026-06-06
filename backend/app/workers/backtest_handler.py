"""StartBacktestHandler — Command Bus handler for backtest execution."""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.ledger import ExecutionLedgerEvent
from app.models.strategy import BacktestRun
from app.repositories.ledger_repository import LedgerRepository
from app.services.backtest_runner import FreqtradeBacktestRunner, BacktestResult
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

        return {
            "backtest_run_id": backtest_run.id,
            "total_trades": result.metrics.total_trades,
            "total_return_pct": result.metrics.total_return_pct,
            "sharpe_ratio": result.metrics.sharpe_ratio,
            "max_drawdown_pct": result.metrics.max_drawdown_pct,
            "win_rate": result.metrics.win_rate,
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

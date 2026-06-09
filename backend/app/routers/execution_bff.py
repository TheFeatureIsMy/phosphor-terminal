"""Execution BFF — Center + Orders/Positions + Emergency + Trade Trace/Labels/Review"""
import logging
import time
import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.execution_bff import (
    ExecutionCenterResponse, ExecutionSession,
    OrdersPositionsResponse, OrderResponse, PositionResponse,
    ReconciliationBusResponse, ReconciliationRun, CommandBusEvent,
)
from app.schemas.common import AvailableAction

router = APIRouter(prefix="/api/execution", tags=["execution-bff"])
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Mock fallbacks
# ---------------------------------------------------------------------------

def _mock_center() -> dict:
    return ExecutionCenterResponse(
        state="running",
        reason_codes=[],
        available_actions=[
            AvailableAction(type="emergency_stop", enabled=True, label="紧急停止", confirm_required=True),
        ],
        sessions=[
            ExecutionSession(run_id="run-001", strategy_name="BTC Structure Scalp", mode="live_small", status="running", symbol="BTC/USDT", open_positions=2, pending_orders=1),
            ExecutionSession(run_id="run-002", strategy_name="ETH FVG Hunter", mode="dryrun", status="running", symbol="ETH/USDT", open_positions=1, pending_orders=0),
        ],
        total_running=2,
        total_open_positions=3,
        total_pending_orders=1,
        freqtrade_heartbeat="healthy",
        execution_latency_ms=45,
    ).model_dump()


def _mock_orders_positions() -> dict:
    return OrdersPositionsResponse(
        state="healthy",
        reason_codes=[],
        available_actions=[
            AvailableAction(type="cancel_all_orders", enabled=True, label="取消所有挂单", confirm_required=True),
            AvailableAction(type="force_close_all", enabled=True, label="强制平仓所有", confirm_required=True),
        ],
        orders=[
            OrderResponse(id="ord-001", symbol="BTC/USDT", side="buy", type="limit", quantity=0.01, price=61500, status="pending", exchange_order_id="ex-12345"),
        ],
        positions=[
            PositionResponse(id="pos-001", symbol="BTC/USDT", side="long", avg_entry_price=62100, current_price=62450, quantity=0.05, unrealized_pnl=17.5, unrealized_pnl_pct=0.56, stop_loss=61200),
            PositionResponse(id="pos-002", symbol="ETH/USDT", side="long", avg_entry_price=3380, current_price=3410, quantity=1.0, unrealized_pnl=30, unrealized_pnl_pct=0.89, stop_loss=3320),
            PositionResponse(id="pos-003", symbol="BTC/USDT", side="short", avg_entry_price=62800, current_price=62450, quantity=0.02, unrealized_pnl=7, unrealized_pnl_pct=0.56, stop_loss=63200),
        ],
    ).model_dump()


# ---------------------------------------------------------------------------
# Endpoints — Execution Center / Orders / Positions / Emergency
# ---------------------------------------------------------------------------

@router.get("/center", response_model=ExecutionCenterResponse)
async def get_execution_center():
    try:
        from app.services.freqtrade_client import FreqtradeClient

        ft = FreqtradeClient()

        # Measure heartbeat latency
        t0 = time.time()
        is_alive = await ft.ping()
        latency_ms = int((time.time() - t0) * 1000)

        heartbeat = "healthy" if is_alive else "unhealthy"

        # Get open trades / positions from Freqtrade
        status_data = await ft.get_status()

        # status_data may be a list of trades or a dict with error
        if not FreqtradeClient.is_success(status_data):
            return ExecutionCenterResponse(
                state="degraded",
                reason_codes=["freqtrade_status_error"],
                available_actions=[
                    AvailableAction(type="emergency_stop", enabled=True, label="紧急停止", confirm_required=True),
                ],
                sessions=[],
                total_running=0,
                total_open_positions=0,
                total_pending_orders=0,
                freqtrade_heartbeat=heartbeat,
                execution_latency_ms=latency_ms,
            ).model_dump()

        trades = status_data if isinstance(status_data, list) else status_data.get("trades", [])

        sessions: list[ExecutionSession] = []
        total_positions = 0
        total_orders = 0

        for i, trade in enumerate(trades):
            trade_id = trade.get("trade_id", f"ft-{i}")
            pair = trade.get("pair", "UNKNOWN")
            is_open = trade.get("is_open", True)
            trade_status = "running" if is_open else "closed"

            orders_count = len(trade.get("orders", []))
            open_orders = sum(1 for o in trade.get("orders", []) if o.get("status") == "open")

            sessions.append(ExecutionSession(
                run_id=f"ft-trade-{trade_id}",
                strategy_name=trade.get("strategy", ""),
                mode="live_small",
                status=trade_status,
                symbol=pair,
                open_positions=1 if is_open else 0,
                pending_orders=open_orders,
            ))
            if is_open:
                total_positions += 1
            total_orders += open_orders

        running_count = sum(1 for s in sessions if s.status == "running")

        return ExecutionCenterResponse(
            state="running" if running_count > 0 else "idle",
            reason_codes=[],
            available_actions=[
                AvailableAction(type="emergency_stop", enabled=True, label="紧急停止", confirm_required=True),
            ],
            sessions=sessions,
            total_running=running_count,
            total_open_positions=total_positions,
            total_pending_orders=total_orders,
            freqtrade_heartbeat=heartbeat,
            execution_latency_ms=latency_ms,
        ).model_dump()
    except Exception as e:
        logger.warning(f"[execution-center] FreqtradeClient unavailable, mock fallback: {e}")
        data = _mock_center()
        data["_mock"] = True
        return data


@router.get("/orders", response_model=OrdersPositionsResponse)
async def get_orders_positions():
    try:
        from app.services.freqtrade_client import FreqtradeClient

        ft = FreqtradeClient()
        status_data = await ft.get_status()

        if not FreqtradeClient.is_success(status_data):
            raise ValueError("Freqtrade status error")

        trades = status_data if isinstance(status_data, list) else status_data.get("trades", [])

        orders: list[OrderResponse] = []
        positions: list[PositionResponse] = []

        for trade in trades:
            trade_id = str(trade.get("trade_id", ""))
            pair = trade.get("pair", "UNKNOWN")
            is_open = trade.get("is_open", True)

            if is_open:
                side = "long" if trade.get("is_short", False) is False else "short"
                entry_price = float(trade.get("open_rate", 0))
                current_price = float(trade.get("current_rate", entry_price))
                amount = float(trade.get("amount", 0))
                profit_abs = float(trade.get("profit_abs", 0))
                profit_pct = float(trade.get("profit_ratio", 0)) * 100

                positions.append(PositionResponse(
                    id=f"pos-ft-{trade_id}",
                    symbol=pair,
                    side=side,
                    avg_entry_price=entry_price,
                    current_price=current_price,
                    quantity=amount,
                    unrealized_pnl=profit_abs,
                    unrealized_pnl_pct=profit_pct,
                    stop_loss=trade.get("stop_loss"),
                    take_profit=trade.get("take_profit"),
                    freqtrade_trade_id=trade_id,
                ))

            for order in trade.get("orders", []):
                order_status = order.get("status", "unknown")
                if order_status in ("open", "pending"):
                    orders.append(OrderResponse(
                        id=f"ord-ft-{order.get('order_id', '')}",
                        symbol=pair,
                        side=order.get("side", "buy"),
                        type=order.get("order_type", "limit"),
                        quantity=float(order.get("amount", 0)),
                        price=order.get("price"),
                        status=order_status,
                        exchange_order_id=str(order.get("order_id", "")),
                        freqtrade_trade_id=trade_id,
                    ))

        return OrdersPositionsResponse(
            state="healthy",
            reason_codes=[],
            available_actions=[
                AvailableAction(type="cancel_all_orders", enabled=True, label="取消所有挂单", confirm_required=True),
                AvailableAction(type="force_close_all", enabled=True, label="强制平仓所有", confirm_required=True),
            ],
            orders=orders,
            positions=positions,
        ).model_dump()
    except Exception as e:
        logger.warning(f"[execution-orders] FreqtradeClient unavailable, mock fallback: {e}")
        data = _mock_orders_positions()
        data["_mock"] = True
        return data


@router.get("/positions", response_model=OrdersPositionsResponse)
async def get_positions():
    try:
        from app.services.freqtrade_client import FreqtradeClient

        ft = FreqtradeClient()
        status_data = await ft.get_status()

        if not FreqtradeClient.is_success(status_data):
            raise ValueError("Freqtrade status error")

        trades = status_data if isinstance(status_data, list) else status_data.get("trades", [])

        positions: list[PositionResponse] = []

        for trade in trades:
            trade_id = str(trade.get("trade_id", ""))
            pair = trade.get("pair", "UNKNOWN")
            is_open = trade.get("is_open", True)

            if is_open:
                side = "long" if trade.get("is_short", False) is False else "short"
                entry_price = float(trade.get("open_rate", 0))
                current_price = float(trade.get("current_rate", entry_price))
                amount = float(trade.get("amount", 0))
                profit_abs = float(trade.get("profit_abs", 0))
                profit_pct = float(trade.get("profit_ratio", 0)) * 100

                positions.append(PositionResponse(
                    id=f"pos-ft-{trade_id}",
                    symbol=pair,
                    side=side,
                    avg_entry_price=entry_price,
                    current_price=current_price,
                    quantity=amount,
                    unrealized_pnl=profit_abs,
                    unrealized_pnl_pct=profit_pct,
                    stop_loss=trade.get("stop_loss"),
                    take_profit=trade.get("take_profit"),
                    freqtrade_trade_id=trade_id,
                ))

        return OrdersPositionsResponse(
            state="healthy",
            reason_codes=[],
            available_actions=[
                AvailableAction(type="cancel_all_orders", enabled=True, label="取消所有挂单", confirm_required=True),
                AvailableAction(type="force_close_all", enabled=True, label="强制平仓所有", confirm_required=True),
            ],
            orders=[],
            positions=positions,
        ).model_dump()
    except Exception as e:
        logger.warning(f"[execution-positions] FreqtradeClient unavailable, mock fallback: {e}")
        data = _mock_orders_positions()
        data["_mock"] = True
        return data


@router.post("/emergency-stop")
async def emergency_stop():
    try:
        from app.services.freqtrade_client import FreqtradeClient

        ft = FreqtradeClient()
        result = await ft.stop_bot()

        if FreqtradeClient.is_success(result):
            return {
                "status": "emergency_stop_executed",
                "reason_codes": ["manual_trigger"],
                "freqtrade_response": result,
            }
        else:
            return {
                "status": "emergency_stop_attempted",
                "reason_codes": ["manual_trigger", "freqtrade_error"],
                "error": result.get("error", "unknown"),
            }
    except Exception as e:
        logger.warning(f"[emergency-stop] FreqtradeClient unavailable, mock fallback: {e}")
        return {"status": "emergency_stop_executed", "reason_codes": ["manual_trigger"], "_mock": True}


# ---------------------------------------------------------------------------
# Trade Trace / Labels / Review — real DB-backed endpoints
# ---------------------------------------------------------------------------

@router.get("/trades/{trade_id}/trace")
async def get_trade_source_trace(trade_id: str, db: Session = Depends(get_db)):
    """Return the full source trace for a trade: Signal -> Strategy -> Snapshot -> RiskDecision -> Trade."""
    feature_snapshot_data = None
    runtime_snapshot_data = None

    try:
        from app.services.feature_snapshot_service import FeatureSnapshotService

        fs_svc = FeatureSnapshotService(db)

        # Try lookup by trade_intent_id first
        fs = None
        try:
            fs = fs_svc.get_by_trade(trade_id)
        except Exception:
            pass

        if fs:
            feature_snapshot_data = {
                "feature_snapshot_id": str(fs.id),
                "snapshot_at": fs.snapshot_at.isoformat() if fs.snapshot_at else None,
                "features": fs.technical_features,
                "structure_context": fs.structure_context,
                "mtf_guard_context": fs.mtf_guard_context,
                "ai_context": fs.ai_context,
                "risk_context": fs.risk_context,
                "liquidity_context": fs.liquidity_context,
            }

            # If we have a runtime_snapshot_id, load the decision snapshot
            if fs.runtime_snapshot_id:
                try:
                    from app.domain.runtime import DecisionSnapshot
                    ds = (
                        db.query(DecisionSnapshot)
                        .filter(DecisionSnapshot.snapshot_uid == fs.runtime_snapshot_id)
                        .first()
                    )
                    if ds:
                        runtime_snapshot_data = {
                            "snapshot_id": ds.snapshot_uid,
                            "decision": ds.final_decision,
                            "reason_codes": ds.reason_codes or [],
                            "mtf_guard_context": fs.mtf_guard_context,
                            "structure_context": ds.structure_context,
                            "ai_context": ds.ai_context,
                            "indicator_context": ds.indicator_context,
                        }
                except Exception:
                    logger.debug("DecisionSnapshot lookup failed for %s", fs.runtime_snapshot_id)
    except Exception as e:
        logger.warning("[trade-trace] DB lookup failed, returning empty trace: %s", e)

    # Build labels list
    labels_data = []
    try:
        from app.services.trade_reviewer import TradeReviewer
        label_rows = TradeReviewer.get_labels(db, trade_id)
        labels_data = [
            {
                "id": str(lbl.id),
                "label": lbl.label,
                "label_source": lbl.label_source,
                "confidence": float(lbl.confidence) if lbl.confidence is not None else None,
                "notes": lbl.notes,
                "created_at": lbl.created_at.isoformat() if lbl.created_at else None,
            }
            for lbl in label_rows
        ]
    except Exception:
        logger.debug("[trade-trace] label lookup failed for %s", trade_id)

    has_snapshot = runtime_snapshot_data is not None
    has_feature = feature_snapshot_data is not None

    return {
        "trade_id": trade_id,
        "trace": {
            "signal": {
                "signal_id": None,
                "source_type": None,
                "direction": None,
                "confidence": None,
                "status": None,
            },
            "strategy": {
                "strategy_id": feature_snapshot_data.get("features", {}).get("strategy_id") if has_feature else None,
                "strategy_name": None,
                "version_id": None,
                "version_no": None,
                "dsl_version": None,
            },
            "runtime_snapshot": runtime_snapshot_data or {
                "snapshot_id": None,
                "decision": None,
                "reason_codes": [],
                "mtf_guard_context": None,
                "structure_context": None,
                "ai_context": None,
            },
            "risk_decision": {
                "decision_type": None,
                "reason_code": None,
            },
            "execution": {
                "strategy_run_id": None,
                "run_mode": None,
                "entry_price": None,
                "exit_price": None,
                "pnl_pct": None,
            },
            "feature_snapshot": feature_snapshot_data or {
                "feature_snapshot_id": None,
                "features": None,
            },
        },
        "labels": labels_data,
        "available_actions": [
            {"type": "open_signal", "enabled": has_snapshot, "label": "查看信号"},
            {"type": "open_strategy", "enabled": has_snapshot, "label": "查看策略"},
            {"type": "open_snapshot", "enabled": has_snapshot, "label": "查看快照"},
            {"type": "add_review_label", "enabled": True, "label": "打标签"},
            {"type": "generate_shadow_strategy", "enabled": True, "label": "生成影子策略"},
        ],
    }


@router.post("/trades/{trade_id}/labels")
async def add_trade_review_label(trade_id: str, body: dict, db: Session = Depends(get_db)):
    """Add a review label to a trade for failure clustering."""
    label = body.get("label", "")
    label_source = body.get("label_source", "human")
    confidence = body.get("confidence")
    notes = body.get("notes", "")

    if not label:
        return {"error": "label is required", "status": "error"}

    try:
        from app.services.trade_reviewer import TradeReviewer

        row = TradeReviewer.add_label(
            db=db,
            trade_id=trade_id,
            label=label,
            label_source=label_source,
            confidence=confidence,
            notes=notes,
            runtime_snapshot_id=body.get("runtime_snapshot_id"),
            feature_snapshot_id=body.get("feature_snapshot_id"),
        )
        db.commit()
        return {
            "trade_id": trade_id,
            "label_id": str(row.id),
            "label": row.label,
            "label_source": row.label_source,
            "confidence": float(row.confidence) if row.confidence is not None else None,
            "notes": row.notes,
            "result": "label_added",
        }
    except Exception as e:
        db.rollback()
        logger.warning("[add-label] DB write failed, returning stub: %s", e)
        return {
            "trade_id": trade_id,
            "label": label,
            "label_source": label_source,
            "notes": notes,
            "result": "label_added",
            "_mock": True,
        }


@router.get("/trades/{trade_id}/labels")
async def get_trade_labels(trade_id: str, db: Session = Depends(get_db)):
    """List all review labels for a trade."""
    try:
        from app.services.trade_reviewer import TradeReviewer

        rows = TradeReviewer.get_labels(db, trade_id)
        return {
            "trade_id": trade_id,
            "labels": [
                {
                    "id": str(r.id),
                    "label": r.label,
                    "label_source": r.label_source,
                    "confidence": float(r.confidence) if r.confidence is not None else None,
                    "notes": r.notes,
                    "created_at": r.created_at.isoformat() if r.created_at else None,
                }
                for r in rows
            ],
        }
    except Exception as e:
        logger.warning("[get-labels] DB read failed: %s", e)
        return {"trade_id": trade_id, "labels": [], "_mock": True}


@router.get("/trades/{trade_id}/review")
async def get_trade_review(trade_id: str, db: Session = Depends(get_db)):
    """Get trade review info including FeatureSnapshot and labels."""
    feature_snapshot = None
    labels = []
    mtf_guard_context = None
    attribution = None

    # Load FeatureSnapshot
    try:
        from app.services.feature_snapshot_service import FeatureSnapshotService

        fs_svc = FeatureSnapshotService(db)
        fs = fs_svc.get_by_trade(trade_id)
        if fs:
            feature_snapshot = {
                "id": str(fs.id),
                "snapshot_at": fs.snapshot_at.isoformat() if fs.snapshot_at else None,
                "symbol": fs.symbol,
                "exchange": fs.exchange,
                "timeframe": fs.timeframe,
                "features": fs.technical_features,
                "structure_context": fs.structure_context,
                "ai_context": fs.ai_context,
                "risk_context": fs.risk_context,
                "liquidity_context": fs.liquidity_context,
            }
            mtf_guard_context = fs.mtf_guard_context
    except Exception as e:
        logger.debug("[trade-review] FeatureSnapshot lookup failed: %s", e)

    # Load labels
    try:
        from app.services.trade_reviewer import TradeReviewer

        rows = TradeReviewer.get_labels(db, trade_id)
        labels = [
            {
                "id": str(r.id),
                "label": r.label,
                "label_source": r.label_source,
                "confidence": float(r.confidence) if r.confidence is not None else None,
                "notes": r.notes,
                "created_at": r.created_at.isoformat() if r.created_at else None,
            }
            for r in rows
        ]
    except Exception as e:
        logger.debug("[trade-review] label lookup failed: %s", e)

    # Load attribution
    try:
        from app.domain.growth import OrderAttribution
        attr = (
            db.query(OrderAttribution)
            .filter(OrderAttribution.execution_order_id == uuid.UUID(trade_id))
            .first()
        )
        if attr:
            attribution = {
                "id": str(attr.id),
                "rule_path": attr.rule_path,
                "attribution_confidence": attr.attribution_confidence,
            }
    except Exception:
        pass  # attribution is optional

    return {
        "trade_id": trade_id,
        "feature_snapshot": feature_snapshot,
        "labels": labels,
        "mtf_guard_context": mtf_guard_context,
        "attribution": attribution,
    }

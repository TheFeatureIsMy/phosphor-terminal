"""Manipulation Radar API — scan + score retrieval."""
import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.manipulation import ManipulationScanRequest, ManipulationScoreResponse
from app.services.manipulation.radar_service import ManipulationRadarService
from app.services.manipulation.lifecycle import ManipulationLifecycleTracker
from app.services.manipulation.strategy_impact import compute_strategy_impact

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v2/manipulation", tags=["manipulation-radar"])

# ---------------------------------------------------------------------------
# Lazy singleton for case repository
# ---------------------------------------------------------------------------
_case_repo = None
_LIFECYCLE_TRACKER = ManipulationLifecycleTracker()

LAYER_KEYS = ("A_price", "B_orderbook", "C_onchain", "D_social", "E_cross_market")


def _get_case_repo():
    global _case_repo
    if _case_repo is None:
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        _case_repo = ManipulationCaseRepository()
    return _case_repo


def _risk_level_from_stage(stage: str) -> str:
    if stage in ("distribute", "collapse"):
        return "high"
    if stage == "markup":
        return "medium"
    return "low"


_STABLE_QUOTE_CURRENCIES = ("USDT", "USDC", "FDUSD")


def _expand_affected_symbols(symbol: str) -> list[str]:
    """Expand a futures symbol to same-base stablecoin pairs.
    SOL/USDT -> [SOL/USDT, SOL/USDC, SOL/FDUSD]; BTC (no /) -> [BTC].
    """
    if "/" not in symbol:
        return [symbol]
    base, _quote = symbol.split("/", 1)
    return [f"{base}/{q}" for q in _STABLE_QUOTE_CURRENCIES]


def _completeness(layers: dict | None) -> float:
    if not layers:
        return 0.0
    available = sum(1 for k in LAYER_KEYS if layers.get(k) and layers[k].get("available"))
    return round(available / len(LAYER_KEYS), 4)


def _build_case_detail_v2(case: dict) -> dict:
    layers = case.get("evidence_layers")
    completeness = _completeness(layers)
    max_confidence = round(min(completeness * 1.2, 1.0), 4)
    dual = _LIFECYCLE_TRACKER.generate_dual_signal(case["lifecycle_stage"])
    return {
        "id": case["id"],
        "symbol": case["symbol"],
        "market": case["market"],
        "manipulation_type": case["manipulation_type"],
        "lifecycle_stage": case["lifecycle_stage"],
        "confidence": case["confidence"],
        "risk_level": _risk_level_from_stage(case["lifecycle_stage"]),
        "evidence": case.get("evidence", {}),
        "evidence_layers": layers,
        "completeness": completeness,
        "max_confidence": max_confidence,
        "timeline": case.get("timeline", []),
        "trading_signal": dual,
        "affected_symbols": _expand_affected_symbols(case["symbol"]),
        "sources": [{
            "type": case.get("source", "rule_engine"),
            "rule_id": case["manipulation_type"],
            "version": "v1",
        }],
        "outcome": case.get("outcome") or {},
        "auto_discovered": case.get("auto_discovered", True),
        "source": case.get("source", "rule_engine"),
        "created_at": case["created_at"],
        "updated_at": case["updated_at"],
        "completed_at": case.get("completed_at"),
    }


# ---------------------------------------------------------------------------
# Existing endpoints — scan + scores
# ---------------------------------------------------------------------------

@router.post("/scan", response_model=ManipulationScoreResponse, status_code=201)
def scan_symbol(req: ManipulationScanRequest, db: Session = Depends(get_db)):
    svc = ManipulationRadarService(db)
    svc.scan_symbol(req.symbol, req.timeframe)
    db.commit()

    record = svc.get_latest_score(req.symbol)
    if not record:
        raise HTTPException(status_code=500, detail="Failed to persist score")
    return ManipulationScoreResponse.from_orm_model(record)


@router.get("/scores", response_model=list[ManipulationScoreResponse])
def list_scores(
    risk_level: str | None = None,
    limit: int = Query(default=50, le=200),
    db: Session = Depends(get_db),
):
    svc = ManipulationRadarService(db)
    records = svc.list_scores(risk_level=risk_level, limit=limit)
    return [ManipulationScoreResponse.from_orm_model(r) for r in records]


@router.get("/scores/{symbol:path}", response_model=ManipulationScoreResponse)
def get_symbol_score(symbol: str, db: Session = Depends(get_db)):
    svc = ManipulationRadarService(db)
    record = svc.get_latest_score(symbol)
    if not record:
        raise HTTPException(status_code=404, detail=f"No score found for {symbol}")
    return ManipulationScoreResponse.from_orm_model(record)


# ---------------------------------------------------------------------------
# New endpoints — Radar, Cases, Alerts, Signals, Historical Scan
# ---------------------------------------------------------------------------

@router.get("/radar")
async def get_radar_overview():
    try:
        repo = _get_case_repo()
        return repo.get_radar_overview()
    except Exception as exc:
        logger.exception("Radar overview failed: %s", exc)
        return {
            "active_cases": [],
            "total_active": 0,
            "by_stage": {},
            "high_risk_symbols": [],
            "recent_alerts": [],
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        }


@router.get("/cases")
async def list_cases(stage: str | None = None, symbol: str | None = None,
                     manipulation_type: str | None = None, active_only: bool = True):
    try:
        repo = _get_case_repo()
        return repo.list_cases(stage=stage, symbol=symbol,
                               manipulation_type=manipulation_type, active_only=active_only)
    except Exception as exc:
        logger.exception("List cases failed: %s", exc)
        return {
            "cases": [],
            "total": 0,
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        }


@router.get("/cases/{case_id}")
async def get_case(case_id: str):
    try:
        repo = _get_case_repo()
        case = repo.get_case(case_id)
        if not case:
            raise HTTPException(404, "Case not found")
        return _build_case_detail_v2(case)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Get case failed: %s", exc)
        raise HTTPException(status_code=503, detail={
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        })


@router.get("/cases/{case_id}/strategy-impact")
async def get_strategy_impact(case_id: str, db: Session = Depends(get_db)):
    try:
        repo = _get_case_repo()
        case = repo.get_case(case_id)
        if not case:
            raise HTTPException(404, "Case not found")
        return compute_strategy_impact(case, db)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Strategy impact failed: %s", exc)
        return {
            "case_id": case_id,
            "affected_strategies": [],
            "total_affected": 0,
            "total_protected": 0,
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        }


@router.get("/cases/{case_id}/similar")
async def get_similar(case_id: str, top_n: int = 5):
    try:
        repo = _get_case_repo()
        case = repo.get_case(case_id)
        if not case:
            raise HTTPException(404, "Case not found")
        similar = repo.find_similar(case_id, top_n=top_n)
        return {"case_id": case_id, "similar": similar, "total": len(similar)}
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Similar cases failed: %s", exc)
        return {
            "case_id": case_id,
            "similar": [],
            "total": 0,
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        }


@router.get("/alerts")
async def get_alerts(limit: int = 20):
    try:
        repo = _get_case_repo()
        return repo.get_alerts(limit=limit)
    except Exception as exc:
        logger.exception("Get alerts failed: %s", exc)
        return {
            "alerts": [],
            "total": 0,
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        }


@router.post("/historical-scan")
async def historical_scan(symbol: str = "BTC/USDT", market: str = "crypto", limit: int = 500):
    try:
        from app.services.manipulation.data_adapter import MockMarketDataAdapter
        from app.services.manipulation.historical_scanner import HistoricalManipulationScanner
        adapter = MockMarketDataAdapter()
        candles = adapter.get_ohlcv(symbol, "1h", limit)
        scanner = HistoricalManipulationScanner()
        result = scanner.scan(candles, symbol=symbol, market=market)
        repo = _get_case_repo()
        for case_data in result.cases:
            repo.create_case(
                symbol=case_data["symbol"], market=case_data["market"],
                manipulation_type=case_data["manipulation_type"],
                confidence=case_data["confidence"], evidence=case_data["evidence"],
                source="historical_scan"
            )
        return {
            "symbol": result.symbol,
            "scanned_candles": result.scanned_candles,
            "events_detected": result.events_detected,
            "confirmed_cases": result.confirmed_cases,
        }
    except Exception as exc:
        logger.exception("Historical scan failed: %s", exc)
        return {
            "symbol": symbol,
            "scanned_candles": 0,
            "events_detected": 0,
            "confirmed_cases": 0,
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        }


@router.get("/signals")
async def get_signals(user_profile: str = "conservative"):
    try:
        from app.services.manipulation.lifecycle import ManipulationLifecycleTracker
        repo = _get_case_repo()
        tracker = ManipulationLifecycleTracker()
        active = repo.list_cases(active_only=True)
        signals = []
        for case in active:
            signal = tracker.generate_signal(case["lifecycle_stage"], user_profile)
            signals.append({
                "case_id": case["id"],
                "symbol": case["symbol"],
                "manipulation_type": case["manipulation_type"],
                "lifecycle_stage": case["lifecycle_stage"],
                "signal": signal.to_dict(),
            })
        return {
            "signals": signals,
            "total": len(signals),
            "state": "healthy",
        }
    except Exception as exc:
        logger.exception("Get signals failed: %s", exc)
        return {
            "signals": [],
            "total": 0,
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        }


@router.get("/training/stats")
async def get_training_stats():
    try:
        from app.services.manipulation.training_pipeline import ManipulationTrainingPipeline
        pipeline = ManipulationTrainingPipeline()
        stats = pipeline.get_stats()
        stats["state"] = "healthy"
        return stats
    except Exception as exc:
        logger.exception("Training stats failed: %s", exc)
        return {
            "total_samples": 0,
            "version": 0,
            "by_type": {},
            "by_stage": {},
            "cases_since_last_train": 0,
            "retrain_threshold": 50,
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        }

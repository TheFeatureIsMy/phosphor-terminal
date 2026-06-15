"""Manipulation Radar API — scan + score retrieval."""
import logging

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.manipulation import ManipulationScanRequest, ManipulationScoreResponse
from app.services.manipulation.radar_service import ManipulationRadarService

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v2/manipulation", tags=["manipulation-radar"])

# ---------------------------------------------------------------------------
# Lazy singleton for case repository
# ---------------------------------------------------------------------------
_case_repo = None


def _get_case_repo():
    global _case_repo
    if _case_repo is None:
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        _case_repo = ManipulationCaseRepository()
    return _case_repo


# ---------------------------------------------------------------------------
# Mock fallback helpers
# ---------------------------------------------------------------------------

def _mock_radar_overview():
    return {
        "active_cases": [
            {"id": "mock-1", "symbol": "SOL/USDT", "manipulation_type": "M5",
             "lifecycle_stage": "markup", "confidence": 0.78, "trading_signal_action": "RIDE", "created_at": "2026-06-15T10:00:00Z"},
            {"id": "mock-2", "symbol": "PEPE/USDT", "manipulation_type": "M3",
             "lifecycle_stage": "distribute", "confidence": 0.85, "trading_signal_action": "EXIT", "created_at": "2026-06-14T08:00:00Z"},
            {"id": "mock-3", "symbol": "DOGE/USDT", "manipulation_type": "M8",
             "lifecycle_stage": "suspected", "confidence": 0.45, "trading_signal_action": "WATCH", "created_at": "2026-06-15T14:00:00Z"},
        ],
        "total_active": 3,
        "by_stage": {"suspected": 1, "markup": 1, "distribute": 1},
        "high_risk_symbols": ["PEPE/USDT"],
        "recent_alerts": [
            {"id": "alert-1", "case_id": "mock-2", "alert_type": "stage_change", "severity": "critical",
             "title": "PEPE/USDT: markup → distribute", "detail": {}, "trading_signal": None, "created_at": "2026-06-15T12:00:00Z"},
            {"id": "alert-2", "case_id": "mock-1", "alert_type": "stage_change", "severity": "warning",
             "title": "SOL/USDT: accumulate → markup", "detail": {}, "trading_signal": None, "created_at": "2026-06-15T10:30:00Z"},
        ],
        "_mock": True,
    }


def _mock_case_detail():
    return {
        "id": "mock-1", "symbol": "SOL/USDT", "market": "crypto",
        "manipulation_type": "M5", "lifecycle_stage": "markup",
        "confidence": 0.78, "evidence": {"pump_dump": 65, "volume_zscore": 55, "price_range_spike": 48, "cross_market_squeeze_score": 72},
        "timeline": [
            {"stage": "suspected", "entered_at": "2026-06-14T08:00:00Z", "confidence": 0.45},
            {"stage": "accumulate", "entered_at": "2026-06-14T16:00:00Z", "confidence": 0.62},
            {"stage": "markup", "entered_at": "2026-06-15T10:00:00Z", "confidence": 0.78},
        ],
        "outcome": {}, "similar_cases": [], "auto_discovered": True, "source": "rule_engine",
        "trading_signal": {"action": "RIDE", "direction": "long", "sizing": "medium",
                           "stop_loss": "trailing", "rationale": "Markup confirmed", "risk_level": "medium"},
        "created_at": "2026-06-14T08:00:00Z", "updated_at": "2026-06-15T10:00:00Z",
        "_mock": True,
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
        logger.warning("Radar overview failed: %s", exc)
        return _mock_radar_overview()


@router.get("/cases")
async def list_cases(stage: str | None = None, symbol: str | None = None,
                     manipulation_type: str | None = None, active_only: bool = True):
    try:
        repo = _get_case_repo()
        return repo.list_cases(stage=stage, symbol=symbol,
                               manipulation_type=manipulation_type, active_only=active_only)
    except Exception as exc:
        logger.warning("List cases failed: %s", exc)
        return []


@router.get("/cases/{case_id}")
async def get_case(case_id: str):
    try:
        repo = _get_case_repo()
        case = repo.get_case(case_id)
        if not case:
            raise HTTPException(404, "Case not found")
        return case
    except HTTPException:
        raise
    except Exception as exc:
        logger.warning("Get case failed: %s", exc)
        return _mock_case_detail()


@router.get("/alerts")
async def get_alerts(limit: int = 20):
    try:
        repo = _get_case_repo()
        return repo.get_alerts(limit=limit)
    except Exception as exc:
        logger.warning("Get alerts failed: %s", exc)
        return []


@router.post("/historical-scan")
async def historical_scan(symbol: str = "BTC/USDT", market: str = "crypto", limit: int = 500):
    try:
        from app.services.manipulation.data_adapter import MockMarketDataAdapter
        from app.services.manipulation.historical_scanner import HistoricalManipulationScanner
        adapter = MockMarketDataAdapter()
        candles = adapter.get_ohlcv(symbol, "1h", limit)
        scanner = HistoricalManipulationScanner()
        result = scanner.scan(candles, symbol=symbol, market=market)
        # Save confirmed cases to repo
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
        logger.warning("Historical scan failed: %s", exc)
        return {"symbol": symbol, "scanned_candles": 0, "events_detected": 0, "confirmed_cases": 0}


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
        return signals
    except Exception as exc:
        logger.warning("Get signals failed: %s", exc)
        return []

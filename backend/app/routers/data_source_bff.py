"""Data Source Management BFF — List + Test + Enable/Disable"""
import logging

from fastapi import APIRouter, Path

from app.schemas.data_source_bff import (
    DataSourceManagementResponse, DataSourceResponse,
)
from app.schemas.common import AvailableAction

router = APIRouter(prefix="/api/data-sources", tags=["data-source-bff"])
logger = logging.getLogger(__name__)


def _mock_sources() -> list[DataSourceResponse]:
    return [
        DataSourceResponse(
            source_id="ds-001", name="Binance Kline", category="exchange_kline",
            provider="binance", status="active", last_fetch="2026-06-06T10:05:00Z",
            latency_ms=45, freshness="fresh", config={"symbols": ["BTC/USDT", "ETH/USDT"], "intervals": ["1m", "5m", "1h"]},
        ),
        DataSourceResponse(
            source_id="ds-002", name="Binance Orderbook", category="orderbook",
            provider="binance", status="active", last_fetch="2026-06-06T10:05:01Z",
            latency_ms=32, freshness="fresh", config={"depth": 20, "symbols": ["BTC/USDT", "ETH/USDT"]},
        ),
        DataSourceResponse(
            source_id="ds-003", name="Binance Funding", category="funding",
            provider="binance", status="active", last_fetch="2026-06-06T10:00:00Z",
            latency_ms=120, freshness="fresh", config={"symbols": ["BTC/USDT", "ETH/USDT"]},
        ),
        DataSourceResponse(
            source_id="ds-004", name="CoinGlass OI", category="open_interest",
            provider="coinglass", status="active", last_fetch="2026-06-06T09:58:00Z",
            latency_ms=280, freshness="fresh", config={"symbols": ["BTC", "ETH"], "exchanges": ["binance", "bybit"]},
        ),
        DataSourceResponse(
            source_id="ds-005", name="CryptoNews", category="news",
            provider="cryptonews_api", status="active", last_fetch="2026-06-06T09:50:00Z",
            latency_ms=450, freshness="fresh", config={"languages": ["en", "zh"], "keywords": ["bitcoin", "ethereum", "fed"]},
        ),
        DataSourceResponse(
            source_id="ds-006", name="Whale Alert", category="whale",
            provider="whale_alert", status="rate_limited", last_fetch="2026-06-06T09:30:00Z",
            latency_ms=0, freshness="stale", config={"min_value_usd": 1000000},
            reason_codes=["rate_limit_exceeded", "retry_after_60s"],
        ),
        DataSourceResponse(
            source_id="ds-007", name="Glassnode", category="on_chain",
            provider="glassnode", status="active", last_fetch="2026-06-06T09:45:00Z",
            latency_ms=380, freshness="fresh", config={"metrics": ["sopr", "nupl", "exchange_netflow"], "asset": "BTC"},
        ),
        DataSourceResponse(
            source_id="ds-008", name="CryptoCompare Social", category="social",
            provider="cryptocompare", status="error", last_fetch="2026-06-05T22:00:00Z",
            latency_ms=0, freshness="expired", config={"coins": ["BTC", "ETH"]},
            reason_codes=["api_key_expired", "last_success_12h_ago"],
        ),
    ]


def _mock_management_response() -> dict:
    sources = _mock_sources()
    active_count = sum(1 for s in sources if s.status == "active")
    error_count = sum(1 for s in sources if s.status in ("error", "rate_limited"))
    return DataSourceManagementResponse(
        state="warning",
        reason_codes=["whale_alert_rate_limited", "cryptocompare_api_key_expired"],
        available_actions=[
            AvailableAction(type="refresh_all", enabled=True, label="刷新所有数据源"),
            AvailableAction(type="test_all", enabled=True, label="测试所有连接"),
            AvailableAction(type="add_source", enabled=True, label="添加数据源"),
        ],
        sources=sources,
        total_active=active_count,
        total_error=error_count,
    ).model_dump()


def _find_mock_source(source_id: str) -> dict | None:
    for s in _mock_sources():
        if s.source_id == source_id:
            return s.model_dump()
    return None


@router.get("", response_model=DataSourceManagementResponse)
async def get_data_sources():
    try:
        from app.services.data_source_manager import DataSourceManager
        mgr = DataSourceManager()
        sources = await mgr.get_all_sources()
        active = [s for s in sources if s.status == "active"]
        errors = [s for s in sources if s.status == "error"]
        all_reasons = []
        for s in sources:
            all_reasons.extend(s.reason_codes)
        state = "healthy" if not errors else "warning"
        return {
            "state": state,
            "reason_codes": all_reasons[:5],
            "available_actions": [{"type": "test_all", "enabled": True, "label": "测试所有连接"}],
            "sources": [
                {
                    "source_id": s.source_id, "name": s.name, "category": s.category,
                    "provider": s.provider, "status": s.status, "last_fetch": s.last_fetch,
                    "latency_ms": s.latency_ms, "freshness": s.freshness,
                    "config": s.config, "reason_codes": s.reason_codes,
                } for s in sources
            ],
            "total_active": len(active),
            "total_error": len(errors),
        }
    except Exception as e:
        logger.warning(f"[data-sources] DataSourceManager unavailable, mock fallback: {e}")
        data = _mock_management_response()
        data["_mock"] = True
        return data


@router.get("/{source_id}")
async def get_data_source(source_id: str):
    try:
        from app.services.data_source_manager import DataSourceManager
        mgr = DataSourceManager()
        source = await mgr.test_source(source_id)
        return {
            "source_id": source.source_id, "name": source.name, "category": source.category,
            "provider": source.provider, "status": source.status, "last_fetch": source.last_fetch,
            "latency_ms": source.latency_ms, "freshness": source.freshness,
            "config": source.config, "reason_codes": source.reason_codes,
        }
    except Exception as e:
        logger.warning(f"[data-source/{source_id}] DataSourceManager unavailable, mock fallback: {e}")
        source = _find_mock_source(source_id)
        if source:
            source["_mock"] = True
            return source
        return {"source_id": source_id, "status": "error", "reason_codes": ["service_unavailable"], "_mock": True}


@router.post("/{source_id}/test")
async def test_data_source(source_id: str):
    try:
        from app.services.data_source_manager import DataSourceManager
        mgr = DataSourceManager()
        result = await mgr.test_source(source_id)
        return {"status": result.status, "latency_ms": result.latency_ms, "reason_codes": result.reason_codes}
    except Exception as e:
        logger.warning(f"[data-source/{source_id}/test] DataSourceManager unavailable, mock fallback: {e}")
        return {"status": "error", "latency_ms": 0, "reason_codes": ["test_failed"], "_mock": True}


@router.post("/{source_id}/enable")
async def enable_data_source(source_id: str):
    from app.services.data_source_manager import DataSourceManager
    mgr = DataSourceManager()
    mgr.enable_source(source_id)
    return {"status": "enabled", "source_id": source_id}


@router.post("/{source_id}/disable")
async def disable_data_source(source_id: str):
    from app.services.data_source_manager import DataSourceManager
    mgr = DataSourceManager()
    mgr.disable_source(source_id)
    return {"status": "disabled", "source_id": source_id}

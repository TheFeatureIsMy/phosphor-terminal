"""Health probe truthfulness tests — no fake zeros.

Covers RuntimeRedisStore RTT probes, overview_aggregator system probes
(fast_track / redis_rtt / exchange_state), and live_readiness real
data-source / exchange / system-gate probes.
"""
from __future__ import annotations

import asyncio

import pytest

from app.models.provider_config import ProviderConfig
from app.services.overview_aggregator import (
    OverviewAggregatorService,
    _provider_category_state,
)
from app.services.runtime_redis_store import RuntimeRedisStore


class TestRedisStoreProbes:
    def test_degraded_store_reports_no_rtt(self):
        # No redis in tests → in-memory fallback
        store = RuntimeRedisStore(redis_url=None)
        assert store.is_degraded is True
        assert asyncio.run(store.ping_rtt_ms()) is None
        assert asyncio.run(store.probe_fast_track_latency_ms()) is None
        # ping() stays True for the fallback path (degraded but serving)
        assert asyncio.run(store.ping()) is True


class TestProviderCategoryState:
    def test_unconfigured_when_no_rows(self, session):
        assert _provider_category_state("cex") == "unconfigured"

    def test_ok_when_any_active(self, session):
        session.add(ProviderConfig(
            category="cex", provider_name="binance", config={},
            enabled=True, status="active", is_active=True,
        ))
        session.add(ProviderConfig(
            category="cex", provider_name="okx", config={},
            enabled=True, status="error",
        ))
        session.commit()
        assert _provider_category_state("cex") == "ok"

    def test_error_when_all_failing(self, session):
        session.add(ProviderConfig(
            category="cex", provider_name="binance", config={},
            enabled=True, status="error",
        ))
        session.commit()
        assert _provider_category_state("cex") == "error"

    def test_degraded_when_unknown(self, session):
        session.add(ProviderConfig(
            category="cex", provider_name="binance", config={},
            enabled=True, status="unknown",
        ))
        session.commit()
        assert _provider_category_state("cex") == "degraded"

    def test_disabled_rows_ignored(self, session):
        session.add(ProviderConfig(
            category="cex", provider_name="binance", config={},
            enabled=False, status="active",
        ))
        session.commit()
        assert _provider_category_state("cex") == "unconfigured"


class TestOverviewSystemProbes:
    def test_system_block_has_no_fake_zeros(self, session):
        agg = OverviewAggregatorService()
        system = asyncio.run(agg._fetch_system())
        # fast_track / redis RTT: either -1 (unavailable) or a real positive
        # measurement — never a fabricated 0. Valid with or without a live Redis.
        ft = system["fast_track_latency_ms"]
        rt = system["redis_rtt_ms"]
        assert ft == -1 or ft > 0
        assert rt == -1 or rt > 0
        # degraded reasons only when serving from the in-memory fallback
        if rt == -1:
            assert "redis_degraded_in_memory" in system["reason_codes"]
        # exchange_state derived from provider health rows
        assert system["exchange_state"] == "unconfigured"

    def test_exchange_state_reflects_provider_health(self, session):
        session.add(ProviderConfig(
            category="cex", provider_name="binance", config={},
            enabled=True, status="active", is_active=True,
        ))
        session.commit()
        agg = OverviewAggregatorService()
        system = asyncio.run(agg._fetch_system())
        assert system["exchange_state"] == "ok"


class TestLiveReadinessRealProbes:
    def _svc(self):
        from app.services.live_readiness_service import LiveReadinessService
        return LiveReadinessService(redis_store=None, freqtrade_client=None)

    def test_data_source_warning_when_unconfigured(self, session):
        c = self._svc()._check_data_source()
        assert c.key == "data_source"
        assert c.status == "warning"
        assert c.value == "unconfigured"

    def test_data_source_healthy_when_active_provider(self, session):
        session.add(ProviderConfig(
            category="market_data", provider_name="ccxt_ticker", config={},
            enabled=True, status="active", is_active=True,
        ))
        session.commit()
        c = self._svc()._check_data_source()
        assert c.status == "healthy"

    def test_data_source_failed_when_provider_error(self, session):
        session.add(ProviderConfig(
            category="market_data", provider_name="ccxt_ticker", config={},
            enabled=True, status="error",
        ))
        session.commit()
        c = self._svc()._check_data_source()
        assert c.status == "failed"

    def test_exchange_warning_when_no_cex_provider(self, session):
        c = self._svc()._check_exchange("binance")
        assert c.status == "warning"

    def test_exchange_failed_when_cex_provider_error(self, session):
        session.add(ProviderConfig(
            category="cex", provider_name="binance", config={},
            enabled=True, status="error",
        ))
        session.commit()
        c = self._svc()._check_exchange("binance")
        assert c.status == "failed"

    def test_probe_system_gates_reflect_provider_state(self, session):
        session.add(ProviderConfig(
            category="market_data", provider_name="ccxt_ticker", config={},
            enabled=True, status="active", is_active=True,
        ))
        session.commit()
        gates = self._svc()._probe_system_gates(session)
        by_key = {g.key: g for g in gates}
        assert by_key["data_source"].status == "healthy"
        assert by_key["exchange"].status == "warning"  # no cex configured
        assert by_key["notification"].status == "healthy"  # optional
        assert by_key["emergency_stop"].status == "healthy"

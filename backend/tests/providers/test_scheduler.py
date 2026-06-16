"""Tests for ProviderHealthScheduler and ProviderHealthTickPolicy."""
from __future__ import annotations

from datetime import datetime, timezone

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models.provider_config import ProviderConfig
from app.services.providers.scheduler import ProviderHealthTickPolicy


def _row(category, provider_name, enabled=True, last_sync_at=None, instance_name=None):
    return ProviderConfig(
        category=category, provider_name=provider_name,
        instance_name=instance_name, config={}, enabled=enabled,
        last_sync_at=last_sync_at, status="unknown",
    )


def test_tick_policy_selects_enabled_only():
    rows = [
        _row("cex", "binance", enabled=True),
        _row("cex", "bybit", enabled=False),
        _row("cex", "okx", enabled=True),
    ]
    policy = ProviderHealthTickPolicy(batch_size=10)
    selected = policy.select(rows, now=datetime.now(timezone.utc))
    names = [r.provider_name for r in selected]
    assert "binance" in names
    assert "okx" in names
    assert "bybit" not in names


def test_tick_policy_orders_oldest_first():
    now = datetime.now(timezone.utc)
    old = now.replace(year=2020)
    rows = [
        _row("cex", "fresh", last_sync_at=now),
        _row("cex", "old", last_sync_at=old),
        _row("cex", "never", last_sync_at=None),
    ]
    policy = ProviderHealthTickPolicy(batch_size=10)
    selected = policy.select(rows, now=now)
    names = [r.provider_name for r in selected]
    assert names[0] == "never"
    assert names[1] == "old"
    assert names[2] == "fresh"


def test_tick_policy_respects_batch_size():
    rows = [_row("cex", f"p{i}") for i in range(20)]
    policy = ProviderHealthTickPolicy(batch_size=5)
    selected = policy.select(rows, now=datetime.now(timezone.utc))
    assert len(selected) == 5


def test_scheduler_interval_zero_disables_loop():
    from app.services.providers.scheduler import ProviderHealthScheduler
    sched = ProviderHealthScheduler(interval_s=0)
    assert sched.enabled is False

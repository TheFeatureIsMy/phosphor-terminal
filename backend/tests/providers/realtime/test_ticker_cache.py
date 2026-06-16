"""Tests for TickerCache."""
import time

from app.services.providers.realtime.ticker_cache import TickerCache


def test_set_and_get():
    c = TickerCache(ttl_s=10.0)
    c.set("BTC/USDT", {"last": 50000.0})
    assert c.get("BTC/USDT") == {"last": 50000.0}


def test_get_missing():
    c = TickerCache()
    assert c.get("NOPE") is None


def test_expiry():
    c = TickerCache(ttl_s=0.01)
    c.set("BTC/USDT", {"last": 1.0})
    time.sleep(0.02)
    assert c.get("BTC/USDT") is None


def test_all_filters_expired():
    c = TickerCache(ttl_s=0.01)
    c.set("A", {"v": 1})
    c.set("B", {"v": 2})
    time.sleep(0.02)
    c.set("C", {"v": 3})
    assert "A" not in c.all()
    assert "B" not in c.all()
    assert "C" in c.all()

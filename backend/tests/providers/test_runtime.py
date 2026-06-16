"""Tests for the RateLimitParser."""
from __future__ import annotations

from datetime import datetime, timezone

from app.services.providers.base import RateLimitInfo
from app.services.providers.runtime import RateLimitParser


def test_parse_standard_ratelimit_headers():
    headers = {
        "X-RateLimit-Remaining": "42",
        "X-RateLimit-Limit": "100",
        "X-RateLimit-Reset": "1700000000",
    }
    info = RateLimitParser.parse(headers)
    assert info is not None
    assert info.remaining == 42
    assert info.limit == 100
    assert info.reset_at is not None
    assert info.source.startswith("header:")


def test_parse_binance_weight_header():
    headers = {"X-MBX-USED-WEIGHT-1M": "950"}
    info = RateLimitParser.parse(headers)
    assert info is not None
    assert info.remaining == 6000 - 950  # default Binance spot weight capacity
    assert "x-mbx-used-weight-1m" in info.source


def test_parse_retry_after_seconds():
    headers = {"Retry-After": "30"}
    info = RateLimitParser.parse(headers)
    assert info is not None
    assert info.retry_after_s == 30


def test_parse_unknown_provider_returns_none():
    assert RateLimitParser.parse({}) is None
    assert RateLimitParser.parse({"Content-Type": "application/json"}) is None


def test_parse_case_insensitive():
    headers = {"x-ratelimit-remaining": "5"}
    info = RateLimitParser.parse(headers)
    assert info is not None
    assert info.remaining == 5

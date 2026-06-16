"""Rate-limit header parser.

Sub-project 1 of the Provider Adapter Foundation.
"""
from __future__ import annotations

from datetime import datetime, timezone
from email.utils import parsedate_to_datetime

from app.services.providers.base import RateLimitInfo


class RateLimitParser:
    """Parses common rate-limit HTTP headers into a RateLimitInfo.

    Headers covered (case-insensitive):
    - X-RateLimit-Remaining / X-RateLimit-Limit / X-RateLimit-Reset
    - X-MBX-USED-WEIGHT-1M (Binance)
    - X-Bapi-Limit-Status / X-Bapi-Limit (Binance public v3)
    - Coinglass-RateLimit-Remaining
    - Retry-After (HTTP standard, seconds or HTTP-date)
    """

    # Binance spot default weight capacity per minute (informational default)
    BINANCE_SPOT_WEIGHT_CAPACITY_1M = 6000

    @classmethod
    def parse(cls, headers: dict[str, str]) -> RateLimitInfo | None:
        # Normalize keys to lowercase for lookup
        lower = {k.lower(): v for k, v in headers.items() if isinstance(v, str)}

        remaining: int | None = None
        limit: int | None = None
        reset_at: datetime | None = None
        retry_after_s: int | None = None
        source: str = ""

        # Standard X-RateLimit-* family
        # Exact match (e.g. X-RateLimit-Remaining)
        if "x-ratelimit-remaining" in lower:
            remaining = int(lower["x-ratelimit-remaining"])
            source = "header:x-ratelimit-remaining"
        # Suffixed variants (e.g. Groq: X-RateLimit-Remaining-Requests)
        if remaining is None:
            for key in ("x-ratelimit-remaining-requests", "x-ratelimit-remaining-tokens"):
                if key in lower:
                    remaining = int(lower[key])
                    source = f"header:{key}"
                    break

        if "x-ratelimit-limit" in lower:
            limit = int(lower["x-ratelimit-limit"])
        if limit is None:
            for key in ("x-ratelimit-limit-requests", "x-ratelimit-limit-tokens"):
                if key in lower:
                    limit = int(lower[key])
                    break
        if "x-ratelimit-reset" in lower:
            reset_at = cls._parse_reset(lower["x-ratelimit-reset"])

        # Binance used weight (subtract from capacity)
        if "x-mbx-used-weight-1m" in lower:
            used = int(lower["x-mbx-used-weight-1m"])
            capacity = cls.BINANCE_SPOT_WEIGHT_CAPACITY_1M
            remaining = max(0, capacity - used)
            limit = capacity
            source = "header:x-mbx-used-weight-1m"

        # Binance v3 headers
        if "x-bapi-limit-status" in lower:
            remaining = int(lower["x-bapi-limit-status"])
            source = "header:x-bapi-limit-status"
        if "x-bapi-limit" in lower:
            limit = int(lower["x-bapi-limit"])

        # Coinglass-style
        if "coinglass-ratelimit-remaining" in lower:
            remaining = int(lower["coinglass-ratelimit-remaining"])
            source = "header:coinglass-ratelimit-remaining"

        # Retry-After (HTTP standard)
        if "retry-after" in lower:
            retry_after_s = cls._parse_retry_after(lower["retry-after"])
            # If we have nothing else, treat Retry-After alone as a signal
            if not source:
                source = "header:retry-after"

        if not source:
            return None

        return RateLimitInfo(
            remaining=remaining,
            limit=limit,
            reset_at=reset_at,
            retry_after_s=retry_after_s,
            source=source,
        )

    @staticmethod
    def _parse_reset(value: str) -> datetime | None:
        # Try Unix timestamp first, then HTTP-date
        try:
            ts = int(value)
            return datetime.fromtimestamp(ts, tz=timezone.utc)
        except (ValueError, TypeError):
            pass
        try:
            dt = parsedate_to_datetime(value)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            return dt
        except (TypeError, ValueError):
            return None

    @staticmethod
    def _parse_retry_after(value: str) -> int | None:
        try:
            return int(value)
        except (ValueError, TypeError):
            pass
        try:
            dt = parsedate_to_datetime(value)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=timezone.utc)
            delta = dt - datetime.now(timezone.utc)
            return max(0, int(delta.total_seconds()))
        except (TypeError, ValueError):
            return None

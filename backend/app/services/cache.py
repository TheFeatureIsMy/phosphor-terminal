"""
Simple in-memory cache service
"""
import time
from typing import Any, Optional


class CacheService:
    def __init__(self, default_ttl: int = 300):
        self._cache: dict[str, tuple[Any, float]] = {}
        self.default_ttl = default_ttl

    def get(self, key: str) -> Optional[Any]:
        """Get value from cache"""
        if key in self._cache:
            value, expiry = self._cache[key]
            if time.time() < expiry:
                return value
            else:
                del self._cache[key]
        return None

    def set(self, key: str, value: Any, ttl: Optional[int] = None) -> None:
        """Set value in cache"""
        expiry = time.time() + (ttl or self.default_ttl)
        self._cache[key] = (value, expiry)

    def delete(self, key: str) -> None:
        """Delete value from cache"""
        if key in self._cache:
            del self._cache[key]

    def clear(self) -> None:
        """Clear all cache"""
        self._cache.clear()

    def has(self, key: str) -> bool:
        """Check if key exists and is not expired"""
        return self.get(key) is not None


# Global cache instance
cache = CacheService()

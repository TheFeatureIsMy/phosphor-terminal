"""
LRU Cache utilities
"""
from typing import TypeVar, Generic, Dict, Optional, List, Tuple
from collections import OrderedDict

K = TypeVar('K')
V = TypeVar('V')


class LRUCache(Generic[K, V]):
    """LRU Cache implementation"""
    def __init__(self, max_size: int):
        self._max_size = max_size
        self._cache: OrderedDict[K, V] = OrderedDict()

    def get(self, key: K) -> Optional[V]:
        """Get value by key"""
        if key not in self._cache:
            return None
        self._cache.move_to_end(key)
        return self._cache[key]

    def set(self, key: K, value: V) -> None:
        """Set key-value pair"""
        if key in self._cache:
            self._cache.move_to_end(key)
        elif len(self._cache) >= self._max_size:
            self._cache.popitem(last=False)
        self._cache[key] = value

    def has(self, key: K) -> bool:
        """Check if key exists"""
        return key in self._cache

    def delete(self, key: K) -> bool:
        """Delete key"""
        if key in self._cache:
            del self._cache[key]
            return True
        return False

    def clear(self) -> None:
        """Clear all items"""
        self._cache.clear()

    @property
    def size(self) -> int:
        """Get cache size"""
        return len(self._cache)

    def keys(self) -> List[K]:
        """Get all keys"""
        return list(self._cache.keys())

    def values(self) -> List[V]:
        """Get all values"""
        return list(self._cache.values())

    def items(self) -> List[Tuple[K, V]]:
        """Get all items"""
        return list(self._cache.items())

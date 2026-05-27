"""
Map/Dictionary utilities
"""
from typing import TypeVar, Generic, Dict, List, Tuple, Optional, Callable

K = TypeVar('K')
V = TypeVar('V')
U = TypeVar('U')


class Dictionary(Generic[K, V]):
    """Dictionary wrapper with utility methods"""
    def __init__(self):
        self._items: Dict[K, V] = {}

    def set(self, key: K, value: V) -> None:
        """Set a key-value pair"""
        self._items[key] = value

    def get(self, key: K, default: Optional[V] = None) -> Optional[V]:
        """Get value by key"""
        return self._items.get(key, default)

    def has(self, key: K) -> bool:
        """Check if key exists"""
        return key in self._items

    def delete(self, key: K) -> bool:
        """Delete key-value pair"""
        if key in self._items:
            del self._items[key]
            return True
        return False

    def clear(self) -> None:
        """Clear all items"""
        self._items.clear()

    @property
    def size(self) -> int:
        """Get dictionary size"""
        return len(self._items)

    def keys(self) -> List[K]:
        """Get all keys"""
        return list(self._items.keys())

    def values(self) -> List[V]:
        """Get all values"""
        return list(self._items.values())

    def items(self) -> List[Tuple[K, V]]:
        """Get all key-value pairs"""
        return list(self._items.items())

    def map(self, fn: Callable[[V, K], U]) -> 'Dictionary[K, U]':
        """Map values"""
        result: Dictionary[K, U] = Dictionary()
        for key, value in self._items.items():
            result.set(key, fn(value, key))
        return result

    def filter(self, fn: Callable[[V, K], bool]) -> 'Dictionary[K, V]':
        """Filter items"""
        result: Dictionary[K, V] = Dictionary()
        for key, value in self._items.items():
            if fn(value, key):
                result.set(key, value)
        return result

    def to_dict(self) -> Dict[K, V]:
        """Convert to dictionary"""
        return self._items.copy()

    @classmethod
    def from_dict(cls, d: Dict[K, V]) -> 'Dictionary[K, V]':
        """Create from dictionary"""
        dict_obj = cls()
        dict_obj._items = d.copy()
        return dict_obj

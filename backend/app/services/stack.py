"""
Stack utilities
"""
from typing import TypeVar, Generic, List, Optional

T = TypeVar('T')


class Stack(Generic[T]):
    """Simple stack implementation"""
    def __init__(self):
        self._items: List[T] = []

    def push(self, item: T) -> None:
        """Push item onto stack"""
        self._items.append(item)

    def pop(self) -> Optional[T]:
        """Pop item from stack"""
        if self._items:
            return self._items.pop()
        return None

    def peek(self) -> Optional[T]:
        """Peek at top item without removing"""
        if self._items:
            return self._items[-1]
        return None

    @property
    def size(self) -> int:
        """Get stack size"""
        return len(self._items)

    @property
    def is_empty(self) -> bool:
        """Check if stack is empty"""
        return len(self._items) == 0

    def clear(self) -> None:
        """Clear all items"""
        self._items.clear()

    def to_list(self) -> List[T]:
        """Convert to list"""
        return list(self._items)

    def contains(self, item: T) -> bool:
        """Check if item is in stack"""
        return item in self._items

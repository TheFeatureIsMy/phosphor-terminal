"""
Queue utilities
"""
from typing import TypeVar, Generic, List, Optional
from collections import deque

T = TypeVar('T')


class Queue(Generic[T]):
    """Simple queue implementation"""
    def __init__(self):
        self._items: deque[T] = deque()

    def enqueue(self, item: T) -> None:
        """Add item to queue"""
        self._items.append(item)

    def dequeue(self) -> Optional[T]:
        """Remove and return item from queue"""
        if self._items:
            return self._items.popleft()
        return None

    def peek(self) -> Optional[T]:
        """Return first item without removing"""
        if self._items:
            return self._items[0]
        return None

    @property
    def size(self) -> int:
        """Get queue size"""
        return len(self._items)

    @property
    def is_empty(self) -> bool:
        """Check if queue is empty"""
        return len(self._items) == 0

    def clear(self) -> None:
        """Clear all items"""
        self._items.clear()

    def to_list(self) -> List[T]:
        """Convert to list"""
        return list(self._items)


class PriorityQueue(Generic[T]):
    """Priority queue implementation"""
    def __init__(self):
        self._items: List[tuple[int, T]] = []

    def enqueue(self, item: T, priority: int) -> None:
        """Add item with priority"""
        self._items.append((priority, item))
        self._items.sort(key=lambda x: x[0])

    def dequeue(self) -> Optional[T]:
        """Remove and return highest priority item"""
        if self._items:
            return self._items.pop(0)[1]
        return None

    def peek(self) -> Optional[T]:
        """Return highest priority item without removing"""
        if self._items:
            return self._items[0][1]
        return None

    @property
    def size(self) -> int:
        """Get queue size"""
        return len(self._items)

    @property
    def is_empty(self) -> bool:
        """Check if queue is empty"""
        return len(self._items) == 0

    def clear(self) -> None:
        """Clear all items"""
        self._items.clear()

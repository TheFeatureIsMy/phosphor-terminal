"""
Ring Buffer utilities
"""
from typing import TypeVar, Generic, List, Optional

T = TypeVar('T')


class RingBuffer(Generic[T]):
    """Ring buffer implementation"""
    def __init__(self, capacity: int):
        self._capacity = capacity
        self._buffer: List[Optional[T]] = [None] * capacity
        self._head = 0
        self._tail = 0
        self._size = 0

    def push(self, item: T) -> None:
        """Push item to buffer"""
        self._buffer[self._tail] = item
        self._tail = (self._tail + 1) % self._capacity

        if self._size == self._capacity:
            self._head = (self._head + 1) % self._capacity
        else:
            self._size += 1

    def pop(self) -> Optional[T]:
        """Pop item from buffer"""
        if self._size == 0:
            return None

        item = self._buffer[self._head]
        self._buffer[self._head] = None
        self._head = (self._head + 1) % self._capacity
        self._size -= 1
        return item

    def peek(self) -> Optional[T]:
        """Peek at first item"""
        if self._size == 0:
            return None
        return self._buffer[self._head]

    def get(self, index: int) -> Optional[T]:
        """Get item at index"""
        if index < 0 or index >= self._size:
            return None
        return self._buffer[(self._head + index) % self._capacity]

    @property
    def length(self) -> int:
        """Get buffer size"""
        return self._size

    @property
    def is_full(self) -> bool:
        """Check if buffer is full"""
        return self._size == self._capacity

    @property
    def is_empty(self) -> bool:
        """Check if buffer is empty"""
        return self._size == 0

    def clear(self) -> None:
        """Clear buffer"""
        self._buffer = [None] * self._capacity
        self._head = 0
        self._tail = 0
        self._size = 0

    def to_list(self) -> List[T]:
        """Convert to list"""
        result: List[T] = []
        for i in range(self._size):
            item = self.get(i)
            if item is not None:
                result.append(item)
        return result

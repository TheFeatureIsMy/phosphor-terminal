"""
Heap utilities
"""
from typing import TypeVar, Generic, List, Callable, Optional

T = TypeVar('T')


class MinHeap(Generic[T]):
    """Min heap implementation"""
    def __init__(self, compare: Callable[[T, T], int]):
        self._items: List[T] = []
        self._compare = compare

    def insert(self, value: T) -> None:
        """Insert a value"""
        self._items.append(value)
        self._bubble_up(len(self._items) - 1)

    def extract_min(self) -> Optional[T]:
        """Extract minimum value"""
        if not self._items:
            return None
        if len(self._items) == 1:
            return self._items.pop()

        min_val = self._items[0]
        self._items[0] = self._items.pop()
        self._bubble_down(0)
        return min_val

    def peek(self) -> Optional[T]:
        """Peek at minimum value"""
        return self._items[0] if self._items else None

    @property
    def size(self) -> int:
        """Get heap size"""
        return len(self._items)

    @property
    def is_empty(self) -> bool:
        """Check if heap is empty"""
        return len(self._items) == 0

    def _bubble_up(self, index: int) -> None:
        """Bubble up element"""
        while index > 0:
            parent = (index - 1) // 2
            if self._compare(self._items[index], self._items[parent]) >= 0:
                break
            self._items[index], self._items[parent] = self._items[parent], self._items[index]
            index = parent

    def _bubble_down(self, index: int) -> None:
        """Bubble down element"""
        while True:
            smallest = index
            left = 2 * index + 1
            right = 2 * index + 2

            if (left < len(self._items) and
                self._compare(self._items[left], self._items[smallest]) < 0):
                smallest = left

            if (right < len(self._items) and
                self._compare(self._items[right], self._items[smallest]) < 0):
                smallest = right

            if smallest == index:
                break

            self._items[index], self._items[smallest] = self._items[smallest], self._items[index]
            index = smallest


class MaxHeap(Generic[T]):
    """Max heap implementation"""
    def __init__(self, compare: Callable[[T, T], int]):
        self._items: List[T] = []
        self._compare = compare

    def insert(self, value: T) -> None:
        """Insert a value"""
        self._items.append(value)
        self._bubble_up(len(self._items) - 1)

    def extract_max(self) -> Optional[T]:
        """Extract maximum value"""
        if not self._items:
            return None
        if len(self._items) == 1:
            return self._items.pop()

        max_val = self._items[0]
        self._items[0] = self._items.pop()
        self._bubble_down(0)
        return max_val

    def peek(self) -> Optional[T]:
        """Peek at maximum value"""
        return self._items[0] if self._items else None

    @property
    def size(self) -> int:
        """Get heap size"""
        return len(self._items)

    @property
    def is_empty(self) -> bool:
        """Check if heap is empty"""
        return len(self._items) == 0

    def _bubble_up(self, index: int) -> None:
        """Bubble up element"""
        while index > 0:
            parent = (index - 1) // 2
            if self._compare(self._items[index], self._items[parent]) <= 0:
                break
            self._items[index], self._items[parent] = self._items[parent], self._items[index]
            index = parent

    def _bubble_down(self, index: int) -> None:
        """Bubble down element"""
        while True:
            largest = index
            left = 2 * index + 1
            right = 2 * index + 2

            if (left < len(self._items) and
                self._compare(self._items[left], self._items[largest]) > 0):
                largest = left

            if (right < len(self._items) and
                self._compare(self._items[right], self._items[largest]) > 0):
                largest = right

            if largest == index:
                break

            self._items[index], self._items[largest] = self._items[largest], self._items[index]
            index = largest

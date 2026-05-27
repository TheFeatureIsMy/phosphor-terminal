"""
Linked List utilities
"""
from typing import TypeVar, Generic, Optional, List

T = TypeVar('T')


class ListNode(Generic[T]):
    """Linked list node"""
    def __init__(self, value: T, next_node: Optional['ListNode[T]'] = None):
        self.value = value
        self.next = next_node


class LinkedList(Generic[T]):
    """Linked list implementation"""
    def __init__(self):
        self._head: Optional[ListNode[T]] = None
        self._size = 0

    def append(self, value: T) -> None:
        """Append value to end"""
        node = ListNode(value)
        if not self._head:
            self._head = node
        else:
            current = self._head
            while current.next:
                current = current.next
            current.next = node
        self._size += 1

    def prepend(self, value: T) -> None:
        """Prepend value to start"""
        node = ListNode(value, self._head)
        self._head = node
        self._size += 1

    def insert_at(self, index: int, value: T) -> None:
        """Insert value at index"""
        if index < 0 or index > self._size:
            raise IndexError("Index out of bounds")

        if index == 0:
            self.prepend(value)
            return

        node = ListNode(value)
        current = self._head
        for _ in range(index - 1):
            current = current.next
        node.next = current.next
        current.next = node
        self._size += 1

    def remove_at(self, index: int) -> Optional[T]:
        """Remove value at index"""
        if index < 0 or index >= self._size or not self._head:
            return None

        if index == 0:
            value = self._head.value
            self._head = self._head.next
        else:
            current = self._head
            for _ in range(index - 1):
                current = current.next
            value = current.next.value
            current.next = current.next.next
        self._size -= 1
        return value

    def get(self, index: int) -> Optional[T]:
        """Get value at index"""
        if index < 0 or index >= self._size or not self._head:
            return None

        current = self._head
        for _ in range(index):
            current = current.next
        return current.value

    def find(self, value: T) -> int:
        """Find index of value"""
        current = self._head
        index = 0
        while current:
            if current.value == value:
                return index
            current = current.next
            index += 1
        return -1

    def contains(self, value: T) -> bool:
        """Check if value exists"""
        return self.find(value) != -1

    @property
    def size(self) -> int:
        """Get list size"""
        return self._size

    @property
    def is_empty(self) -> bool:
        """Check if list is empty"""
        return self._size == 0

    def to_list(self) -> List[T]:
        """Convert to list"""
        result: List[T] = []
        current = self._head
        while current:
            result.append(current.value)
            current = current.next
        return result

    def clear(self) -> None:
        """Clear all items"""
        self._head = None
        self._size = 0

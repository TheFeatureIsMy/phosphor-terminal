"""
Skip List utilities
"""
import random
from typing import TypeVar, Generic, List, Optional, Callable

T = TypeVar('T')


class SkipListNode(Generic[T]):
    """Skip list node"""
    def __init__(self, value: Optional[T], level: int):
        self.value = value
        self.forward: List[Optional['SkipListNode[T]']] = [None] * (level + 1)


class SkipList(Generic[T]):
    """Skip list implementation"""
    def __init__(self, max_level: int, compare: Callable[[T, T], int]):
        self._max_level = max_level
        self._compare = compare
        self._head = SkipListNode(None, max_level)
        self._level = 0
        self._size = 0

    def _random_level(self) -> int:
        """Generate random level"""
        level = 0
        while random.random() < 0.5 and level < self._max_level:
            level += 1
        return level

    def insert(self, value: T) -> None:
        """Insert a value"""
        update: List[Optional[SkipListNode[T]]] = [None] * (self._max_level + 1)
        current = self._head

        for i in range(self._level, -1, -1):
            while (current.forward[i] and
                   self._compare(current.forward[i].value, value) < 0):
                current = current.forward[i]
            update[i] = current

        current = current.forward[0]

        if not current or self._compare(current.value, value) != 0:
            new_level = self._random_level()

            if new_level > self._level:
                for i in range(self._level + 1, new_level + 1):
                    update[i] = self._head
                self._level = new_level

            new_node = SkipListNode(value, new_level)

            for i in range(new_level + 1):
                new_node.forward[i] = update[i].forward[i]
                update[i].forward[i] = new_node

            self._size += 1

    def search(self, value: T) -> bool:
        """Search for a value"""
        current = self._head

        for i in range(self._level, -1, -1):
            while (current.forward[i] and
                   self._compare(current.forward[i].value, value) < 0):
                current = current.forward[i]

        current = current.forward[0]
        return current is not None and self._compare(current.value, value) == 0

    def delete(self, value: T) -> bool:
        """Delete a value"""
        update: List[Optional[SkipListNode[T]]] = [None] * (self._max_level + 1)
        current = self._head

        for i in range(self._level, -1, -1):
            while (current.forward[i] and
                   self._compare(current.forward[i].value, value) < 0):
                current = current.forward[i]
            update[i] = current

        current = current.forward[0]

        if current and self._compare(current.value, value) == 0:
            for i in range(self._level + 1):
                if update[i].forward[i] != current:
                    break
                update[i].forward[i] = current.forward[i]

            while self._level > 0 and not self._head.forward[self._level]:
                self._level -= 1

            self._size -= 1
            return True

        return False

    @property
    def length(self) -> int:
        """Get list size"""
        return self._size

    def to_list(self) -> List[T]:
        """Convert to list"""
        result: List[T] = []
        current = self._head.forward[0]

        while current:
            result.append(current.value)
            current = current.forward[0]

        return result

"""
Bloom Filter utilities
"""
import math


class BloomFilter:
    """Bloom filter implementation"""
    def __init__(self, size: int, hash_count: int):
        self._size = size
        self._hash_count = hash_count
        self._bits = [False] * size

    def add(self, item: str) -> None:
        """Add an item"""
        for i in range(self._hash_count):
            index = self._hash(item, i) % self._size
            self._bits[index] = True

    def contains(self, item: str) -> bool:
        """Check if item might exist"""
        for i in range(self._hash_count):
            index = self._hash(item, i) % self._size
            if not self._bits[index]:
                return False
        return True

    def _hash(self, item: str, seed: int) -> int:
        """Hash function"""
        hash_val = 0
        for char in item:
            hash_val = ((hash_val << 5) - hash_val + ord(char) + seed) & 0xFFFFFFFF
        return abs(hash_val)

    def clear(self) -> None:
        """Clear all bits"""
        self._bits = [False] * self._size

    def get_false_positive_rate(self) -> float:
        """Calculate false positive rate"""
        set_bits = sum(self._bits)
        return (set_bits / self._size) ** self._hash_count

    @staticmethod
    def optimal_size(expected_items: int, fp_rate: float) -> tuple[int, int]:
        """Calculate optimal size and hash count"""
        size = int(-expected_items * math.log(fp_rate) / (math.log(2) ** 2))
        hash_count = int((size / expected_items) * math.log(2))
        return size, max(1, hash_count)

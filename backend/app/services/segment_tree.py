"""
Segment Tree utilities
"""
from typing import List, Callable


class SegmentTree:
    """Segment tree implementation"""
    def __init__(self, arr: List[int], combine: Callable[[int, int], int]):
        self._n = len(arr)
        self._combine = combine
        self._tree = [0] * (4 * self._n)
        self._build(arr, 1, 0, self._n - 1)

    def _build(self, arr: List[int], node: int, start: int, end: int) -> None:
        """Build segment tree"""
        if start == end:
            self._tree[node] = arr[start]
        else:
            mid = (start + end) // 2
            self._build(arr, 2 * node, start, mid)
            self._build(arr, 2 * node + 1, mid + 1, end)
            self._tree[node] = self._combine(self._tree[2 * node], self._tree[2 * node + 1])

    def update(self, index: int, value: int) -> None:
        """Update value at index"""
        self._update_helper(1, 0, self._n - 1, index, value)

    def _update_helper(self, node: int, start: int, end: int, index: int, value: int) -> None:
        """Update helper"""
        if start == end:
            self._tree[node] = value
        else:
            mid = (start + end) // 2
            if index <= mid:
                self._update_helper(2 * node, start, mid, index, value)
            else:
                self._update_helper(2 * node + 1, mid + 1, end, index, value)
            self._tree[node] = self._combine(self._tree[2 * node], self._tree[2 * node + 1])

    def query(self, left: int, right: int) -> int:
        """Query range [left, right]"""
        return self._query_helper(1, 0, self._n - 1, left, right)

    def _query_helper(self, node: int, start: int, end: int, left: int, right: int) -> int:
        """Query helper"""
        if right < start or end < left:
            return 0
        if left <= start and end <= right:
            return self._tree[node]
        mid = (start + end) // 2
        left_result = self._query_helper(2 * node, start, mid, left, right)
        right_result = self._query_helper(2 * node + 1, mid + 1, end, left, right)
        return self._combine(left_result, right_result)

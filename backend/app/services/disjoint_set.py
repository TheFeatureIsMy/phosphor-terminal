"""
Disjoint Set (Union-Find) utilities
"""
from typing import List, Dict


class DisjointSet:
    """Disjoint Set implementation"""
    def __init__(self, size: int):
        self._parent = list(range(size))
        self._rank = [0] * size

    def find(self, x: int) -> int:
        """Find root of element"""
        if self._parent[x] != x:
            self._parent[x] = self.find(self._parent[x])
        return self._parent[x]

    def union(self, x: int, y: int) -> bool:
        """Union two sets"""
        root_x = self.find(x)
        root_y = self.find(y)

        if root_x == root_y:
            return False

        if self._rank[root_x] < self._rank[root_y]:
            self._parent[root_x] = root_y
        elif self._rank[root_x] > self._rank[root_y]:
            self._parent[root_y] = root_x
        else:
            self._parent[root_y] = root_x
            self._rank[root_x] += 1

        return True

    def connected(self, x: int, y: int) -> bool:
        """Check if two elements are connected"""
        return self.find(x) == self.find(y)

    def get_components(self) -> List[List[int]]:
        """Get all components"""
        components: Dict[int, List[int]] = {}
        for i in range(len(self._parent)):
            root = self.find(i)
            if root not in components:
                components[root] = []
            components[root].append(i)
        return list(components.values())

    def get_component_count(self) -> int:
        """Get number of components"""
        return len(set(self.find(i) for i in range(len(self._parent))))

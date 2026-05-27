"""
Graph utilities
"""
from typing import TypeVar, Generic, Dict, Set, List, Optional
from collections import deque

T = TypeVar('T')


class Graph(Generic[T]):
    """Graph implementation with adjacency list"""
    def __init__(self):
        self._adjacency_list: Dict[T, Set[T]] = {}

    def add_vertex(self, vertex: T) -> None:
        """Add a vertex"""
        if vertex not in self._adjacency_list:
            self._adjacency_list[vertex] = set()

    def add_edge(self, from_vertex: T, to_vertex: T) -> None:
        """Add an edge"""
        self.add_vertex(from_vertex)
        self.add_vertex(to_vertex)
        self._adjacency_list[from_vertex].add(to_vertex)

    def remove_vertex(self, vertex: T) -> None:
        """Remove a vertex"""
        self._adjacency_list.pop(vertex, None)
        for neighbors in self._adjacency_list.values():
            neighbors.discard(vertex)

    def remove_edge(self, from_vertex: T, to_vertex: T) -> None:
        """Remove an edge"""
        if from_vertex in self._adjacency_list:
            self._adjacency_list[from_vertex].discard(to_vertex)

    def has_vertex(self, vertex: T) -> bool:
        """Check if vertex exists"""
        return vertex in self._adjacency_list

    def has_edge(self, from_vertex: T, to_vertex: T) -> bool:
        """Check if edge exists"""
        return to_vertex in self._adjacency_list.get(from_vertex, set())

    def get_neighbors(self, vertex: T) -> List[T]:
        """Get neighbors of a vertex"""
        return list(self._adjacency_list.get(vertex, set()))

    def get_vertices(self) -> List[T]:
        """Get all vertices"""
        return list(self._adjacency_list.keys())

    @property
    def size(self) -> int:
        """Get number of vertices"""
        return len(self._adjacency_list)

    def bfs(self, start: T) -> List[T]:
        """Breadth-first search"""
        visited: Set[T] = set()
        queue: deque[T] = deque([start])
        result: List[T] = []

        visited.add(start)

        while queue:
            vertex = queue.popleft()
            result.append(vertex)

            for neighbor in self.get_neighbors(vertex):
                if neighbor not in visited:
                    visited.add(neighbor)
                    queue.append(neighbor)

        return result

    def dfs(self, start: T) -> List[T]:
        """Depth-first search"""
        visited: Set[T] = set()
        result: List[T] = []

        def dfs_helper(vertex: T) -> None:
            visited.add(vertex)
            result.append(vertex)

            for neighbor in self.get_neighbors(vertex):
                if neighbor not in visited:
                    dfs_helper(neighbor)

        dfs_helper(start)
        return result

    def has_cycle(self) -> bool:
        """Check if graph has a cycle"""
        visited: Set[T] = set()
        recursion_stack: Set[T] = set()

        def has_cycle_helper(vertex: T) -> bool:
            visited.add(vertex)
            recursion_stack.add(vertex)

            for neighbor in self.get_neighbors(vertex):
                if neighbor not in visited:
                    if has_cycle_helper(neighbor):
                        return True
                elif neighbor in recursion_stack:
                    return True

            recursion_stack.discard(vertex)
            return False

        for vertex in self.get_vertices():
            if vertex not in visited:
                if has_cycle_helper(vertex):
                    return True

        return False

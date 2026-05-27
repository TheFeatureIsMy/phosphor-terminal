"""
Tree utilities
"""
from typing import TypeVar, Generic, List, Optional

T = TypeVar('T')


class TreeNode(Generic[T]):
    """Tree node"""
    def __init__(self, value: T):
        self.value = value
        self.children: List[TreeNode[T]] = []


class Tree(Generic[T]):
    """Tree implementation"""
    def __init__(self, root_value: Optional[T] = None):
        self._root: Optional[TreeNode[T]] = None
        if root_value is not None:
            self._root = TreeNode(root_value)

    def get_root(self) -> Optional[T]:
        """Get root value"""
        return self._root.value if self._root else None

    def set_root(self, value: T) -> None:
        """Set root value"""
        self._root = TreeNode(value)

    def add_child(self, parent_value: T, child_value: T) -> bool:
        """Add child to parent"""
        parent = self._find_node(parent_value)
        if not parent:
            return False
        parent.children.append(TreeNode(child_value))
        return True

    def remove(self, value: T) -> bool:
        """Remove a node"""
        if not self._root:
            return False
        if self._root.value == value:
            self._root = None
            return True
        return self._remove_node(self._root, value)

    def _remove_node(self, node: TreeNode[T], value: T) -> bool:
        """Remove node helper"""
        for i, child in enumerate(node.children):
            if child.value == value:
                node.children.pop(i)
                return True
            if self._remove_node(child, value):
                return True
        return False

    def find(self, value: T) -> bool:
        """Find a node"""
        return self._find_node(value) is not None

    def _find_node(self, value: T) -> Optional[TreeNode[T]]:
        """Find node helper"""
        if not self._root:
            return None
        return self._find_node_helper(self._root, value)

    def _find_node_helper(self, node: TreeNode[T], value: T) -> Optional[TreeNode[T]]:
        """Find node helper"""
        if node.value == value:
            return node
        for child in node.children:
            found = self._find_node_helper(child, value)
            if found:
                return found
        return None

    def get_children(self, value: T) -> List[T]:
        """Get children of a node"""
        node = self._find_node(value)
        return [child.value for child in node.children] if node else []

    def get_parent(self, value: T) -> Optional[T]:
        """Get parent of a node"""
        if not self._root or self._root.value == value:
            return None
        return self._get_parent_helper(self._root, value)

    def _get_parent_helper(self, node: TreeNode[T], value: T) -> Optional[T]:
        """Get parent helper"""
        for child in node.children:
            if child.value == value:
                return node.value
            parent = self._get_parent_helper(child, value)
            if parent is not None:
                return parent
        return None

    def get_height(self) -> int:
        """Get tree height"""
        if not self._root:
            return 0
        return self._get_height_helper(self._root)

    def _get_height_helper(self, node: TreeNode[T]) -> int:
        """Get height helper"""
        if not node.children:
            return 1
        return 1 + max(self._get_height_helper(child) for child in node.children)

    def traverse_bfs(self) -> List[T]:
        """Breadth-first traversal"""
        if not self._root:
            return []
        result: List[T] = []
        queue = [self._root]
        while queue:
            node = queue.pop(0)
            result.append(node.value)
            queue.extend(node.children)
        return result

    def traverse_dfs(self) -> List[T]:
        """Depth-first traversal"""
        if not self._root:
            return []
        result: List[T] = []
        self._traverse_dfs_helper(self._root, result)
        return result

    def _traverse_dfs_helper(self, node: TreeNode[T], result: List[T]) -> None:
        """DFS helper"""
        result.append(node.value)
        for child in node.children:
            self._traverse_dfs_helper(child, result)

    @property
    def size(self) -> int:
        """Get tree size"""
        return len(self.traverse_bfs())

    @property
    def is_empty(self) -> bool:
        """Check if tree is empty"""
        return self._root is None

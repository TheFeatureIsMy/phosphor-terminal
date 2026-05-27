"""
Trie utilities
"""
from typing import Dict, List


class TrieNode:
    """Trie node"""
    def __init__(self):
        self.children: Dict[str, 'TrieNode'] = {}
        self.is_end = False


class Trie:
    """Trie implementation"""
    def __init__(self):
        self._root = TrieNode()

    def insert(self, word: str) -> None:
        """Insert a word"""
        node = self._root
        for char in word:
            if char not in node.children:
                node.children[char] = TrieNode()
            node = node.children[char]
        node.is_end = True

    def search(self, word: str) -> bool:
        """Search for a word"""
        node = self._find_node(word)
        return node.is_end if node else False

    def starts_with(self, prefix: str) -> bool:
        """Check if prefix exists"""
        return self._find_node(prefix) is not None

    def _find_node(self, prefix: str) -> TrieNode:
        """Find node for prefix"""
        node = self._root
        for char in prefix:
            if char not in node.children:
                return None
            node = node.children[char]
        return node

    def autocomplete(self, prefix: str, max_results: int = 10) -> List[str]:
        """Autocomplete with prefix"""
        node = self._find_node(prefix)
        if not node:
            return []

        results: List[str] = []
        self._collect_words(node, prefix, results, max_results)
        return results

    def _collect_words(self, node: TrieNode, prefix: str, results: List[str], max_results: int) -> None:
        """Collect words from node"""
        if len(results) >= max_results:
            return

        if node.is_end:
            results.append(prefix)

        for char, child in node.children.items():
            self._collect_words(child, prefix + char, results, max_results)

    def delete(self, word: str) -> bool:
        """Delete a word"""
        return self._delete_helper(self._root, word, 0)

    def _delete_helper(self, node: TrieNode, word: str, index: int) -> bool:
        """Delete helper"""
        if index == len(word):
            if not node.is_end:
                return False
            node.is_end = False
            return len(node.children) == 0

        char = word[index]
        child = node.children.get(char)
        if not child:
            return False

        should_delete = self._delete_helper(child, word, index + 1)

        if should_delete:
            del node.children[char]
            return len(node.children) == 0 and not node.is_end

        return False

    @property
    def size(self) -> int:
        """Get number of words"""
        count = 0
        self._count_words(self._root, lambda: nonlocal(count))
        return count

    def _count_words(self, node: TrieNode, increment) -> None:
        """Count words"""
        if node.is_end:
            increment()
        for child in node.children.values():
            self._count_words(child, increment)

    def get_all_words(self) -> List[str]:
        """Get all words"""
        words: List[str] = []
        self._collect_words(self._root, '', words, float('inf'))
        return words

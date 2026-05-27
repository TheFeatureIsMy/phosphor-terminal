/**
 * Trie utilities
 */

class TrieNode {
  children = new Map<string, TrieNode>()
  isEnd = false
}

export class Trie {
  private root = new TrieNode()

  insert(word: string): void {
    let node = this.root
    for (const char of word) {
      if (!node.children.has(char)) {
        node.children.set(char, new TrieNode())
      }
      node = node.children.get(char)!
    }
    node.isEnd = true
  }

  search(word: string): boolean {
    const node = this.findNode(word)
    return node?.isEnd ?? false
  }

  startsWith(prefix: string): boolean {
    return this.findNode(prefix) !== null
  }

  private findNode(prefix: string): TrieNode | null {
    let node = this.root
    for (const char of prefix) {
      if (!node.children.has(char)) {
        return null
      }
      node = node.children.get(char)!
    }
    return node
  }

  autocomplete(prefix: string, maxResults: number = 10): string[] {
    const node = this.findNode(prefix)
    if (!node) return []

    const results: string[] = []
    this.collectWords(node, prefix, results, maxResults)
    return results
  }

  private collectWords(node: TrieNode, prefix: string, results: string[], maxResults: number): void {
    if (results.length >= maxResults) return

    if (node.isEnd) {
      results.push(prefix)
    }

    for (const [char, child] of node.children) {
      this.collectWords(child, prefix + char, results, maxResults)
    }
  }

  delete(word: string): boolean {
    return this.deleteHelper(this.root, word, 0)
  }

  private deleteHelper(node: TrieNode, word: string, index: number): boolean {
    if (index === word.length) {
      if (!node.isEnd) return false
      node.isEnd = false
      return node.children.size === 0
    }

    const char = word[index]
    const child = node.children.get(char)
    if (!child) return false

    const shouldDelete = this.deleteHelper(child, word, index + 1)

    if (shouldDelete) {
      node.children.delete(char)
      return node.children.size === 0 && !node.isEnd
    }

    return false
  }

  get size(): number {
    let count = 0
    this.countWords(this.root, () => count++)
    return count
  }

  private countWords(node: TrieNode, increment: () => void): void {
    if (node.isEnd) increment()
    for (const child of node.children.values()) {
      this.countWords(child, increment)
    }
  }

  getAllWords(): string[] {
    const words: string[] = []
    this.collectWords(this.root, '', words, Infinity)
    return words
  }
}

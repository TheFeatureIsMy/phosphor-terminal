/**
 * Tree utilities
 */

class TreeNode<T> {
  value: T
  children: TreeNode<T>[]
  constructor(value: T, children: TreeNode<T>[] = []) {
    this.value = value
    this.children = children
  }
}

export class Tree<T> {
  private root: TreeNode<T> | null = null

  constructor(rootValue?: T) {
    if (rootValue !== undefined) {
      this.root = new TreeNode(rootValue)
    }
  }

  getRoot(): T | null {
    return this.root?.value ?? null
  }

  setRoot(value: T): void {
    this.root = new TreeNode(value)
  }

  addChild(parentValue: T, childValue: T): boolean {
    const parent = this.findNode(parentValue)
    if (!parent) return false
    parent.children.push(new TreeNode(childValue))
    return true
  }

  remove(value: T): boolean {
    if (!this.root) return false
    if (this.root.value === value) {
      this.root = null
      return true
    }
    return this.removeNode(this.root, value)
  }

  private removeNode(node: TreeNode<T>, value: T): boolean {
    for (let i = 0; i < node.children.length; i++) {
      if (node.children[i].value === value) {
        node.children.splice(i, 1)
        return true
      }
      if (this.removeNode(node.children[i], value)) {
        return true
      }
    }
    return false
  }

  find(value: T): boolean {
    return this.findNode(value) !== null
  }

  private findNode(value: T): TreeNode<T> | null {
    if (!this.root) return null
    return this.findNodeHelper(this.root, value)
  }

  private findNodeHelper(node: TreeNode<T>, value: T): TreeNode<T> | null {
    if (node.value === value) return node
    for (const child of node.children) {
      const found = this.findNodeHelper(child, value)
      if (found) return found
    }
    return null
  }

  getChildren(value: T): T[] {
    const node = this.findNode(value)
    return node?.children.map(c => c.value) ?? []
  }

  getParent(value: T): T | null {
    if (!this.root || this.root.value === value) return null
    return this.getParentHelper(this.root, value)
  }

  private getParentHelper(node: TreeNode<T>, value: T): T | null {
    for (const child of node.children) {
      if (child.value === value) return node.value
      const parent = this.getParentHelper(child, value)
      if (parent !== null) return parent
    }
    return null
  }

  getHeight(): number {
    if (!this.root) return 0
    return this.getHeightHelper(this.root)
  }

  private getHeightHelper(node: TreeNode<T>): number {
    if (node.children.length === 0) return 1
    return 1 + Math.max(...node.children.map(c => this.getHeightHelper(c)))
  }

  traverseBFS(): T[] {
    if (!this.root) return []
    const result: T[] = []
    const queue: TreeNode<T>[] = [this.root]

    while (queue.length > 0) {
      const node = queue.shift()!
      result.push(node.value)
      queue.push(...node.children)
    }

    return result
  }

  traverseDFS(): T[] {
    if (!this.root) return []
    const result: T[] = []
    this.traverseDFSHelper(this.root, result)
    return result
  }

  private traverseDFSHelper(node: TreeNode<T>, result: T[]): void {
    result.push(node.value)
    for (const child of node.children) {
      this.traverseDFSHelper(child, result)
    }
  }

  get size(): number {
    return this.traverseBFS().length
  }

  get isEmpty(): boolean {
    return this.root === null
  }
}

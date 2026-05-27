/**
 * Disjoint Set (Union-Find) utilities
 */

export class DisjointSet {
  private parent: number[]
  private rank: number[]

  constructor(size: number) {
    this.parent = Array.from({ length: size }, (_, i) => i)
    this.rank = new Array(size).fill(0)
  }

  find(x: number): number {
    if (this.parent[x] !== x) {
      this.parent[x] = this.find(this.parent[x])
    }
    return this.parent[x]
  }

  union(x: number, y: number): boolean {
    const rootX = this.find(x)
    const rootY = this.find(y)

    if (rootX === rootY) return false

    if (this.rank[rootX] < this.rank[rootY]) {
      this.parent[rootX] = rootY
    } else if (this.rank[rootX] > this.rank[rootY]) {
      this.parent[rootY] = rootX
    } else {
      this.parent[rootY] = rootX
      this.rank[rootX]++
    }

    return true
  }

  connected(x: number, y: number): boolean {
    return this.find(x) === this.find(y)
  }

  getComponents(): number[][] {
    const components = new Map<number, number[]>()
    for (let i = 0; i < this.parent.length; i++) {
      const root = this.find(i)
      if (!components.has(root)) {
        components.set(root, [])
      }
      components.get(root)!.push(i)
    }
    return Array.from(components.values())
  }

  getComponentCount(): number {
    const roots = new Set<number>()
    for (let i = 0; i < this.parent.length; i++) {
      roots.add(this.find(i))
    }
    return roots.size
  }
}

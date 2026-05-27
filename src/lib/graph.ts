/**
 * Graph utilities
 */

export class Graph<T> {
  private adjacencyList = new Map<T, Set<T>>()

  addVertex(vertex: T): void {
    if (!this.adjacencyList.has(vertex)) {
      this.adjacencyList.set(vertex, new Set())
    }
  }

  addEdge(from: T, to: T): void {
    this.addVertex(from)
    this.addVertex(to)
    this.adjacencyList.get(from)!.add(to)
  }

  removeVertex(vertex: T): void {
    this.adjacencyList.delete(vertex)
    for (const [, neighbors] of this.adjacencyList) {
      neighbors.delete(vertex)
    }
  }

  removeEdge(from: T, to: T): void {
    this.adjacencyList.get(from)?.delete(to)
  }

  hasVertex(vertex: T): boolean {
    return this.adjacencyList.has(vertex)
  }

  hasEdge(from: T, to: T): boolean {
    return this.adjacencyList.get(from)?.has(to) ?? false
  }

  getNeighbors(vertex: T): T[] {
    return Array.from(this.adjacencyList.get(vertex) ?? [])
  }

  getVertices(): T[] {
    return Array.from(this.adjacencyList.keys())
  }

  get size(): number {
    return this.adjacencyList.size
  }

  bfs(start: T): T[] {
    const visited = new Set<T>()
    const queue: T[] = [start]
    const result: T[] = []

    visited.add(start)

    while (queue.length > 0) {
      const vertex = queue.shift()!
      result.push(vertex)

      for (const neighbor of this.getNeighbors(vertex)) {
        if (!visited.has(neighbor)) {
          visited.add(neighbor)
          queue.push(neighbor)
        }
      }
    }

    return result
  }

  dfs(start: T): T[] {
    const visited = new Set<T>()
    const result: T[] = []

    const dfsHelper = (vertex: T) => {
      visited.add(vertex)
      result.push(vertex)

      for (const neighbor of this.getNeighbors(vertex)) {
        if (!visited.has(neighbor)) {
          dfsHelper(neighbor)
        }
      }
    }

    dfsHelper(start)
    return result
  }

  hasCycle(): boolean {
    const visited = new Set<T>()
    const recursionStack = new Set<T>()

    const hasCycleHelper = (vertex: T): boolean => {
      visited.add(vertex)
      recursionStack.add(vertex)

      for (const neighbor of this.getNeighbors(vertex)) {
        if (!visited.has(neighbor)) {
          if (hasCycleHelper(neighbor)) {
            return true
          }
        } else if (recursionStack.has(neighbor)) {
          return true
        }
      }

      recursionStack.delete(vertex)
      return false
    }

    for (const vertex of this.getVertices()) {
      if (!visited.has(vertex)) {
        if (hasCycleHelper(vertex)) {
          return true
        }
      }
    }

    return false
  }
}

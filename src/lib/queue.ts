/**
 * Queue utilities
 */

export class Queue<T> {
  private items: T[] = []

  enqueue(item: T): void {
    this.items.push(item)
  }

  dequeue(): T | undefined {
    return this.items.shift()
  }

  peek(): T | undefined {
    return this.items[0]
  }

  get size(): number {
    return this.items.length
  }

  get isEmpty(): boolean {
    return this.items.length === 0
  }

  clear(): void {
    this.items = []
  }

  toArray(): T[] {
    return [...this.items]
  }
}

export class PriorityQueue<T> {
  private items: { item: T; priority: number }[] = []

  enqueue(item: T, priority: number): void {
    const element = { item, priority }
    let added = false

    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].priority > priority) {
        this.items.splice(i, 0, element)
        added = true
        break
      }
    }

    if (!added) {
      this.items.push(element)
    }
  }

  dequeue(): T | undefined {
    return this.items.shift()?.item
  }

  peek(): T | undefined {
    return this.items[0]?.item
  }

  get size(): number {
    return this.items.length
  }

  get isEmpty(): boolean {
    return this.items.length === 0
  }

  clear(): void {
    this.items = []
  }
}

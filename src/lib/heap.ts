/**
 * Heap utilities
 */

export class MinHeap<T> {
  private items: T[] = []
  private compare: (a: T, b: T) => number

  constructor(compare: (a: T, b: T) => number) {
    this.compare = compare
  }

  insert(value: T): void {
    this.items.push(value)
    this.bubbleUp(this.items.length - 1)
  }

  extractMin(): T | undefined {
    if (this.items.length === 0) return undefined
    if (this.items.length === 1) return this.items.pop()

    const min = this.items[0]
    this.items[0] = this.items.pop()!
    this.bubbleDown(0)
    return min
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

  private bubbleUp(index: number): void {
    while (index > 0) {
      const parentIndex = Math.floor((index - 1) / 2)
      if (this.compare(this.items[index], this.items[parentIndex]) >= 0) break
      this.swap(index, parentIndex)
      index = parentIndex
    }
  }

  private bubbleDown(index: number): void {
    while (true) {
      let smallest = index
      const leftChild = 2 * index + 1
      const rightChild = 2 * index + 2

      if (
        leftChild < this.items.length &&
        this.compare(this.items[leftChild], this.items[smallest]) < 0
      ) {
        smallest = leftChild
      }

      if (
        rightChild < this.items.length &&
        this.compare(this.items[rightChild], this.items[smallest]) < 0
      ) {
        smallest = rightChild
      }

      if (smallest === index) break
      this.swap(index, smallest)
      index = smallest
    }
  }

  private swap(i: number, j: number): void {
    const temp = this.items[i]
    this.items[i] = this.items[j]
    this.items[j] = temp
  }
}

export class MaxHeap<T> {
  private items: T[] = []
  private compare: (a: T, b: T) => number

  constructor(compare: (a: T, b: T) => number) {
    this.compare = compare
  }

  insert(value: T): void {
    this.items.push(value)
    this.bubbleUp(this.items.length - 1)
  }

  extractMax(): T | undefined {
    if (this.items.length === 0) return undefined
    if (this.items.length === 1) return this.items.pop()

    const max = this.items[0]
    this.items[0] = this.items.pop()!
    this.bubbleDown(0)
    return max
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

  private bubbleUp(index: number): void {
    while (index > 0) {
      const parentIndex = Math.floor((index - 1) / 2)
      if (this.compare(this.items[index], this.items[parentIndex]) <= 0) break
      this.swap(index, parentIndex)
      index = parentIndex
    }
  }

  private bubbleDown(index: number): void {
    while (true) {
      let largest = index
      const leftChild = 2 * index + 1
      const rightChild = 2 * index + 2

      if (
        leftChild < this.items.length &&
        this.compare(this.items[leftChild], this.items[largest]) > 0
      ) {
        largest = leftChild
      }

      if (
        rightChild < this.items.length &&
        this.compare(this.items[rightChild], this.items[largest]) > 0
      ) {
        largest = rightChild
      }

      if (largest === index) break
      this.swap(index, largest)
      index = largest
    }
  }

  private swap(i: number, j: number): void {
    const temp = this.items[i]
    this.items[i] = this.items[j]
    this.items[j] = temp
  }
}

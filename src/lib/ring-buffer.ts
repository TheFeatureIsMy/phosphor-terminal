/**
 * Ring Buffer utilities
 */

export class RingBuffer<T> {
  private buffer: (T | undefined)[]
  private head = 0
  private tail = 0
  private size = 0
  private capacity: number

  constructor(capacity: number) {
    this.capacity = capacity
    this.buffer = new Array(capacity)
  }

  push(item: T): void {
    this.buffer[this.tail] = item
    this.tail = (this.tail + 1) % this.capacity

    if (this.size === this.capacity) {
      this.head = (this.head + 1) % this.capacity
    } else {
      this.size++
    }
  }

  pop(): T | undefined {
    if (this.size === 0) return undefined

    const item = this.buffer[this.head]
    this.buffer[this.head] = undefined
    this.head = (this.head + 1) % this.capacity
    this.size--
    return item
  }

  peek(): T | undefined {
    if (this.size === 0) return undefined
    return this.buffer[this.head]
  }

  get(index: number): T | undefined {
    if (index < 0 || index >= this.size) return undefined
    return this.buffer[(this.head + index) % this.capacity]
  }

  get length(): number {
    return this.size
  }

  get isFull(): boolean {
    return this.size === this.capacity
  }

  get isEmpty(): boolean {
    return this.size === 0
  }

  clear(): void {
    this.buffer = new Array(this.capacity)
    this.head = 0
    this.tail = 0
    this.size = 0
  }

  toArray(): T[] {
    const result: T[] = []
    for (let i = 0; i < this.size; i++) {
      const item = this.get(i)
      if (item !== undefined) {
        result.push(item)
      }
    }
    return result
  }
}

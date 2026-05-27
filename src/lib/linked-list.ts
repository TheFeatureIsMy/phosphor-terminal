/**
 * Linked List utilities
 */

class ListNode<T> {
  constructor(
    public value: T,
    public next: ListNode<T> | null = null
  ) {}
}

export class LinkedList<T> {
  private head: ListNode<T> | null = null
  private _size = 0

  append(value: T): void {
    const node = new ListNode(value)
    if (!this.head) {
      this.head = node
    } else {
      let current = this.head
      while (current.next) {
        current = current.next
      }
      current.next = node
    }
    this._size++
  }

  prepend(value: T): void {
    const node = new ListNode(value, this.head)
    this.head = node
    this._size++
  }

  insertAt(index: number, value: T): void {
    if (index < 0 || index > this._size) {
      throw new Error('Index out of bounds')
    }

    if (index === 0) {
      this.prepend(value)
      return
    }

    const node = new ListNode(value)
    let current = this.head!
    for (let i = 0; i < index - 1; i++) {
      current = current.next!
    }
    node.next = current.next
    current.next = node
    this._size++
  }

  removeAt(index: number): T | undefined {
    if (index < 0 || index >= this._size || !this.head) {
      return undefined
    }

    let value: T
    if (index === 0) {
      value = this.head.value
      this.head = this.head.next
    } else {
      let current = this.head
      for (let i = 0; i < index - 1; i++) {
        current = current.next!
      }
      value = current.next!.value
      current.next = current.next!.next
    }
    this._size--
    return value
  }

  get(index: number): T | undefined {
    if (index < 0 || index >= this._size || !this.head) {
      return undefined
    }

    let current = this.head
    for (let i = 0; i < index; i++) {
      current = current.next!
    }
    return current.value
  }

  find(value: T): number {
    let current = this.head
    let index = 0
    while (current) {
      if (current.value === value) {
        return index
      }
      current = current.next
      index++
    }
    return -1
  }

  contains(value: T): boolean {
    return this.find(value) !== -1
  }

  get size(): number {
    return this._size
  }

  get isEmpty(): boolean {
    return this._size === 0
  }

  toArray(): T[] {
    const result: T[] = []
    let current = this.head
    while (current) {
      result.push(current.value)
      current = current.next
    }
    return result
  }

  clear(): void {
    this.head = null
    this._size = 0
  }
}

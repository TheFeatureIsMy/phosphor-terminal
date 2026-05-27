/**
 * Skip List utilities
 */

class SkipListNode<T> {
  constructor(
    public value: T,
    public forward: (SkipListNode<T> | null)[] = []
  ) {}
}

export class SkipList<T> {
  private head: SkipListNode<T>
  private maxLevel: number
  private level = 0
  private size = 0
  private compare: (a: T, b: T) => number

  constructor(maxLevel: number, compare: (a: T, b: T) => number) {
    this.maxLevel = maxLevel
    this.compare = compare
    this.head = new SkipListNode<T>(null as unknown as T, new Array(maxLevel + 1).fill(null))
  }

  private randomLevel(): number {
    let level = 0
    while (Math.random() < 0.5 && level < this.maxLevel) {
      level++
    }
    return level
  }

  insert(value: T): void {
    const update: (SkipListNode<T> | null)[] = new Array(this.maxLevel + 1).fill(null)
    let current = this.head

    for (let i = this.level; i >= 0; i--) {
      while (current.forward[i] && this.compare(current.forward[i]!.value, value) < 0) {
        current = current.forward[i]!
      }
      update[i] = current
    }

    current = current.forward[0]!

    if (!current || this.compare(current.value, value) !== 0) {
      const newLevel = this.randomLevel()

      if (newLevel > this.level) {
        for (let i = this.level + 1; i <= newLevel; i++) {
          update[i] = this.head
        }
        this.level = newLevel
      }

      const newNode = new SkipListNode(value, new Array(newLevel + 1).fill(null))

      for (let i = 0; i <= newLevel; i++) {
        newNode.forward[i] = update[i]!.forward[i]
        update[i]!.forward[i] = newNode
      }

      this.size++
    }
  }

  search(value: T): boolean {
    let current = this.head

    for (let i = this.level; i >= 0; i--) {
      while (current.forward[i] && this.compare(current.forward[i]!.value, value) < 0) {
        current = current.forward[i]!
      }
    }

    current = current.forward[0]!
    return current !== null && this.compare(current.value, value) === 0
  }

  delete(value: T): boolean {
    const update: (SkipListNode<T> | null)[] = new Array(this.maxLevel + 1).fill(null)
    let current = this.head

    for (let i = this.level; i >= 0; i--) {
      while (current.forward[i] && this.compare(current.forward[i]!.value, value) < 0) {
        current = current.forward[i]!
      }
      update[i] = current
    }

    current = current.forward[0]!

    if (current && this.compare(current.value, value) === 0) {
      for (let i = 0; i <= this.level; i++) {
        if (update[i]!.forward[i] !== current) break
        update[i]!.forward[i] = current.forward[i]
      }

      while (this.level > 0 && !this.head.forward[this.level]) {
        this.level--
      }

      this.size--
      return true
    }

    return false
  }

  get length(): number {
    return this.size
  }

  toArray(): T[] {
    const result: T[] = []
    let current = this.head.forward[0]

    while (current) {
      result.push(current.value)
      current = current.forward[0]
    }

    return result
  }
}

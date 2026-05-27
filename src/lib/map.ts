/**
 * Map utilities
 */

export class Dictionary<T> {
  private items = new Map<string, T>()

  set(key: string, value: T): void {
    this.items.set(key, value)
  }

  get(key: string): T | undefined {
    return this.items.get(key)
  }

  has(key: string): boolean {
    return this.items.has(key)
  }

  delete(key: string): boolean {
    return this.items.delete(key)
  }

  clear(): void {
    this.items.clear()
  }

  get size(): number {
    return this.items.size
  }

  keys(): string[] {
    return Array.from(this.items.keys())
  }

  values(): T[] {
    return Array.from(this.items.values())
  }

  entries(): [string, T][] {
    return Array.from(this.items.entries())
  }

  forEach(callback: (value: T, key: string) => void): void {
    this.items.forEach(callback)
  }

  map<U>(callback: (value: T, key: string) => U): Dictionary<U> {
    const result = new Dictionary<U>()
    this.items.forEach((value, key) => {
      result.set(key, callback(value, key))
    })
    return result
  }

  filter(predicate: (value: T, key: string) => boolean): Dictionary<T> {
    const result = new Dictionary<T>()
    this.items.forEach((value, key) => {
      if (predicate(value, key)) {
        result.set(key, value)
      }
    })
    return result
  }

  toObject(): Record<string, T> {
    const result: Record<string, T> = {}
    this.items.forEach((value, key) => {
      result[key] = value
    })
    return result
  }

  static fromObject<T>(obj: Record<string, T>): Dictionary<T> {
    const dict = new Dictionary<T>()
    Object.entries(obj).forEach(([key, value]) => {
      dict.set(key, value)
    })
    return dict
  }
}

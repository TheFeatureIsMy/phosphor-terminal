/**
 * Bloom Filter utilities
 */

export class BloomFilter {
  private bits: boolean[]
  private size: number
  private hashCount: number

  constructor(size: number, hashCount: number) {
    this.size = size
    this.hashCount = hashCount
    this.bits = new Array(size).fill(false)
  }

  add(item: string): void {
    for (let i = 0; i < this.hashCount; i++) {
      const index = this.hash(item, i) % this.size
      this.bits[index] = true
    }
  }

  contains(item: string): boolean {
    for (let i = 0; i < this.hashCount; i++) {
      const index = this.hash(item, i) % this.size
      if (!this.bits[index]) {
        return false
      }
    }
    return true
  }

  private hash(item: string, seed: number): number {
    let hash = 0
    for (let i = 0; i < item.length; i++) {
      const char = item.charCodeAt(i)
      hash = ((hash << 5) - hash + char + seed) | 0
    }
    return Math.abs(hash)
  }

  clear(): void {
    this.bits.fill(false)
  }

  getFalsePositiveRate(): number {
    const setBits = this.bits.filter(b => b).length
    return Math.pow(setBits / this.size, this.hashCount)
  }
}

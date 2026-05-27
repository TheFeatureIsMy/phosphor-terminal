/**
 * Segment Tree utilities
 */

export class SegmentTree {
  private tree: number[]
  private n: number
  private combine: (a: number, b: number) => number

  constructor(arr: number[], combine: (a: number, b: number) => number) {
    this.n = arr.length
    this.combine = combine
    this.tree = new Array(4 * this.n).fill(0)
    this.build(arr, 1, 0, this.n - 1)
  }

  private build(arr: number[], node: number, start: number, end: number): void {
    if (start === end) {
      this.tree[node] = arr[start]
    } else {
      const mid = Math.floor((start + end) / 2)
      this.build(arr, 2 * node, start, mid)
      this.build(arr, 2 * node + 1, mid + 1, end)
      this.tree[node] = this.combine(this.tree[2 * node], this.tree[2 * node + 1])
    }
  }

  update(index: number, value: number): void {
    this.updateHelper(1, 0, this.n - 1, index, value)
  }

  private updateHelper(node: number, start: number, end: number, index: number, value: number): void {
    if (start === end) {
      this.tree[node] = value
    } else {
      const mid = Math.floor((start + end) / 2)
      if (index <= mid) {
        this.updateHelper(2 * node, start, mid, index, value)
      } else {
        this.updateHelper(2 * node + 1, mid + 1, end, index, value)
      }
      this.tree[node] = this.combine(this.tree[2 * node], this.tree[2 * node + 1])
    }
  }

  query(left: number, right: number): number {
    return this.queryHelper(1, 0, this.n - 1, left, right)
  }

  private queryHelper(node: number, start: number, end: number, left: number, right: number): number {
    if (right < start || end < left) {
      return 0
    }
    if (left <= start && end <= right) {
      return this.tree[node]
    }
    const mid = Math.floor((start + end) / 2)
    const leftResult = this.queryHelper(2 * node, start, mid, left, right)
    const rightResult = this.queryHelper(2 * node + 1, mid + 1, end, left, right)
    return this.combine(leftResult, rightResult)
  }
}

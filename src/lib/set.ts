/**
 * Set utilities
 */

export function union<T>(...sets: Set<T>[]): Set<T> {
  const result = new Set<T>()
  for (const set of sets) {
    for (const item of set) {
      result.add(item)
    }
  }
  return result
}

export function intersection<T>(...sets: Set<T>[]): Set<T> {
  if (sets.length === 0) return new Set()
  if (sets.length === 1) return new Set(sets[0])

  const result = new Set(sets[0])
  for (const set of sets.slice(1)) {
    for (const item of result) {
      if (!set.has(item)) {
        result.delete(item)
      }
    }
  }
  return result
}

export function difference<T>(setA: Set<T>, setB: Set<T>): Set<T> {
  const result = new Set(setA)
  for (const item of setB) {
    result.delete(item)
  }
  return result
}

export function symmetricDifference<T>(setA: Set<T>, setB: Set<T>): Set<T> {
  const result = new Set<T>()
  for (const item of setA) {
    if (!setB.has(item)) {
      result.add(item)
    }
  }
  for (const item of setB) {
    if (!setA.has(item)) {
      result.add(item)
    }
  }
  return result
}

export function isSubset<T>(setA: Set<T>, setB: Set<T>): boolean {
  for (const item of setA) {
    if (!setB.has(item)) {
      return false
    }
  }
  return true
}

export function isSuperset<T>(setA: Set<T>, setB: Set<T>): boolean {
  return isSubset(setB, setA)
}

export function toArray<T>(set: Set<T>): T[] {
  return Array.from(set)
}

export function fromArray<T>(array: T[]): Set<T> {
  return new Set(array)
}

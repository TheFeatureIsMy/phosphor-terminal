/**
 * Storage utility with error handling and serialization
 */

type StorageType = 'local' | 'session'

class StorageManager {
  private storage: Storage

  constructor(type: StorageType = 'local') {
    this.storage = type === 'local' ? localStorage : sessionStorage
  }

  get<T>(key: string, defaultValue: T): T {
    try {
      const item = this.storage.getItem(key)
      return item ? JSON.parse(item) : defaultValue
    } catch {
      return defaultValue
    }
  }

  set<T>(key: string, value: T): void {
    try {
      this.storage.setItem(key, JSON.stringify(value))
    } catch (error) {
      console.warn(`Failed to save to storage: ${key}`, error)
    }
  }

  remove(key: string): void {
    try {
      this.storage.removeItem(key)
    } catch (error) {
      console.warn(`Failed to remove from storage: ${key}`, error)
    }
  }

  clear(): void {
    try {
      this.storage.clear()
    } catch (error) {
      console.warn('Failed to clear storage', error)
    }
  }
}

export const localStorage = new StorageManager('local')
export const sessionStorage = new StorageManager('session')

/**
 * Create a Zustand persist storage adapter
 */
export function createPersistStorage(type: StorageType = 'local') {
  const manager = type === 'local' ? localStorage : sessionStorage

  return {
    getItem: (name: string) => {
      const value = manager.get(name, null)
      return value ? JSON.stringify(value) : null
    },
    setItem: (name: string, value: string) => {
      manager.set(name, JSON.parse(value))
    },
    removeItem: (name: string) => {
      manager.remove(name)
    },
  }
}

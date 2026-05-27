/**
 * Event utilities
 */

type EventHandler<T = unknown> = (data: T) => void

class EventEmitter<T extends Record<string, unknown> = Record<string, unknown>> {
  private handlers = new Map<keyof T, Set<EventHandler<unknown>>>()

  on<K extends keyof T>(event: K, handler: EventHandler<T[K]>): () => void {
    if (!this.handlers.has(event)) {
      this.handlers.set(event, new Set())
    }
    this.handlers.get(event)!.add(handler as EventHandler<unknown>)

    return () => {
      this.handlers.get(event)?.delete(handler as EventHandler<unknown>)
    }
  }

  emit<K extends keyof T>(event: K, data: T[K]): void {
    this.handlers.get(event)?.forEach(handler => {
      try {
        (handler as EventHandler<T[K]>)(data)
      } catch (error) {
        console.error(`Error in event handler for ${String(event)}:`, error)
      }
    })
  }

  off<K extends keyof T>(event: K, handler: EventHandler<T[K]>): void {
    this.handlers.get(event)?.delete(handler as EventHandler<unknown>)
  }

  clear(): void {
    this.handlers.clear()
  }
}

export function createEventEmitter<T extends Record<string, unknown>>(): EventEmitter<T> {
  return new EventEmitter<T>()
}

export function dispatchCustomEvent(name: string, detail?: unknown): void {
  window.dispatchEvent(new CustomEvent(name, { detail }))
}

export function listenCustomEvent(name: string, handler: (detail: unknown) => void): () => void {
  const listener = (e: Event) => {
    handler((e as CustomEvent).detail)
  }
  window.addEventListener(name, listener)
  return () => window.removeEventListener(name, listener)
}

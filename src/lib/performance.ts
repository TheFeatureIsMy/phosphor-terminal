/**
 * Performance monitoring utility
 * Tracks key metrics for the application
 */

interface Metric {
  name: string
  value: number
  timestamp: number
}

class PerformanceMonitor {
  private metrics: Metric[] = []

  mark(name: string) {
    if (typeof performance !== 'undefined') {
      performance.mark(name)
    }
  }

  measure(name: string, startMark: string, endMark: string) {
    if (typeof performance !== 'undefined') {
      try {
        performance.measure(name, startMark, endMark)
        const entries = performance.getEntriesByName(name)
        if (entries.length > 0) {
          this.metrics.push({
            name,
            value: entries[entries.length - 1].duration,
            timestamp: Date.now(),
          })
        }
      } catch { /* marks may not exist */ }
    }
  }

  getMetrics() {
    return [...this.metrics]
  }

  clear() {
    this.metrics = []
    if (typeof performance !== 'undefined') {
      performance.clearMarks()
      performance.clearMeasures()
    }
  }
}

export const perf = new PerformanceMonitor()

/**
 * Track component render time
 */
export function trackRender(componentName: string) {
  const startMark = `${componentName}-render-start`
  const endMark = `${componentName}-render-end`

  perf.mark(startMark)

  return () => {
    perf.mark(endMark)
    perf.measure(`${componentName}-render`, startMark, endMark)
  }
}

/**
 * Track async operation time
 */
export async function trackAsync<T>(name: string, fn: () => Promise<T>): Promise<T> {
  const start = performance.now()
  try {
    return await fn()
  } finally {
    const duration = performance.now() - start
    perf.mark(`${name}-complete`)
    console.debug(`[Perf] ${name}: ${duration.toFixed(2)}ms`)
  }
}

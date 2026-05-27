/**
 * Testing utilities for development
 */

/**
 * Mock API delay for testing
 */
export function mockDelay(ms: number = 200): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms))
}

/**
 * Generate mock data for testing
 */
export function generateMockId(): string {
  return Math.random().toString(36).substring(2, 9)
}

/**
 * Create mock event for testing
 */
export function createMockEvent(type: string, data: Record<string, unknown> = {}): Event {
  return new CustomEvent(type, { detail: data })
}

/**
 * Wait for condition to be true
 */
export async function waitFor(
  condition: () => boolean,
  timeout: number = 5000,
  interval: number = 100,
): Promise<void> {
  const start = Date.now()
  while (!condition()) {
    if (Date.now() - start > timeout) {
      throw new Error('Timeout waiting for condition')
    }
    await new Promise(resolve => setTimeout(resolve, interval))
  }
}

/**
 * Format bytes for testing
 */
export function formatBytes(bytes: number): string {
  if (bytes === 0) return '0 Bytes'
  const k = 1024
  const sizes = ['Bytes', 'KB', 'MB', 'GB']
  const i = Math.floor(Math.log(bytes) / Math.log(k))
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
}

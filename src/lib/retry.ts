/**
 * Retry utilities
 */

interface RetryOptions {
  maxAttempts?: number
  delay?: number
  backoff?: 'fixed' | 'exponential'
  onRetry?: (error: Error, attempt: number) => void
}

export async function retry<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {}
): Promise<T> {
  const {
    maxAttempts = 3,
    delay = 1000,
    backoff = 'exponential',
    onRetry,
  } = options

  let lastError: Error | null = null

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn()
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error))

      if (attempt < maxAttempts) {
        const waitTime = backoff === 'exponential'
          ? delay * Math.pow(2, attempt - 1)
          : delay

        onRetry?.(lastError, attempt)

        await new Promise(resolve => setTimeout(resolve, waitTime))
      }
    }
  }

  throw lastError
}

export function createRetryable<T>(
  fn: () => Promise<T>,
  options: RetryOptions = {}
): () => Promise<T> {
  return () => retry(fn, options)
}

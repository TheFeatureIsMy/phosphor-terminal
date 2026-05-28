/**
 * Global error handling utilities
 */

export class AppError extends Error {
  code: string
  statusCode?: number
  constructor(message: string, code: string, statusCode?: number) {
    super(message)
    this.code = code
    this.statusCode = statusCode
    this.name = 'AppError'
  }
}

export function handleApiError(error: unknown): AppError {
  if (error instanceof AppError) {
    return error
  }

  if (error instanceof Error) {
    // Network errors
    if (error.message.includes('fetch')) {
      return new AppError('网络连接失败，请检查网络', 'NETWORK_ERROR')
    }

    // Timeout errors
    if (error.message.includes('timeout') || error.message.includes('abort')) {
      return new AppError('请求超时，请稍后重试', 'TIMEOUT_ERROR')
    }

    return new AppError(error.message, 'UNKNOWN_ERROR')
  }

  return new AppError('发生未知错误', 'UNKNOWN_ERROR')
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof AppError) {
    return error.message
  }

  if (error instanceof Error) {
    return error.message
  }

  return '发生未知错误'
}

export function isNetworkError(error: unknown): boolean {
  if (error instanceof AppError) {
    return error.code === 'NETWORK_ERROR'
  }

  if (error instanceof Error) {
    return error.message.includes('fetch') || error.message.includes('network')
  }

  return false
}

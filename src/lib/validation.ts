/**
 * Validation utilities
 */

export function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
}

export function isValidUsername(username: string): boolean {
  return /^[a-zA-Z0-9_]{3,50}$/.test(username)
}

export function isValidPassword(password: string): boolean {
  return password.length >= 6 && password.length <= 128
}

export function isValidUrl(url: string): boolean {
  try {
    new URL(url)
    return true
  } catch {
    return false
  }
}

export function isValidNumber(value: unknown): value is number {
  return typeof value === 'number' && !isNaN(value) && isFinite(value)
}

export function isPositiveNumber(value: unknown): value is number {
  return isValidNumber(value) && value > 0
}

export function isValidDate(date: string): boolean {
  return !isNaN(Date.parse(date))
}

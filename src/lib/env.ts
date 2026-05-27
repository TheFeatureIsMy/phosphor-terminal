/**
 * Environment utilities
 */

export function isDevelopment(): boolean {
  return import.meta.env.DEV
}

export function isProduction(): boolean {
  return import.meta.env.PROD
}

export function getEnvVar(key: string, defaultValue: string = ''): string {
  return import.meta.env[key] || defaultValue
}

export function getApiBaseUrl(): string {
  return getEnvVar('VITE_API_BASE_URL', 'http://localhost:8000')
}

export function isMockMode(): boolean {
  return getEnvVar('VITE_USE_MOCK', 'true') !== 'false'
}

export function getAppVersion(): string {
  return getEnvVar('VITE_APP_VERSION', '0.0.0')
}

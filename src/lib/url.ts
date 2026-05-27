/**
 * URL utilities
 */

export function getBaseUrl(): string {
  return import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000'
}

export function buildUrl(path: string, params?: Record<string, string>): string {
  const base = getBaseUrl()
  const url = new URL(path, base)

  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      url.searchParams.append(key, value)
    })
  }

  return url.toString()
}

export function getQueryParam(name: string): string | null {
  const params = new URLSearchParams(window.location.search)
  return params.get(name)
}

export function setQueryParam(name: string, value: string): void {
  const params = new URLSearchParams(window.location.search)
  params.set(name, value)
  window.history.replaceState({}, '', `${window.location.pathname}?${params.toString()}`)
}

export function removeQueryParam(name: string): void {
  const params = new URLSearchParams(window.location.search)
  params.delete(name)
  window.history.replaceState({}, '', `${window.location.pathname}?${params.toString()}`)
}

export function isExternalUrl(url: string): boolean {
  try {
    const parsed = new URL(url)
    return parsed.origin !== window.location.origin
  } catch {
    return false
  }
}

export function getPathname(): string {
  return window.location.pathname
}

export function getHash(): string {
  return window.location.hash
}

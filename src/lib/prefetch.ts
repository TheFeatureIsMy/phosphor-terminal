/**
 * Route prefetching utility
 * Prefetches page chunks when user is likely to navigate there
 */

const prefetchMap: Record<string, () => Promise<unknown>> = {
  '/dashboard': () => import('@/pages/DashboardPage'),
  '/strategies': () => import('@/pages/StrategiesPage'),
  '/backtest': () => import('@/pages/BacktestPage'),
  '/trades': () => import('@/pages/TradesPage'),
  '/settings': () => import('@/pages/SettingsPage'),
  '/lab': () => import('@/pages/StrategyLabPage'),
}

export function prefetchRoute(path: string) {
  const loader = prefetchMap[path]
  if (loader) {
    loader().catch(() => { /* prefetch failed, will load on navigate */ })
  }
}

export function prefetchOnHover(element: HTMLElement, path: string) {
  let prefetched = false
  const handler = () => {
    if (!prefetched) {
      prefetched = true
      prefetchRoute(path)
    }
  }
  element.addEventListener('mouseenter', handler, { once: true })
  element.addEventListener('focus', handler, { once: true })
  return () => {
    element.removeEventListener('mouseenter', handler)
    element.removeEventListener('focus', handler)
  }
}

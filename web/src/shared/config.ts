/**
 * Runtime configuration.
 *
 * Resolution order:
 * 1. window.__ALPHALOOP_CONFIG__ (injected by Tauri/desktop or a mounted
 *    runtime-config.js on the server)
 * 2. VITE_API_BASE at build time
 * 3. same origin (dev goes through the Vite proxy; production goes through
 *    the reverse proxy)
 *
 * Never fall back to localhost in production: a remote deployment must not
 * silently point at the user's machine.
 */
export interface AlphaLoopRuntimeConfig {
  apiBase?: string;
  wsBase?: string;
}

declare global {
  interface Window {
    __ALPHALOOP_CONFIG__?: AlphaLoopRuntimeConfig;
  }
}

function stripTrailingSlash(value: string): string {
  return value.endsWith("/") ? value.slice(0, -1) : value;
}

function resolveApiBase(): string {
  const runtime =
    typeof window !== "undefined" ? window.__ALPHALOOP_CONFIG__?.apiBase : undefined;
  const buildTime = import.meta.env.VITE_API_BASE as string | undefined;
  if (runtime) return stripTrailingSlash(runtime);
  if (buildTime) return stripTrailingSlash(buildTime);
  if (typeof window !== "undefined" && window.location.origin.startsWith("http")) {
    return stripTrailingSlash(window.location.origin);
  }
  return "";
}

export const API_BASE: string = resolveApiBase();

export function resolveWsBase(): string {
  const configured =
    typeof window !== "undefined" ? window.__ALPHALOOP_CONFIG__?.wsBase : undefined;
  if (configured) return stripTrailingSlash(configured);
  if (API_BASE) return API_BASE.replace(/^http/, "ws");
  if (typeof window !== "undefined") {
    const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
    return `${protocol}//${window.location.host}`;
  }
  return "";
}

export function apiUrl(path: string): string {
  const suffix = path.startsWith("/") ? path : `/${path}`;
  return `${API_BASE}${suffix}`;
}

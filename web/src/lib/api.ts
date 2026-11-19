// AlphaLoop BFF fetch client — dev 经 vite proxy 转发;生产(Tauri)直连 8000

import { apiUrl } from "@/shared/config";

const TOKEN_KEY = "alphaloop_token";

export class ApiError extends Error {
  constructor(
    public status: number,
    message: string
  ) {
    super(message);
    this.name = "ApiError";
  }
}

export function getAuthToken(): string | null {
  try {
    return window.localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

export function setAuthToken(token: string): void {
  window.localStorage.setItem(TOKEN_KEY, token);
}

export function clearAuthToken(): void {
  window.localStorage.removeItem(TOKEN_KEY);
}

/** Login against the backend OAuth2 password flow. */
export async function login(username: string, password: string): Promise<void> {
  const res = await fetch(apiUrl("/auth/login"), {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ username, password }).toString(),
  });
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    let message = body || res.statusText;
    try {
      const parsed = JSON.parse(body) as { detail?: unknown };
      if (typeof parsed.detail === "string") message = parsed.detail;
    } catch {
      // keep the raw body
    }
    throw new ApiError(res.status, message);
  }
  const data = (await res.json()) as { access_token?: string };
  if (!data.access_token) throw new ApiError(500, "login response missing access_token");
  setAuthToken(data.access_token);
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const token = getAuthToken();
  let res: Response;
  try {
    res = await fetch(apiUrl(path), {
      ...init,
      headers: {
        "Content-Type": "application/json",
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
        ...init?.headers,
      },
    });
  } catch {
    throw new ApiError(0, "backend unreachable");
  }
  if (res.status === 401) {
    clearAuthToken();
    window.dispatchEvent(new Event("alphaloop:unauthorized"));
  }
  if (!res.ok) {
    const body = await res.text().catch(() => "");
    throw new ApiError(res.status, body || res.statusText);
  }
  if (res.status === 204) {
    return undefined as T;
  }
  return res.json() as Promise<T>;
}

export const api = {
  get: <T>(path: string) => request<T>(path),
  post: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "POST", body: body ? JSON.stringify(body) : undefined }),
  put: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "PUT", body: body ? JSON.stringify(body) : undefined }),
  patch: <T>(path: string, body?: unknown) =>
    request<T>(path, { method: "PATCH", body: body ? JSON.stringify(body) : undefined }),
  del: <T,>(path: string) => request<T>(path, { method: "DELETE" }),
};

// Dev-only E2E bootstrap: allow `?e2e_token=<jwt>` to seed the token once.
if (import.meta.env.DEV) {
  const params = new URLSearchParams(window.location.search);
  const token = params.get("e2e_token");
  if (token) {
    setAuthToken(token);
    sessionStorage.setItem("alphaloop-launched", "1");
    params.delete("e2e_token");
    const query = params.toString();
    window.history.replaceState({}, "", `${window.location.pathname}${query ? `?${query}` : ""}`);
  }
}

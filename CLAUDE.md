# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev        # Start Vite dev server on port 5173
npm run build      # Type-check (tsc -b) then Vite production build
npm run lint       # ESLint with flat config
npm run preview    # Serve production build locally
```

## Architecture

Crypto quantitative trading dashboard (React 19 SPA). All UI is Chinese-language (zh-CN). Dark theme by default.

### Data Flow (three layers)

1. **`src/api/client.ts`** — Dual-mode API client. Controlled by `VITE_USE_MOCK` env var. When `"true"` (default), calls a `mockFn` callback with simulated latency (200-500ms). When `"false"`, fetches from `VITE_API_BASE_URL` (default `http://localhost:8000`). Exports `apiGet`, `apiPost`, `apiPut`, `apiDelete`.

2. **`src/api/*.ts`** — Domain modules (`strategies.ts`, `orders.ts`, `dashboard.ts`). Each function passes endpoint + mock factory to the client. `strategies.ts` maintains a mutable in-memory array so mock CRUD persists for the session.

3. **`src/hooks/*.ts`** — TanStack Query v5 wrappers. Manage caching, polling intervals, and mutation invalidation. Strategy mutations invalidate `['strategies']` key.

### State Management

- **Zustand** (`src/stores/app-store.ts`) — Client-only UI state (sidebar collapse).
- **TanStack Query** — All server state. Polling intervals: `useSystemStatus` 10s, `usePositions` 15s, `useDashboardKPIs` 30s.

### Routing

React Router v7 with `AppShell` layout wrapper (`Sidebar` + `TopBar` + `<Outlet />`). Six routes: `/`, `/strategies`, `/strategies/:id/canvas`, `/backtest`, `/trades`, `/settings`.

### Key Libraries

- **Recharts** — Equity curves and PnL charts. Tooltip formatters must accept `ValueType | undefined`, not `number`.
- **@xyflow/react** — Strategy canvas with 4 custom node types: `dataSource`, `indicator`, `logicGate`, `executor`.
- **Tailwind CSS v4** — Uses `@import "tailwindcss"` + `@theme` block in `index.css`. No `tailwind.config.js`.
- **lucide-react** — All icons.

### Styling Conventions

Dark trading dashboard theme defined in `src/index.css` `@theme` block. Semantic color tokens: `profit` (green), `loss` (red), `primary` (blue), `warning` (amber), `danger`, `info`, `background`, `surface`, `border`, `text-primary`, `text-secondary`, `text-muted`. Use `cn()` from `@/lib/utils` for conditional classes (clsx + tailwind-merge). Financial numbers use `.font-tabular` class for tabular-nums alignment.

### Path Alias

`@/*` maps to `./src/*` (configured in both `vite.config.ts` and `tsconfig.app.json`).

### Environment Variables

Set in `.env` (Vite auto-loads):
- `VITE_USE_MOCK` — `"true"` for mock data, `"false"` for real API
- `VITE_API_BASE_URL` — Backend API base URL (default `http://localhost:8000`)

## Conventions

- TypeScript strict: `noUnusedLocals`, `noUnusedParameters` enforced — remove unused imports.
- All domain types defined in `src/types/index.ts` — add new types there, not inline.
- New API endpoints: add mock data generator in `mock-data.ts`, domain function in the appropriate `api/*.ts`, and React Query hook in `hooks/*.ts`.
- Pages go in `src/pages/`, layout components in `src/components/layout/`.

## PRD Reference

The full product requirements are in `../CyberQuant OS 量化交易系统工程PRD v2.0.md`. Key differentiating features: RAG strategy lab (PDF→code), SHAP XAI attribution, microstructure audit (wash trading/spoofing detection), FinBERT sentiment, FreqAI incremental learning. Python backend (Freqtrade + CCXT) is planned but not yet built.

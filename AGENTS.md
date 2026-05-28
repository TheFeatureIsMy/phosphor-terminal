# AGENTS.md

Supersedes `CLAUDE.md` for OpenCode. PulseDesk — AI crypto quant dashboard (React 19, Vite 8, TS 6, Tailwind v4). Chinese UI, dark theme.

## Commands

```bash
npm run dev          # Vite on :5173 (host:true)
npm run build        # tsc -b → vite build (run both; vite build alone skips typecheck)
npm run type-check   # tsc --noEmit (fast typecheck without build)
npm run lint         # ESLint flat config
npm run lint:fix
npm run preview      # serve dist/
npm run clean        # rm -rf dist node_modules/.vite
```

Tauri (optional desktop shell, Rust backend in `src-tauri/`): `npm run tauri:dev` / `tauri:build`.

## TypeScript traps

- **`verbatimModuleSyntax`** — type-only imports MUST use `import type { X }`, not `import { X }`.
- **`erasableSyntaxOnly`** — no `enum`, no namespaces, no parameter properties. Use const arrays + `as const` instead of enums.
- **`noUnusedLocals` / `noUnusedParameters`** — unused imports/params break `tsc -b`. Remove them.
- Types go in `src/types/index.ts`, never inline.

## Architecture

### Data flow (3 layers)
1. `src/api/client.ts` — dual-mode (`apiGet/apiPost/apiPut/apiDelete`). `VITE_USE_MOCK=true` (default) calls mock factory; `false` hits `VITE_API_BASE_URL` (default `http://localhost:8000`) with 15s timeout.
2. `src/api/*.ts` — domain modules pass endpoint + mock factory to client. `strategies.ts` has mutable in-memory array for session-persistent mock CRUD.
3. `src/hooks/*.ts` — TanStack Query v5 wrappers. Strategy mutations invalidate `['strategies']`. Global QueryClient: `staleTime: 5000`, `retry: 1`, `refetchOnWindowFocus: false`.

### ⚠️ Auth API is special
`src/api/auth.ts` does NOT use the shared client. It manages its own `fetch()` calls, mock delay, and JWT token flow directly. Sets `Content-Type: application/x-www-form-urlencoded` for login (OAuth2 password grant).

### State management
- **Zustand** (`src/stores/`): 3 stores. `app-store.ts` (no persist), `auth-store.ts` (persisted to localStorage key `pulsedesk-auth`), `settings-store.ts` (persisted to `pulsedesk-settings`).
- **TanStack Query**: polling — `useSystemStatus` 10s, `usePositions` 15s, `useDashboardKPIs` 30s.

### Routes
**Public**: `/`, `/login`, `/register`, `/forgot-password`.
**Protected** (inside `ProtectedRoute` + `AppShell`): `/dashboard`, `/strategies`, `/strategies/:id`, `/backtest`, `/trades`, `/settings`, `/profile`, `/lab`.
All pages lazy-loaded via `lazy(() => import('@/pages/X').then(m => ({ default: m.X })))`.

### Canvas node types (@xyflow/react)
6 custom types with distinct colors: `dataSource` (blue), `indicator` (green), `logicGate` (amber), `executor` (emerald), `ai` (purple), `risk` (red).

### Recharts
Tooltip value props are `ValueType | undefined`, NOT `number`. Check with `if (value == null) return ''`.

## Styling

- **Tailwind v4**: no `tailwind.config.js`. Config via `@import "tailwindcss"` + `@theme` block in `src/index.css`.
- **`cn()`** from `@/lib/utils` (clsx + tailwind-merge) for conditional classes.
- **`.font-tabular`** for `font-variant-numeric: tabular-nums` on financial numbers.
- Semantic colors: `profit` (#8cffb8), `loss` (#ff6b6b), `primary`, `warning`, `danger`, `info`, `bg`, `bg-surface`, `border`, `text`, `text-secondary`, `text-muted`.
- Utility classes defined in `index.css`: `.card`, `.glass`, `.glass-strong`, `.terminal-panel`, `.btn-primary`, `.btn-ghost`, `.badge`, `.skeleton`.

## Conventions

- All domain types in `src/types/index.ts`. Const arrays with `as const` for enums (`EXCHANGES`, `TRADING_MODES`, `MARKETS`, `TIMEFRAMES`).
- `@/*` maps to `./src/*` (vite.config.ts + tsconfig.app.json).
- No frontend test framework installed.
- ESLint globally ignores: `src-tauri/target`, `src/components/ui/splash-cursor.tsx`.
- `.env` (gitignored) sets defaults: `VITE_USE_MOCK=true`, `VITE_API_BASE_URL=http://localhost:8000`.
- Docker Compose (`docker-compose.yml`) for backend + Freqtrade, but main dev is frontend-only `npm run dev`.

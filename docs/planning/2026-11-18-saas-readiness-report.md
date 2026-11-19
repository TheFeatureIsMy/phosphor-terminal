# SaaS Readiness Report (2026-11-18, round 100)

## Verdict

- **Web client:** functional, verified in a real browser (Playwright).
- **iOS client:** functional, verified in an iOS 27.2 simulator with UI tests.
- **Server:** 1577 tests pass on PostgreSQL, 1574 on SQLite; migrations and RLS
  verified on a disposable PostgreSQL cluster.
- **Multi-tenant data layer:** 47 tenant tables, 42 with RLS; all strategy/run
  related tables carry `tenant_id`.
- **Per-tenant execution:** profile, encrypted credentials, config rendering,
  health checks, provisioning API and scripts exist; the local full stack
  (Postgres/Redis/API/Nginx) has been started, but a per-tenant Freqtrade
  container and a real exchange backtest have not been verified yet.
- **Not production-ready for multi-tenant live trading.** Ready for a
  single-owner paper deployment and for staging the tenant runtime.

## Evidence

| Area | Evidence |
|---|---|
| Backend SQLite | 1559 passed / 6 skipped |
| Backend PostgreSQL | 1577 passed / 3 skipped (9m42s) |
| Tenant isolation | `scripts/verify-tenant-isolation.sh` → PASS |
| Schema audit | 44 tenant tables, 35 RLS, 9 allowlisted, 0 linked tables without tenant |
| Web E2E | login, dashboard, settings, strategy, backtest submit/result, members, invites, sessions (`docs/assets/web-e2e-*.png`) |
| iOS UI | simulator login + 5 tabs + settings sections (`AlphaLoopIOSUITests`, 72s) |
| Migrations | `alembic upgrade head` on PostgreSQL; head `c6670360b3b2` |
| CI | SQLite, PostgreSQL, tenant-isolation, iOS UI test jobs defined; not yet run on GitHub |

## Remaining P0

1. **Per-tenant runtime**: start/stop a real Freqtrade container, verify health,
   execute a paper run, destroy it. Local Docker host is now available.
2. **Real exchange network**: run one real backtest and one paper session
   (Binance API is unreachable from this network).
3. **CI green**: push the workflow and confirm the PostgreSQL, tenant-isolation
   and iOS UI jobs.
4. **Execution data isolation review**: RLS covers orders/trades/positions, but
   the global Freqtrade endpoints remain platform-admin-only until runtime
   provisioning is real.

## Remaining P1

- Legacy tables now have tenant RLS (40/44), but rows with null `tenant_id`
  are still hidden from tenants until backfilled.
- Quotas/billing, plan enforcement, runtime image upgrades/rollback.
- Web invite/session E2E are scripted outside the repo; move them into CI.
- Android/Windows clients not started; macOS native paused.
- SMTP only tested against a fake server; no real delivery.

## Deployment recommendation

- Deploy **paper-only**, single tenant owner, shared Freqtrade runtime.
- Keep `TENANT_RUNTIME_PROVISIONING_ENABLED=false` until a staging container
  has been provisioned and health-checked.
- Do not enable multi-tenant live trading before items 1–3 above are closed.

## Next 30 days

1. Provision one tenant runtime on a Docker host; verify health, paper run, stop.
2. Push CI and fix any runner-specific failures.
3. Add web E2E scripts to the repo and a CI job.
4. Decide Android/Windows (build vs defer).
5. Add quotas/billing before onboarding a second tenant.

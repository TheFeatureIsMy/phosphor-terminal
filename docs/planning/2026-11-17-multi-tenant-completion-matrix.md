# Multi-Tenant Completion Matrix (2026-11-17)

Evidence: `1514 passed / 5 skipped` on SQLite; PostgreSQL migrations to
`ccb10ee514e9`; tenant-isolation script passes with `alphaloop_app` /
`alphaloop_worker`.

## 1. Database

Audit: `scripts/audit-tenant-schema.py` against PostgreSQL:

- 45 tables with `tenant_id`
- 41 with RLS enabled and one policy each
- 4 allowlisted without RLS:
  - `memberships` — login/refresh must read the user's membership before a
    tenant GUC exists
  - `command_bus_commands` — platform-operational queue; tenant column exists,
    RLS is intentionally not enabled yet
  - `device_sessions` — auth middleware must check `sid` before a tenant GUC
  - `tenant_invites` — accepted by token without a tenant GUC

Tenant-scoped tables with RLS:

```
strategies_v2, strategy_versions, strategy_runs, backtest_runs,
provider_configs, knowledge_documents, knowledge_chunks,
capital_pools, risk_policies, risk_policy_versions,
generated_strategy_artifacts, execution_ledger_events,
execution_orders, execution_trades, execution_positions,
freqtrade_runs, order_fills, canvas_drafts,
strategy_risk_policy_bindings, strategy_activity_log
```

### Tenantless strategy/run-linked tables (19)

```
(none — all strategy/run-linked tables now have tenant_id; 7 tables are
allowlisted pending legacy-id migration)
```

Risk classification:

| Severity | Tables | Why |
|---|---|---|
| — | ~~trade_intents, risk_decisions, portfolio_snapshots, circuit_breaker_events, reconciliation_events, order_attributions~~ | Covered by migration `6ef0661da299` |
| P1 | `feature_snapshots`, `risk_events` | Still need tenant/RLS; no strategy UUID link for risk_events |
| P1 | `strategy_rule_dsl_versions`, `strategy_version_upgrade_requests`, `canvas_workflows`, `ai_research_links` | Strategy IP / research links |
| P1 | `dryrun_runs`, `freqai_runs`, `growth_reports`, `attribution_reports` | Per-run/per-strategy results |
| P2 | `mtf_guard_events`, `mtf_guard_backtest_stats`, `failure_clusters` | Analytics; often keyed by symbol, less direct leak |

## 2. API surfaces

| Area | Tenant-aware | RLS | Notes |
|---|---|---|---|
| Auth / tenant | ✅ | n/a | register/login/refresh/`/auth/tenant`; first user is superuser |
| Strategies / versions | ✅ | ✅ | list/detail/versions scoped by `tid` |
| Backtests | ✅ | ✅ | start writes tenant into command + run |
| Strategy runs | ✅ | ✅ | run, orders, ledger, pause/resume/stop scoped |
| Ledger | ✅ | ✅ | auto-fill from run; no-run system events are worker-only |
| Providers | ✅ | ✅ | admin API per tenant; per-tenant derived keys |
| Knowledge / RAG | ✅ | ✅ | docs/chunks/artifacts scoped |
| Capital / risk | ✅ | ✅ | policies, versions, bindings, activity |
| Canvas | ✅ | ✅ | draft auto-fill; publish scoped |
| Execution (Freqtrade) | ✅ routing | ❌ | tenant profile with dedicated URL; no profile => 403; superuser uses shared runtime; container provisioning still external |
| Command queue | ✅ | ❌ | tenant view + platform scope; table not RLS |

## 3. Workers / runtime

- Command Bus commands carry `tenant_id`; `acquire_next` prefers the tenant with
  the fewest running commands.
- Provider health tick has an optional per-tenant limit.
- Worker DB role (`alphaloop_worker`) is BYPASSRLS.
- Ledger / order / trade / position / freqtrade-run rows auto-fill tenant from
  their parent; strategy executions are isolated by app-layer filters.
- Tenant execution routes through `tenant_execution_profiles`: an enabled
  `dedicated` profile with `freqtrade_url` unlocks `/api/execution/*`; otherwise
  403. Superusers keep the shared runtime.
- Credentials (API + exchange) are encrypted per tenant, rendered into a 0600
  config, and a provisioning API/scripts can start/stop a container
  (`TENANT_RUNTIME_PROVISIONING_ENABLED=false` by default).
- Health checks are manual and can be scheduled (`TENANT_RUNTIME_HEALTH_INTERVAL_S`).
- Tenant membership: invite links, roles, last-owner protection, device sessions
  with revoke/expiry/cleanup.
- Plans: `free` / `pro` / `enterprise` with member and strategy limits;
  superusers can change a tenant's plan via `/api/admin/tenant-plan`.
- **Not done**: automated provisioning of the per-tenant runtime. Contract and
  rollout are specified in
  [`docs/architecture/20_tenant_runtime_provisioning.md`](../architecture/20_tenant_runtime_provisioning.md).

## 4. Clients

| Client | Status |
|---|---|
| Web | **Playwright E2E passed**: login, dashboard, settings, strategy + backtest, member add/remove/role, invite accept/login, session revoke; screenshots in `docs/assets/web-e2e-*.png` |
| iOS | **UI test passed (72s)**: auto-login against a real backend; dashboard, strategies, execution, risk, settings (tenant/members/sessions/execution runtime) asserted |
| Android / Windows | not started (deferred) |
| macOS native | paused |

Neither client has: tenant switcher, invitations, role management, billing, or
device/session management.

### PostgreSQL test status (2026-11-18)

- Tenant/API subset: 97 passed.
- **Full suite: 1539 passed / 3 skipped / 0 failed** (10m29s).
- Test harness sets `session_replication_role=replica` to match SQLite's
  non-enforcing FK behaviour; production data integrity is covered by real
  API/integration flows and migrations.
- Three real PostgreSQL datetime bugs were found and fixed (stale command
  recovery, strategy promotion, trade-sync heartbeat).

## 5. Security / deployment

- RLS uses `set_config('app.tenant_id', ..., true)` per transaction; API sessions
  set it from `request.state.tenant_id`.
- `scripts/preflight.sh`: secrets, DB role, role attributes, RLS for two core
  tables, Alembic head.
- `scripts/verify-tenant-isolation.sh`: temp PG + migrations + roles + dual-tenant
  API/RLS assertions.
- `scripts/audit-tenant-schema.py`: tenant/RLS coverage audit.
- CI has a `tenant-isolation` job, but it has not run on GitHub yet.
- compose still defaults to the owner URL; app/worker role switch is documented
  in `docs/operations/multi-tenant-upgrade.md` and remains opt-in.

## 6. Definition of done for SaaS

1. Per-tenant execution runtime with paper-only default and live gated per plan.
2. All P0/P1 tenantless tables migrated, backfilled, RLS enabled, and covered by
   the two-tenant regression.
3. API integration tests run against PostgreSQL for the tenant-critical paths.
4. CI green including `tenant-isolation`; compose upgrade drilled once.
5. Tenant lifecycle: invite, role change, remove member, device sessions.
6. Quotas/billing and audit export.
7. Android/Windows clients or an explicit decision to defer them.

## 7. Next recommended order

1. **P0 execution/risk tables** tenant columns + RLS (mechanical, high value).
2. Per-tenant execution runtime design spike (container/job + routing).
3. PG integration tests for tenant-critical APIs.
4. Compose upgrade drill + CI verification.

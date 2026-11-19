# Tenant RLS Design (2026-11-16)

Status: design only. Application-layer tenant filters exist for strategies,
versions, backtests, strategy runs, ledger, providers, knowledge, capital pools
and risk policies. PostgreSQL RLS is the defense-in-depth layer; it is **not
enabled yet**.

## 1. Goals

- A bug that forgets a `tenant_id` filter must not leak another tenant's rows.
- Tenant context must be explicit per DB transaction, never process-global.
- Workers and migrations need a controlled bypass, not a silent one.

## 2. Roles

| Role | Attributes | Used by |
|---|---|---|
| `alphaloop_migrator` | owner, `BYPASSRLS` | Alembic only |
| `alphaloop_app` | `NOBYPASSRLS`, no table ownership | API |
| `alphaloop_worker` | `BYPASSRLS` | command worker / reconciliation / provider scheduler |

`docker-compose.yml` should create these roles and set
`DATABASE_URL` for the API to `alphaloop_app`. The current deployment uses
`postgres`, which bypasses RLS and would make policies a no-op.

## 3. Tenant GUC

Per transaction:

```sql
SET LOCAL app.tenant_id = '42';
```

Reset is automatic at transaction end. The API obtains the id from JWT `tid`
(AuthMiddleware) and sets it in the SQLAlchemy `after_begin` event before the
first statement. Requests without `tid` (public endpoints, legacy tokens) do not
set it and therefore see only rows where `tenant_id IS NULL` once policies are
enforced.

## 4. Policy shape

```sql
ALTER TABLE strategies_v2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE strategies_v2 FORCE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation ON strategies_v2
  USING (
    tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
  )
  WITH CHECK (
    tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
  );
```

Apply to:

- `strategies_v2`, `strategy_versions`, `backtest_runs`
- `provider_configs`, `knowledge_documents`, `knowledge_chunks`,
  `generated_strategy_artifacts`
- `capital_pools`, `risk_policies`

Tables without direct `tenant_id` (`strategy_runs`, ledger, orders, positions)
derive ownership through joins, so RLS alone cannot filter them without a
denormalized `tenant_id`. Add `tenant_id` to those tables first, or enforce via
security-barrier views.

## 5. Rollout

1. Create roles and a non-superuser `DATABASE_URL` for the API.
2. Add `app.tenant_id` setting in `get_db`/`SessionLocal` `after_begin`.
3. Enable RLS on one table (`strategies_v2`) in staging, run the two-tenant
   regression suite.
4. Enable the rest table by table, keeping a rollback migration per table.
5. Remove application-layer filters only after RLS has run in production for a
   full release.

## 6. Test plan

- Non-superuser connection with `app.tenant_id=1` cannot `SELECT`, `UPDATE` or
  `DELETE` tenant 2 rows.
- `INSERT` with the wrong `tenant_id` fails `WITH CHECK`.
- No GUC set: only `tenant_id IS NULL` rows are visible.
- Worker role bypasses RLS and can reconcile all tenants.
- `alembic upgrade head` works as migrator, not app role.

## 7. Known blockers

- Local verification is constrained: the full pytest suite on PostgreSQL grows
  the cluster past the current ~1GB free disk and crashed PostgreSQL during the
  attempt. RLS tests need a machine/CI runner with several GB free.
- `execution_orders` / positions / trades still lack `tenant_id`.

## 8. Implementation progress (2026-11-16)

- Roles: `deploy/postgres/init-tenant-roles.sh` (mounted by docker-compose).
- `strategies_v2` policy created by migration `a936cc9d0aeb`; RLS is enabled
  by migration `ac10e45b8067` (owners/superusers still bypass until the API
  connects as `alphaloop_app`).
- Verified manually on PostgreSQL: with `app.tenant_id=101`, a non-superuser
  role sees only tenant 101 and an INSERT for tenant 102 fails the `WITH CHECK`
  policy.
- Remaining before enabling: point the API at `alphaloop_app`, point workers at
  `alphaloop_worker`, then `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` per table.

## 9. End-to-end result (2026-11-17)

With the API connected as `alphaloop_app` and workers as `alphaloop_worker`:

- Register/login/create/list strategy as tenant A: 201/200/201/200.
- Tenant B list: 0 rows; reading A's strategy: 404.
- App role without `app.tenant_id`: 0 strategies visible.
- App role with `app.tenant_id = A`: 1 strategy visible.
- Worker role: 1 strategy visible (BYPASSRLS).

This validates the policy + GUC + role split together.

## 10. Extended coverage (2026-11-17)

Migration `fc32b319d45f` adds policies and enables RLS for:

- `strategy_versions`
- `provider_configs`
- `knowledge_documents`
- `knowledge_chunks`

With the API as `alphaloop_app` (tenant GUC set) and workers as
`alphaloop_worker`:

- create strategy + version + knowledge upload: 201/201/200
- list versions: 200 (1 row)
- app role without GUC: 0 versions / 0 documents
- worker role: 1 version / 1 document

Research draft confirmation and canvas publish now propagate `tenant_id` so
they keep working under RLS.

## 11. Capital / risk (2026-11-17)

Migration `edb94f38f472` adds policies and enables RLS for `capital_pools` and
`risk_policies`. E2E with `alphaloop_app`: tenant A sees only `pool-a`, tenant B
only `pool-b`; `alphaloop_worker` sees both. `risk_policy_versions` now carries `tenant_id` (migration `66b99c27f75e`) and
RLS is enabled, so direct lookups are also protected.

## 12. Generated artifacts (2026-11-17)

Migration `fdd9adf9d88a` enables RLS on `generated_strategy_artifacts`.
`/rag/generate` writes the tenant id; with `alphaloop_app` and no GUC the table
is empty, while `alphaloop_worker` sees the row.

## 13. Strategy runs (2026-11-17)

`strategy_runs.tenant_id` is now denormalized from the strategy version and RLS
is enabled (migration `0679c9bd58aa`). The live-small command payload carries the
tenant so the worker writes it. Verified: app role without GUC sees 0 runs, with
the tenant GUC 1, worker sees 1.

## 14. Ledger (2026-11-17)

`execution_ledger_events.tenant_id` is filled by an ORM `before_insert` hook that
looks up `strategy_run -> strategy_version.tenant_id`. Existing rows are
backfilled from their run. RLS is enabled; events without a run keep a NULL
tenant and are invisible to tenant-scoped API sessions (system events remain
worker-only for now).

Verified on PostgreSQL: insert under `app.tenant_id=301` auto-filled 301, app
role with no GUC saw 0 rows, worker saw both events.

## 15. Execution data (2026-11-17)

`execution_orders`, `execution_trades` and `execution_positions` now carry
`tenant_id`, auto-filled from `strategy_run` on insert (same pattern as the
ledger). RLS is enabled on all three. Verified: insert under tenant 301 got
301 on all rows; app role without GUC saw 0; worker saw 1 per table.

`freqtrade_runs` and `order_fills` are not independently protected; they are
reached through a run/order that is.

## 16. Freqtrade runs and fills (2026-11-17)

`freqtrade_runs.tenant_id` is derived from its strategy run, and
`order_fills.tenant_id` from its execution order, both via ORM hooks. RLS is
enabled (migration `24b2af3b76ba`). Verified: app role without GUC sees 0 rows,
worker sees 1 in each table.

Global unique constraints such as `execution_orders(source_system,
source_order_id)` are still global; per-tenant runtimes that reuse source ids
will need the constraints widened to include `tenant_id`.

## 17. Tenant-scoped uniqueness (2026-11-17)

`execution_orders` and `execution_trades` uniqueness now includes `tenant_id`
(migration `8f43eae7587d`). Two tenants may use the same source/system id;
duplicates within one tenant are still rejected. Verified on PostgreSQL.

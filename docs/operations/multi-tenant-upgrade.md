# Multi-Tenant Production Upgrade (2026-11-17)

This guide moves an existing single-role deployment to the split-role,
RLS-enabled setup. **Do not skip the migration step** and do not point the API at
`alphaloop_app` before the role grants exist.

## 0. Preconditions

- PostgreSQL 14+.
- Backup: `pg_dump` the database and record the current Alembic revision.
- Maintenance window: the API/worker restart briefly.
- `psql`, `pg_ctl` available on the host or in the postgres container.

```bash
cd backend
alembic current
pg_dump "$DATABASE_URL" > backup-$(date +%F).sql
```

## 1. Apply migrations as the owner

Use the owner/superuser URL, not `alphaloop_app`:

```bash
cd backend
DATABASE_URL='postgresql://pulsedesk:pulsedesk@HOST:5432/pulsedesk' \
  alembic upgrade head
```

Expected head: `8f43eae7587d` (or newer). This creates tenant columns, backfills
data, creates policies, enables RLS, and widens execution uniqueness.

## 2. Create the runtime roles

On a **fresh** Docker volume the init script runs automatically. For an existing
database, run it manually:

```bash
PGHOST=HOST PGPORT=5432 POSTGRES_USER=pulsedesk POSTGRES_DB=pulsedesk \
APP_DB_PASSWORD='<strong-app-password>' \
WORKER_DB_PASSWORD='<strong-worker-password>' \
./deploy/postgres/init-tenant-roles.sh
```

Roles:

| Role | Attribute | Purpose |
|---|---|---|
| `alphaloop_app` | `NOBYPASSRLS` | API, tenant GUC required |
| `alphaloop_worker` | `BYPASSRLS` | command worker, scheduler, reconciliation |

Verify:

```sql
select rolname, rolbypassrls from pg_roles where rolname like 'alphaloop_%';
```

## 3. Point the API and workers at the new roles

Set in `.env` / compose environment:

```bash
DATABASE_URL=postgresql://alphaloop_app:<app-password>@HOST:5432/pulsedesk
DATABASE_URL_WORKER=postgresql://alphaloop_worker:<worker-password>@HOST:5432/pulsedesk
```

`DATABASE_URL_WORKER` is optional; if omitted, workers share the API URL and
will be blocked by RLS once a policy applies to their tables.

## 4. Preflight

```bash
APP_ENV=production scripts/preflight.sh
```

It must report:

- no security-config problems;
- connected as `alphaloop_app` (not superuser / BYPASSRLS);
- 11+ RLS-enabled tables;
- current revision == Alembic head.

## 5. Restart and verify

```bash
scripts/deploy.sh remote user@host   # or docker compose up -d
scripts/smoke.sh
```

Check:

- login + dashboard;
- create a strategy and a version;
- run a backtest (worker writes `backtest_runs` under BYPASSRLS);
- ledger/orders remain visible to the owning tenant;
- a second tenant cannot list or fetch the first tenant's strategy.

For a disposable end-to-end check:

```bash
scripts/verify-tenant-isolation.sh
```

## Rollback

1. Set `DATABASE_URL` / `DATABASE_URL_WORKER` back to the owner URL and restart.
2. If a migration must be reverted, run `alembic downgrade -1` per step **before**
   removing the roles. Downgrades disable RLS/drop policies for the table.
3. Restore the `pg_dump` backup if data backfills must be undone.

## Known limitations

- RLS applies to the API role only; owners and superusers bypass it by design.
- Workers need `BYPASSRLS` or they will see no tenant rows.
- `risk_policy_versions` and `freqtrade_runs`/`order_fills` ownership is derived;
  direct-by-id access paths still need application checks.
- `init_db()` create_all is not a migration; always run Alembic first.

## 历史数据回填（旧策略表）

旧表 `ai_research_links` / `attribution_reports` / `canvas_workflows` /
`freqai_runs` / `risk_events` 没有原始归属字段；新表启用 RLS 后，`tenant_id`
为空的历史行对租户不可见。

单租户升级时，把历史行归到一个租户：

```bash
python scripts/backfill-legacy-tenant.py --tenant-id 1 --dry-run
python scripts/backfill-legacy-tenant.py --tenant-id 1
```

- 默认拒绝多租户环境；确需执行时加 `--force`。
- 先跑 `--dry-run` 查看每张表待回填行数。

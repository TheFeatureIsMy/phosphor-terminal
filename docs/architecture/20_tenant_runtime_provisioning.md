# Tenant Runtime Provisioning Design (2026-11-17)

Status: design. Execution routing, credentials and per-tenant profile exist; the
runtime itself is still provisioned manually. This document defines the contract
for automating it.

## 1. Runtime unit

One **Freqtrade runtime per tenant** (not per strategy) for paper/live-small:

| Item | Value |
|---|---|
| Container name | `alphaloop-ft-{tenant_id}` |
| Data dir | `/data/tenants/{tenant_id}` |
| Config | `/data/tenants/{tenant_id}/config.json` |
| Rules | `/data/tenants/{tenant_id}/user_data/strategies/` |
| Trade DB | `/data/tenants/{tenant_id}/tradesv3.sqlite` |
| API port | `19{tenant_id:04d}` (e.g. tenant 42 → 19042), internally only |
| API bind | `0.0.0.0` inside container, **not** published to host |
| Credentials | per-tenant `api_username` / encrypted `api_password` in the profile |

The API reaches the runtime over the compose/K8s network by container name, not
through the public ingress:

```
tenant_execution_profiles.freqtrade_url = http://alphaloop-ft-42:8080
```

## 2. Provisioning flow

1. Tenant owner requests execution (or platform admin enables it).
2. Control plane validates plan/quota:
   - tenant has an active subscription / execution entitlement;
   - runtime count per plan;
   - CPU/memory/disk quota.
3. Create the data directory and generate config from:
   - the tenant's capital pool (budget/risk limits);
   - the strategy DSL (symbols/timeframe/stoploss/max_open_trades);
   - the profile max_open_trades cap;
   - a unique API password (stored encrypted in the profile).
4. Start the container with the generated config and a read-only rules mount.
5. Wait for `/api/v1/ping` on the internal API.
6. Write `freqtrade_url`, `api_username`, `api_password_ct`, `enabled=true` to the
   profile.
7. Emit an audit event (who/when/image/config hash).

## 3. Lifecycle

| Action | Behaviour |
|---|---|
| start | create missing dir/config, start container, wait for ping |
| stop | stop container, keep volume for audit |
| destroy | stop + remove container; volume retained N days then purged |
| rotate credentials | generate new password, restart runtime, update profile |
| upgrade image | stop, backup config/DB, start new image, ping, rollback on failure |
| health | `/api/v1/ping` + heartbeat + trade DB mtime |
| idle | no runs/positions for N days → stop (not destroy) |

Every action must be idempotent and recorded in `provider_audit_logs` or a new
`tenant_runtime_events` table.

## 4. Isolation requirements

- No host bind mounts; only the tenant volume.
- Runtime cannot reach other tenants' volumes or the metadata service.
- Egress limited to exchange endpoints + internal API; deny all by default.
- CPU/memory limits; pids limit; read-only root filesystem.
- One exchange API key per tenant; never shared.
- Secrets injected at start, not baked into images.

## 5. Control-plane API (planned)

```
POST /api/admin/execution-profile/provision   # create/start
POST /api/admin/execution-profile/stop
POST /api/admin/execution-profile/rotate-credentials
GET  /api/admin/execution-profile/plan        # implemented: dir/port/limits
GET  /api/admin/execution-profile/health      # exists today
```

All are tenant-scoped, superuser/owner gated, audited, and rate-limited.

## 6. Failure modes

| Failure | Handling |
|---|---|
| image pull fails | keep old container, report `image_unavailable` |
| ping timeout | mark profile `enabled=false`, alert, keep logs |
| DB corrupt | restore latest backup, freeze trading |
| disk full | stop new starts, alert, do not delete volume |
| credential mismatch | rotate, restart, re-check |
| exchange outage | runtime stays up; execution commands fail closed |

## 7. Rollout

1. Manual provisioning (today): operator creates container, fills profile URL and
   credentials.
2. `plan` + `provision` for a single staging tenant; no live trading.
3. Automate compose-based provisioning for paper tenants.
4. Move to K8s Jobs for live runs; one job per run, not per tenant.
5. Enforce quotas/billing before enabling live.

## 7.1 Operator scripts (2026-11-17)

`scripts/provision-tenant-runtime.sh` implements the container half:

```bash
scripts/provision-tenant-runtime.sh --tenant-id 42 --dry-run
scripts/provision-tenant-runtime.sh --tenant-id 42
```

- deterministic name/dir/port;
- CPU/memory/pids limits;
- no published host port (internal network only);
- copies a config template on first run;
- prints the profile URL to write via the admin API.

`scripts/deprovision-tenant-runtime.sh --tenant-id 42 [--purge]` stops the
container; purging data requires `CONFIRM_PURGE=1`.

Tenant config generation is now scripted:

```bash
scripts/generate-tenant-config.py --tenant-id 42 --dsl dsl.json \
  --budget 10000 --position-pct 0.02 --max-open-trades 2 \
  --out /data/tenants/42/config.json

scripts/provision-tenant-runtime.sh --tenant-id 42 \
  --config /data/tenants/42/config.json
```

`build_tenant_runtime_config` emits `db_url`, `user_data_dir`, API bind
`0.0.0.0`, per-tenant API credentials, demo map for dry-run and live map for
live. Exchange keys are stored encrypted on the tenant execution profile and can be
rendered server-side without putting them on a command line:

```bash
POST /api/admin/execution-profile/render-config
  { "dsl": {...}, "budget": 10000, "dry_run": true }
```

The response contains the full runtime config (including exchange key/secret)
and is restricted to platform admins over the authenticated API.

`POST /api/admin/execution-profile/write-config` persists it atomically to
`{TENANT_DATA_ROOT}/{tenant_id}/config.json` with mode 0600, then returns the
path and SHA-256. `TENANT_DATA_ROOT` defaults to `/data/tenants`.

Rotate the runtime API password with:

```bash
POST /api/admin/execution-profile/rotate-credentials
```

It returns the new password exactly once; render a new config and restart the
runtime. Data directories are created with mode 0700 and config files 0600.

## 8. Non-goals

- Sharing one Freqtrade process across tenants.
- Letting clients talk to Freqtrade directly.
- Multi-region runtime placement in the first iteration.

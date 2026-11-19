# Production compose

`docker-compose.prod.yml` is an override for `docker-compose.yml`. It removes
the API source bind mount, runs migrations as a one-shot job, and requires
explicit secrets/URLs.

Requirements: Docker Compose **>= 2.24.4** (uses `!override`).

## Environment

```bash
export DATABASE_URL='postgresql://alphaloop_app:...@postgres:5432/pulsedesk'
export DATABASE_URL_WORKER='postgresql://alphaloop_worker:...@postgres:5432/pulsedesk'
export SECRET_KEY='<64 hex chars>'
export PULSEDESK_ENCRYPTION_KEY='<fernet key>'
export CORS_ORIGINS='["https://app.example.com"]'
export PUBLIC_BASE_URL='https://app.example.com'
```

The app/worker roles are created on a fresh Postgres volume by
`deploy/postgres/init-tenant-roles.sh` (see `docs/operations/multi-tenant-upgrade.md`).
If the volume already exists, create/rotate the roles manually.

## Start

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml build
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

`migrate` runs `alembic upgrade head` and must complete before `api` starts.

## Tenant runtime data

Per-tenant rendered Freqtrade configs live in the `tenantdata` volume at
`/var/lib/alphaloop/tenants/<tenant_id>/config.json`.

The API's provisioning endpoint (`TENANT_RUNTIME_PROVISIONING_ENABLED`) needs
access to a Docker socket to start sibling containers. That is intentionally
**not** mounted by default; enable it only on a dedicated runtime host.

## Enable per-tenant runtime (privileged)

```bash
docker compose -f docker-compose.yml -f docker-compose.prod.yml \
  -f docker-compose.runtime.yml up -d
```

This mounts `/var/run/docker.sock` and sets
`TENANT_RUNTIME_PROVISIONING_ENABLED=true`, allowing the API to start
`alphaloop-ft-<tenant_id>` containers.

Security notes:

- Docker socket access is equivalent to host root. Use a dedicated host.
- Set `TENANT_RUNTIME_NETWORK` to the compose network name (default
  `phosphor-terminal_default`).
- Tenant containers are started without published ports; the API reaches them
  by container name on that network.
- Disable the override (`TENANT_RUNTIME_PROVISIONING_ENABLED=false`) on
  control-plane-only deployments.

## Web container

`docker-compose.yml` now includes a `web` service (Nginx) built from
`web/Dockerfile`:

- serves the Vite production build;
- SPA fallback to `index.html`;
- proxies `/api/` and `/auth/` to `api:8000` (WebSocket upgrade enabled);
- listens on host port `3000` (container port 8080).

This makes the stack reachable at `http://localhost:3000` with same-origin API
calls, so no CORS configuration is needed for the bundled web app.

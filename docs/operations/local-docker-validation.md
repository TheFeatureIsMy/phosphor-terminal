# Local Docker / K8s validation (2026-11-19)

Docker was installed without Homebrew via Colima + Lima binaries under
`.tools/` (Homebrew 3.5.9 cannot run on macOS 27.2).

## Docker stack

Running containers:

- `phosphor-terminal-postgres-1` (postgres:16-alpine, healthy)
- `phosphor-terminal-redis-1` (redis:7-alpine, healthy)
- `alphaloop-api-test` (API image, port 8000)
- `alphaloop-web-test` (Nginx production build, port 3000)

Migrations applied against the container DB through the host:

```bash
DATABASE_URL=postgresql://pulsedesk:pulsedesk@127.0.0.1:5432/pulsedesk \
  alembic upgrade head
```

Verified:

- `GET /health` → 200
- `GET /readiness` → 200 (`database=connected`, `redis=connected`)
- Nginx `http://127.0.0.1:3000` serves the production build
- `/auth/register`, `/auth/login`, `/api/v1/billing/plans`,
  `/api/overview/dashboard` work through the Nginx proxy
- Chrome login → dashboard rendered (`docs/assets/docker-fullstack-dashboard.png`)

Notes:

- The API image used for this run was built with a temporary core-deps
  Dockerfile (not committed) because the full requirements build was extremely
  slow over the proxy. The production `backend/Dockerfile` is unchanged.
- Freqtrade was not started, so the dashboard correctly reports
  `freqtrade_disconnected` / trading engine unavailable.

## Kubernetes

Installed `k3d` under `.tools/k3d` and created a single-node cluster
`alphaloop` (k3s v1.35.5). Manifests were validated with server-side dry-run:

```bash
kubectl apply -f deploy/k8s/base/namespace.yaml
kubectl apply --dry-run=server -k deploy/k8s/base
```

All resources accepted, including RBAC, PVC, NetworkPolicy, worker deployment,
and migrate Job.

## Reproduce

```bash
export PATH="$PWD/.tools/colima:$PWD/.tools/lima/bin:$PWD/.tools/k3d:$PATH"
export DOCKER_CONFIG="$PWD/.tools/docker"
colima start
```

Stop:

```bash
docker rm -f alphaloop-web-test alphaloop-api-test
docker compose down
k3d cluster delete alphaloop
colima stop
```

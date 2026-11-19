# Kubernetes manifests

`deploy/k8s/base` contains a minimal control-plane deployment:

- `api` Deployment (2 replicas, loops disabled);
- `worker` Deployment (2 replicas, runs `python -m app.worker_main`);
- `web` Deployment (Nginx, port 8080);
- `migrate` Job (`alembic upgrade head`);
- ConfigMap, Ingress, Services.

## Images

Replace `ghcr.io/example/...` with your registry. Build from:

```bash
docker build -t ghcr.io/you/alphaloop-api backend
docker build -t ghcr.io/you/alphaloop-web web
```

The API image runs as UID 10001; the web image is nginx-unprivileged (8080).

## Secrets

`secret.example.yaml` is **not** included in kustomization. Create the real
secret before applying:

```bash
kubectl -n alphaloop create secret generic alphaloop-secrets \
  --from-literal=DATABASE_URL=... \
  --from-literal=DATABASE_URL_WORKER=... \
  --from-literal=SECRET_KEY=... \
  --from-literal=PULSEDESK_ENCRYPTION_KEY=...
```

## Apply

```bash
kubectl apply -k deploy/k8s/base
kubectl -n alphaloop wait --for=condition=complete job/alphaloop-migrate --timeout=300s
```

Postgres/Redis/Freqtrade are assumed to exist (managed services or separate
manifests). Update `configmap.yaml` with their endpoints.

## Tenant runtime

Set `TENANT_RUNTIME_PROVIDER=kubernetes` to generate per-tenant Deployment +
Service manifests and apply them with `kubectl`:

```env
TENANT_RUNTIME_PROVISIONING_ENABLED=true
TENANT_RUNTIME_PROVIDER=kubernetes
TENANT_RUNTIME_NAMESPACE=alphaloop
TENANT_RUNTIME_PVC=alphaloop-tenant-data
```

The API pod and tenant pods must mount the same PVC at
`/var/lib/alphaloop/tenants`; render/write the tenant config first, then call
`POST /api/admin/execution-profile/provision?dry_run=false`.

The API runs as ServiceAccount `alphaloop-api`; `rbac.yaml` grants it
namespace-scoped Deployment/Service management (the minimum needed for the
provisioner). The provisioner is disabled by default.

`pvc.yaml` defines `alphaloop-tenant-data` with `ReadWriteMany`; use a storage
class that supports RWX (e.g. NFS/CephFS/EFS). API, worker and tenant pods all
mount it at `/var/lib/alphaloop/tenants`.

`networkpolicy.yaml` restricts tenant Freqtrade ingress to the API pods on port
8080; egress remains open for exchange/DNS traffic. Tenant pods also drop all
Linux capabilities and use the RuntimeDefault seccomp profile.

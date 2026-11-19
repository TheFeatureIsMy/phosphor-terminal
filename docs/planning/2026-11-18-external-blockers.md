# External blockers (2026-11-18)

All software-side work in this session is complete and verified. The remaining
release steps cannot be performed from this environment:

| Blocker | Evidence | Needed to proceed |
|---|---|---|
| Docker | verified locally via Colima | production host still needed |
| Kubernetes | k3d server dry-run passed | real cluster + registry still needed |
| Exchange network unreachable | `api.binance.com` request times out | network access to Binance |
| Live payment provider | no Stripe test keys | test-mode Stripe account/keys |
| Per-tenant Freqtrade | image not started yet | exchange access + runtime host |

## Verified before blocking

- PostgreSQL full suite: 1577 passed / 3 skipped.
- SQLite full suite: 1574 passed / 6 skipped.
- Tenant isolation: PASS.
- Web Playwright E2E: 3 passed.
- iOS simulator UI test: passed.
- RLS: 47 tenant tables, 42 RLS, 5 allowlisted.
- GitHub Actions: all jobs green (run 44567150111).
- Local Docker full stack + k3d server-side validation passed.

## What remains after unblocking

1. `docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d`
   (plus `.runtime.yml` for tenant containers).
2. `kubectl apply -k deploy/k8s/base` on staging.
3. Trigger CI (backend, postgres, tenant-isolation, web-e2e, iOS).
4. Run one real backtest + paper session against an exchange.
5. Stripe test-mode webhook/plan round trip.

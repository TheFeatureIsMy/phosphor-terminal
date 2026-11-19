"""Command Bus commands carry the tenant for fair scheduling/filtering."""
from app.security.tenant_context import reset_current_tenant, set_current_tenant
from app.services.command_bus import CommandBusService


def _enqueue(session, key, payload):
    return CommandBusService(session).enqueue(
        command_type="start_backtest",
        aggregate_type="strategy",
        payload=payload,
        idempotency_key=key,
        requested_by="test",
    )[0]


def test_enqueue_uses_tenant_context(session):
    token = set_current_tenant(5)
    try:
        cmd = _enqueue(session, "tenant-context", {})
        assert cmd.tenant_id == 5
    finally:
        reset_current_tenant(token)


def test_payload_tenant_wins_over_context(session):
    token = set_current_tenant(5)
    try:
        cmd = _enqueue(session, "tenant-payload", {"tenant_id": 6})
        assert cmd.tenant_id == 6
    finally:
        reset_current_tenant(token)

"""Per-request tenant context for database sessions.

RLS policies read ``app.tenant_id`` from the PostgreSQL transaction. The
context var is set by AuthMiddleware from the JWT `tid` claim and consumed by
the SQLAlchemy ``after_begin`` hook in app.database.
"""
from __future__ import annotations

from contextvars import ContextVar, Token

_current_tenant_id: ContextVar[int | None] = ContextVar(
    "current_tenant_id", default=None,
)


def set_current_tenant(tenant_id: int | None) -> Token:
    return _current_tenant_id.set(tenant_id)


def reset_current_tenant(token: Token) -> None:
    _current_tenant_id.reset(token)


def get_current_tenant() -> int | None:
    return _current_tenant_id.get()

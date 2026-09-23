"""StateLeaseService — mutual-exclusion leases over stateful resources (PRD §7.3).

A lease grants its owner exclusive authority to mutate a resource (keyed by
``resource_key``) until it expires or is released. Reconciliation runs
acquire a lease before executing so that concurrent actors cannot interleave
state changes with drift detection.

Semantics:
- acquire: succeeds when no active lease exists (expired/released leases are
  taken over); fails when another owner holds an active lease.
- renew: only the current owner may extend the expiry.
- release: only the current owner may release; idempotent afterwards.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.reconciliation import StateLease

logger = logging.getLogger(__name__)


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class StateLeaseService:
    def __init__(self, session: Session):
        self._s = session

    def _get(self, resource_key: str) -> StateLease | None:
        stmt = select(StateLease).where(StateLease.resource_key == resource_key)
        return self._s.scalar(stmt)

    @staticmethod
    def _is_active(lease: StateLease, now: datetime) -> bool:
        if lease.released:
            return False
        expires = lease.expires_at
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        return expires > now

    def acquire(
        self,
        resource_key: str,
        owner: str,
        ttl_sec: int = 300,
        purpose: str | None = None,
    ) -> tuple[StateLease | None, str]:
        """Acquire a lease. Returns (lease, status) where status is one of
        acquired / taken_over / already_held / renewed_own."""
        now = _utcnow()
        existing = self._get(resource_key)

        if existing is not None and self._is_active(existing, now):
            if existing.owner == owner:
                existing.expires_at = now + timedelta(seconds=ttl_sec)
                self._s.flush()
                return existing, "renewed_own"
            return None, "already_held"

        if existing is not None:
            # Expired or released — take over the row
            existing.owner = owner
            existing.purpose = purpose
            existing.acquired_at = now
            existing.expires_at = now + timedelta(seconds=ttl_sec)
            existing.released = False
            self._s.flush()
            return existing, "taken_over"

        lease = StateLease(
            resource_key=resource_key,
            owner=owner,
            purpose=purpose,
            acquired_at=now,
            expires_at=now + timedelta(seconds=ttl_sec),
            released=False,
        )
        self._s.add(lease)
        self._s.flush()
        return lease, "acquired"

    def renew(self, resource_key: str, owner: str, ttl_sec: int = 300) -> bool:
        lease = self._get(resource_key)
        now = _utcnow()
        if lease is None or lease.owner != owner or not self._is_active(lease, now):
            return False
        lease.expires_at = now + timedelta(seconds=ttl_sec)
        self._s.flush()
        return True

    def release(self, resource_key: str, owner: str) -> bool:
        lease = self._get(resource_key)
        if lease is None or lease.owner != owner or lease.released:
            return False
        lease.released = True
        self._s.flush()
        return True

    def force_release_expired(self, resource_key: str) -> bool:
        """Release a lease only if it has already expired (ops endpoint)."""
        lease = self._get(resource_key)
        if lease is None or lease.released:
            return False
        if self._is_active(lease, _utcnow()):
            return False
        lease.released = True
        self._s.flush()
        return True

    def list_active(self) -> list[StateLease]:
        now = _utcnow()
        leases = list(self._s.scalars(
            select(StateLease).order_by(StateLease.acquired_at.desc())
        ).all())
        return [lk for lk in leases if self._is_active(lk, now)]

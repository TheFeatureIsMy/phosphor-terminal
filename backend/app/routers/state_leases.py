"""State leases router — PRD §7.3 对账总线 State Lease Monitor."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.state_lease_service import StateLeaseService

router = APIRouter(prefix="/api/state-leases", tags=["state-leases"])


@router.get("")
def list_state_leases(db: Session = Depends(get_db)):
    """List active state leases (expired/released are excluded)."""
    svc = StateLeaseService(db)
    leases = svc.list_active()
    return {
        "state": "healthy",
        "reason_codes": [],
        "available_actions": [],
        "leases": [
            {
                "id": str(lk.id),
                "resource_key": lk.resource_key,
                "owner": lk.owner,
                "purpose": lk.purpose,
                "acquired_at": lk.acquired_at.isoformat() if lk.acquired_at else None,
                "expires_at": lk.expires_at.isoformat() if lk.expires_at else None,
            }
            for lk in leases
        ],
        "total": len(leases),
    }


@router.post("/{lease_id}/release")
def release_state_lease(lease_id: str, db: Session = Depends(get_db)):
    """Ops endpoint: release a lease only if it has already expired."""
    from app.domain.reconciliation import StateLease

    lease = db.get(StateLease, lease_id)
    if lease is None:
        raise HTTPException(status_code=404, detail="StateLease not found")

    svc = StateLeaseService(db)
    released = svc.force_release_expired(lease.resource_key)
    db.commit()
    if not released:
        raise HTTPException(status_code=409, detail={
            "state": "blocked",
            "reason_codes": ["lease_still_active_or_already_released"],
        })
    return {"state": "healthy", "reason_codes": [], "released_lease_id": lease_id}

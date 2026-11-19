"""Tenant plan limits (simple, code-defined plans)."""
from __future__ import annotations

from fastapi import HTTPException, status

PLAN_LIMITS = {
    "free": {"members": 5, "strategies": 20, "audit_days": 90},
    "pro": {"members": 25, "strategies": 200, "audit_days": 365},
    "enterprise": {"members": 200, "strategies": 2000, "audit_days": 1095},
}


def limits_for(plan: str | None) -> dict[str, int]:
    return PLAN_LIMITS.get(plan or "free", PLAN_LIMITS["free"])


def enforce_member_limit(db, tenant, current_members: int) -> None:
    limit = limits_for(tenant.plan)["members"]
    if current_members >= limit:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Tenant member limit reached ({limit} on {tenant.plan})",
        )


def enforce_strategy_limit(db, tenant, current_strategies: int) -> None:
    limit = limits_for(tenant.plan)["strategies"]
    if current_strategies >= limit:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Tenant strategy limit reached ({limit} on {tenant.plan})",
        )


QUOTA_WARN_RATIO = 0.8


def quota_warnings(
    plan: str | None, usage: dict[str, int], ratio: float | None = None
) -> list[dict]:
    """Return resources at/above the configured ratio of their plan limit."""
    from app.config import settings

    threshold = ratio if ratio is not None else settings.tenant_quota_warn_ratio
    limits = limits_for(plan)
    warnings = []
    for key in ("members", "strategies"):
        limit = limits[key]
        used = usage.get(key, 0)
        if limit > 0 and used / limit >= threshold:
            warnings.append({"resource": key, "used": used, "limit": limit})
    if limits["audit_days"] > 0 and usage.get("audit_logs", 0) >= limits["audit_days"] * 1000:
        warnings.append({
            "resource": "audit_logs",
            "used": usage["audit_logs"],
            "limit": limits["audit_days"] * 1000,
        })
    return warnings

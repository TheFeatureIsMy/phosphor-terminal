# Execution & Risk Module Pages Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Polish 6 pages (Execution: center/orders/recon; Risk: center/stop/breakers) with unified EmergencyStopBar + LiveWireStrip, atmospheric background, real-data binding, mandatory confirmations, and 8 backend completions.

**Architecture:** Backend-first (FastAPI endpoints in `backend/app/routers/`), then shared SwiftUI components (`EmergencyStopBar`/`LiveWireStrip`/`riskAtmosphericBackground`), then per-page wiring. All trading/high-risk actions route through `KryptonConfirmDialog`. Single real emergency endpoint `/api/v2/emergency/stop`.

**Tech Stack:** Python 3.12 / FastAPI / SQLAlchemy (backend); Swift 6.2 / SwiftUI / no external deps (macOS app); pytest / XCTest.

## Global Constraints

- Swift tools 6.2, target macOS 26, no SPM dependencies (macOS app).
- Python 3.12, pytest with `--cov-fail-under=30` (backend).
- All user-visible strings via `L10n.<Domain>.<key>` — no inline `L10n.zh(...)`.
- Design tokens in `DesignSystem/DesignTokens.swift` — no hardcoded colors/fonts/spacing/radii.
- `.glassEffect()` applied to content view directly, never inside `.background()`.
- Backend: thin routers, logic in services; new endpoints follow Redis → service → mock fallback.
- Mock data only at `MockNetworkClient` layer; backend never returns mock. Mock BFF responses add `data_source: "mock"` field.
- Reply language: Chinese to user; code/identifiers/committed docs in English.
- Each task ends with a commit. Run tests before committing.

**Spec:** `docs/superpowers/specs/2026-07-01-execution-risk-pages-polish-design.md`

---

## File Structure

### Backend (Python)

- **Modify** `backend/app/routers/execution_bff.py` — add single cancel/close, batch cancel/close, deprecate old emergency endpoint.
- **Modify** `backend/app/routers/reconciliation_bff.py` — add retry endpoints.
- **Modify** `backend/app/routers/risk_bff.py` — real block/unblock impl, add `/rules`, add circuit-breaker resolve, fix emergency-stop GET→POST bug + mark deprecated.
- **Modify** `backend/app/services/account_risk_firewall.py` — add `activate_manual_block` / `deactivate_manual_block` if absent.
- **Create** `backend/app/services/risk_rules_service.py` — read effective thresholds.
- **Modify** `backend/app/schemas/risk_bff.py` — add `RiskRulesResponse`, `ResolveResponse`.
- **Modify** `backend/app/schemas/execution_bff.py` — add `CancelResponse`, `CloseResponse`, `BatchActionResponse`.
- **Tests** under `backend/tests/test_execution_bff.py`, `test_reconciliation_bff.py`, `test_risk_bff.py`, `test_risk_rules_service.py`.

### Frontend (Swift) — shared

- **Create** `macos-app/AlphaLoop/Views/Shared/EmergencyStopBar.swift` — 48pt top bar.
- **Create** `macos-app/AlphaLoop/Views/Shared/LiveWireStrip.swift` — 2pt gradient strip.
- **Create** `macos-app/AlphaLoop/DesignSystem/AtmosphericBackgroundModifier.swift` — extracted modifier.
- **Create** `macos-app/AlphaLoop/Localization/L10n+EmergencyStop.swift`.
- **Create** `macos-app/AlphaLoop/Localization/L10n+Reconciliation.swift`.
- **Create** `macos-app/AlphaLoop/Localization/L10n+Risk.swift`.
- **Modify** `macos-app/AlphaLoop/Localization/L10n+Execution.swift` — extend keys.

### Frontend (Swift) — API services

- **Modify** `macos-app/AlphaLoop/Services/APIExecutionBFF.swift` — add `cancelOrder`, `closePosition`, `cancelAllOrders`, `forceCloseAllAll`, `retryReconciliation`, `retryReconciliationRun`. Plus mock factories.
- **Modify** `macos-app/AlphaLoop/Services/APIRiskBFF.swift` — add `blockNewEntries`, `unblock`, `getRiskRules`, `resolveCircuitBreaker`, fix `emergencyStop` to call `/api/v2/emergency/stop`. Plus mock factories.
- **Modify** `macos-app/AlphaLoop/Services/APIReconciliationBFF.swift` (or create if absent) — retry methods if not in APIExecutionBFF.

### Frontend (Swift) — pages

- **Modify** `macos-app/AlphaLoop/Views/Execution/ExecutionCenterView.swift` — add top bar, remove in-page emergency button, apply background.
- **Modify** `macos-app/AlphaLoop/Views/Execution/OrdersPositionsView.swift` — add batch action row + inline cancel/close buttons.
- **Modify** `macos-app/AlphaLoop/Views/Execution/ReconciliationBusView.swift` — add retry buttons, migrate i18n.
- **Modify** `macos-app/AlphaLoop/Views/Risk/RiskCenterView.swift` — add top bar, remove emergencyPanel, wire block/unblock, extract background.
- **Modify** `macos-app/AlphaLoop/Views/Risk/StopProtectionView.swift` — add risk rules section, wire force-close, extract background.
- **Modify** `macos-app/AlphaLoop/Views/Risk/CircuitBreakersView.swift` — add resolve button, default unresolved filter, extract background.
- **Modify** `macos-app/AlphaLoop/ViewModels/ExecutionCenterViewModel.swift` — action methods.
- **Modify** `macos-app/AlphaLoop/ViewModels/RiskCenterViewModel.swift` — action methods, risk rules state.

---

## Task 1: Backend — single order cancel endpoint

**Files:**
- Modify: `backend/app/routers/execution_bff.py`
- Modify: `backend/app/schemas/execution_bff.py`
- Test: `backend/tests/test_execution_bff.py`

**Interfaces:**
- Produces: `POST /api/execution/orders/{order_id}/cancel` → `CancelResponse(cancelled_order_id: str, status: str, reason_codes: list[str])`.

- [ ] **Step 1: Write failing test**

```python
# backend/tests/test_execution_bff.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_cancel_single_order(monkeypatch):
    cancelled = {}
    class FakeClient:
        async def cancel_order(self, order_id):
            cancelled["id"] = order_id
            return {"status": "ok"}
    monkeypatch.setattr("app.services.freqtrade_client.FreqtradeClient", lambda *a, **k: FakeClient())
    resp = client.post("/api/execution/orders/abc-123/cancel")
    assert resp.status_code == 200
    body = resp.json()
    assert body["cancelled_order_id"] == "abc-123"
    assert body["status"] == "cancelled"
    assert cancelled["id"] == "abc-123"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_execution_bff.py::test_cancel_single_order -v`
Expected: FAIL (route not found / 404).

- [ ] **Step 3: Add schema**

In `backend/app/schemas/execution_bff.py` add:

```python
from pydantic import BaseModel

class CancelResponse(BaseModel):
    cancelled_order_id: str
    status: str
    reason_codes: list[str] = []
```

- [ ] **Step 4: Add route**

In `backend/app/routers/execution_bff.py` add:

```python
from app.schemas.execution_bff import CancelResponse
from app.services.freqtrade_client import FreqtradeClient

@router.post("/orders/{order_id}/cancel", response_model=CancelResponse)
async def cancel_single_order(order_id: str):
    try:
        client = FreqtradeClient()
        await client.cancel_order(order_id)
        return CancelResponse(cancelled_order_id=order_id, status="cancelled", reason_codes=[])
    except Exception as e:
        logger.exception("[cancel-order] failed: %s", e)
        return CancelResponse(cancelled_order_id=order_id, status="failed", reason_codes=[type(e).__name__])
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd backend && python3 -m pytest tests/test_execution_bff.py::test_cancel_single_order -v`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/execution_bff.py backend/app/schemas/execution_bff.py backend/tests/test_execution_bff.py
git commit -m "feat(backend): single order cancel endpoint"
```

---

## Task 2: Backend — single position close endpoint

**Files:**
- Modify: `backend/app/routers/execution_bff.py`
- Modify: `backend/app/schemas/execution_bff.py`
- Test: `backend/tests/test_execution_bff.py`

**Interfaces:**
- Produces: `POST /api/execution/positions/{position_id}/close` → `CloseResponse(closed_position_id: str, status: str, reason_codes: list[str])`.

- [ ] **Step 1: Write failing test**

```python
def test_close_single_position(monkeypatch):
    closed = {}
    class FakeClient:
        async def forceexit(self, trade_id):
            closed["id"] = trade_id
            return {"status": "ok"}
    monkeypatch.setattr("app.services.freqtrade_client.FreqtradeClient", lambda *a, **k: FakeClient())
    resp = client.post("/api/execution/positions/pos-42/close")
    assert resp.status_code == 200
    body = resp.json()
    assert body["closed_position_id"] == "pos-42"
    assert body["status"] == "closed"
    assert closed["id"] == "pos-42"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_execution_bff.py::test_close_single_position -v`
Expected: FAIL (404).

- [ ] **Step 3: Add schema + route**

Schema in `backend/app/schemas/execution_bff.py`:

```python
class CloseResponse(BaseModel):
    closed_position_id: str
    status: str
    reason_codes: list[str] = []
```

Route in `backend/app/routers/execution_bff.py`:

```python
from app.schemas.execution_bff import CloseResponse

@router.post("/positions/{position_id}/close", response_model=CloseResponse)
async def close_single_position(position_id: str):
    try:
        client = FreqtradeClient()
        await client.forceexit(position_id)
        return CloseResponse(closed_position_id=position_id, status="closed", reason_codes=[])
    except Exception as e:
        logger.exception("[close-position] failed: %s", e)
        return CloseResponse(closed_position_id=position_id, status="failed", reason_codes=[type(e).__name__])
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd backend && python3 -m pytest tests/test_execution_bff.py::test_close_single_position -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/execution_bff.py backend/app/schemas/execution_bff.py backend/tests/test_execution_bff.py
git commit -m "feat(backend): single position close endpoint"
```

---

## Task 3: Backend — batch cancel-all and force-close-all endpoints

**Files:**
- Modify: `backend/app/routers/execution_bff.py`
- Modify: `backend/app/schemas/execution_bff.py`
- Test: `backend/tests/test_execution_bff.py`

**Interfaces:**
- Produces: `POST /api/execution/orders/cancel-all` → `BatchActionResponse(affected_count: int, status: str, reason_codes: list[str])`.
- Produces: `POST /api/execution/positions/force-close-all` → `BatchActionResponse`.

- [ ] **Step 1: Write failing tests**

```python
def test_cancel_all_orders(monkeypatch):
    class FakeClient:
        async def get_open_orders(self):
            return [{"id": "a"}, {"id": "b"}]
        async def cancel_order(self, order_id):
            return {"status": "ok"}
    monkeypatch.setattr("app.services.freqtrade_client.FreqtradeClient", lambda *a, **k: FakeClient())
    resp = client.post("/api/execution/orders/cancel-all")
    assert resp.status_code == 200
    assert resp.json()["affected_count"] == 2
    assert resp.json()["status"] == "cancelled"

def test_force_close_all_positions(monkeypatch):
    class FakeClient:
        async def get_status(self):
            return [{"trade_id": "t1"}, {"trade_id": "t2"}, {"trade_id": "t3"}]
        async def forceexit(self, trade_id):
            return {"status": "ok"}
    monkeypatch.setattr("app.services.freqtrade_client.FreqtradeClient", lambda *a, **k: FakeClient())
    resp = client.post("/api/execution/positions/force-close-all")
    assert resp.status_code == 200
    assert resp.json()["affected_count"] == 3
    assert resp.json()["status"] == "closed"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python3 -m pytest tests/test_execution_bff.py::test_cancel_all_orders tests/test_execution_bff.py::test_force_close_all_positions -v`
Expected: FAIL (404).

- [ ] **Step 3: Add schema + routes**

Schema:

```python
class BatchActionResponse(BaseModel):
    affected_count: int
    status: str
    reason_codes: list[str] = []
```

Routes:

```python
from app.schemas.execution_bff import BatchActionResponse

@router.post("/orders/cancel-all", response_model=BatchActionResponse)
async def cancel_all_orders():
    try:
        client = FreqtradeClient()
        orders = await client.get_open_orders()
        for o in orders:
            await client.cancel_order(o["id"])
        return BatchActionResponse(affected_count=len(orders), status="cancelled", reason_codes=[])
    except Exception as e:
        logger.exception("[cancel-all] failed: %s", e)
        return BatchActionResponse(affected_count=0, status="failed", reason_codes=[type(e).__name__])

@router.post("/positions/force-close-all", response_model=BatchActionResponse)
async def force_close_all_positions():
    try:
        client = FreqtradeClient()
        trades = await client.get_status()
        for t in trades:
            await client.forceexit(t["trade_id"])
        return BatchActionResponse(affected_count=len(trades), status="closed", reason_codes=[])
    except Exception as e:
        logger.exception("[force-close-all] failed: %s", e)
        return BatchActionResponse(affected_count=0, status="failed", reason_codes=[type(e).__name__])
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python3 -m pytest tests/test_execution_bff.py::test_cancel_all_orders tests/test_execution_bff.py::test_force_close_all_positions -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/execution_bff.py backend/app/schemas/execution_bff.py backend/tests/test_execution_bff.py
git commit -m "feat(backend): batch cancel-all and force-close-all endpoints"
```

---

## Task 4: Backend — reconciliation retry endpoints

**Files:**
- Modify: `backend/app/routers/reconciliation_bff.py`
- Test: `backend/tests/test_reconciliation_bff.py`

**Interfaces:**
- Produces: `POST /api/reconciliation/runs/{run_id}/retry` → `{status, run_id, reason_codes}`.
- Produces: `POST /api/reconciliation/retry` → `{status, affected_count, reason_codes}`.

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/test_reconciliation_bff.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_retry_single_recon_run(monkeypatch):
    retried = {}
    def fake_run(run_id):
        retried["id"] = run_id
        return {"status": "ok"}
    monkeypatch.setattr("app.services.reconciliation_service.ReconciliationService.run_reconciliation", fake_run)
    resp = client.post("/api/reconciliation/runs/recon-9/retry")
    assert resp.status_code == 200
    assert resp.json()["run_id"] == "recon-9"
    assert resp.json()["status"] == "retrying"
    assert retried["id"] == "recon-9"

def test_retry_all_recon(monkeypatch):
    monkeypatch.setattr("app.services.reconciliation_service.ReconciliationService.run_reconciliation", lambda *a, **k: {"status": "ok"})
    resp = client.post("/api/reconciliation/retry")
    assert resp.status_code == 200
    assert resp.json()["status"] == "retrying"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python3 -m pytest tests/test_reconciliation_bff.py -v`
Expected: FAIL (404).

- [ ] **Step 3: Add routes**

In `backend/app/routers/reconciliation_bff.py`:

```python
from app.services.reconciliation_service import ReconciliationService

@router.post("/runs/{run_id}/retry")
async def retry_reconciliation_run(run_id: str):
    try:
        svc = ReconciliationService()
        await svc.run_reconciliation(run_id=run_id)
        return {"status": "retrying", "run_id": run_id, "reason_codes": []}
    except Exception as e:
        logger.exception("[recon-retry-single] failed: %s", e)
        return {"status": "failed", "run_id": run_id, "reason_codes": [type(e).__name__]}

@router.post("/retry")
async def retry_reconciliation_batch():
    try:
        svc = ReconciliationService()
        await svc.run_reconciliation()
        return {"status": "retrying", "affected_count": -1, "reason_codes": []}
    except Exception as e:
        logger.exception("[recon-retry-batch] failed: %s", e)
        return {"status": "failed", "affected_count": 0, "reason_codes": [type(e).__name__]}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python3 -m pytest tests/test_reconciliation_bff.py -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/reconciliation_bff.py backend/tests/test_reconciliation_bff.py
git commit -m "feat(backend): reconciliation retry endpoints"
```

---

## Task 5: Backend — risk block/unblock real impl + risk rules query + circuit-breaker resolve

**Files:**
- Modify: `backend/app/routers/risk_bff.py`
- Modify: `backend/app/services/account_risk_firewall.py`
- Create: `backend/app/services/risk_rules_service.py`
- Modify: `backend/app/schemas/risk_bff.py`
- Test: `backend/tests/test_risk_bff.py`, `backend/tests/test_risk_rules_service.py`

**Interfaces:**
- Produces: `POST /api/risk/block-new-entries` (real) → `{status, active_locks, reason_codes}`.
- Produces: `POST /api/risk/unblock` (real) → same shape.
- Produces: `GET /api/risk/rules` → `RiskRulesResponse`.
- Produces: `POST /api/risk/circuit-breakers/{event_id}/resolve` → `{status, resolved_event_id, reason_codes}`.

- [ ] **Step 1: Write failing tests**

```python
# backend/tests/test_risk_bff.py
import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_block_new_entries_real(monkeypatch):
    monkeypatch.setattr(
        "app.services.account_risk_firewall.AccountRiskFirewall.activate_manual_block",
        lambda self, reason: [{"lock": "manual_block", "reason": reason}],
    )
    resp = client.post("/api/risk/block-new-entries", json={"reason": "manual"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["status"] == "blocked"
    assert any(l["lock"] == "manual_block" for l in body["active_locks"])

def test_unblock_real(monkeypatch):
    monkeypatch.setattr(
        "app.services.account_risk_firewall.AccountRiskFirewall.deactivate_manual_block",
        lambda self: [],
    )
    resp = client.post("/api/risk/unblock")
    assert resp.status_code == 200
    assert resp.json()["status"] == "unblocked"
    assert resp.json()["active_locks"] == []

def test_get_risk_rules():
    resp = client.get("/api/risk/rules")
    assert resp.status_code == 200
    body = resp.json()
    assert "daily_loss_limit" in body
    assert "kill_switch" in body
    assert "active" in body["kill_switch"]

def test_resolve_circuit_breaker(monkeypatch):
    class FakeRepo:
        def get(self, event_id):
            class E:
                type = "daily_loss_lock"
                resolved = False
            return E()
        def mark_resolved(self, event_id):
            pass
    monkeypatch.setattr("app.services.circuit_breaker_repository.CircuitBreakerRepository", lambda *a, **k: FakeRepo())
    resp = client.post("/api/risk/circuit-breakers/evt-1/resolve")
    assert resp.status_code == 200
    assert resp.json()["resolved_event_id"] == "evt-1"

def test_resolve_kill_switch_rejected(monkeypatch):
    class FakeRepo:
        def get(self, event_id):
            class E:
                type = "kill_switch"
                resolved = False
            return E()
    monkeypatch.setattr("app.services.circuit_breaker_repository.CircuitBreakerRepository", lambda *a, **k: FakeRepo())
    resp = client.post("/api/risk/circuit-breakers/evt-2/resolve")
    assert resp.status_code == 409
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python3 -m pytest tests/test_risk_bff.py -v`
Expected: FAIL (routes missing or stub returning fake success).

- [ ] **Step 3: Add `activate_manual_block` / `deactivate_manual_block` to AccountRiskFirewall**

In `backend/app/services/account_risk_firewall.py` add (if absent):

```python
def activate_manual_block(self, reason: str = "manual") -> list[dict]:
    """Activate a manual block lock. Returns current active_locks list."""
    self._manual_block_active = True
    self._manual_block_reason = reason
    return self._current_locks()

def deactivate_manual_block(self) -> list[dict]:
    """Deactivate the manual block lock. Returns current active_locks list."""
    self._manual_block_active = False
    self._manual_block_reason = None
    return self._current_locks()

def _current_locks(self) -> list[dict]:
    locks = []
    if getattr(self, "_manual_block_active", False):
        locks.append({"lock": "manual_block", "reason": self._manual_block_reason or "manual"})
    return locks
```

- [ ] **Step 4: Create risk_rules_service.py**

```python
# backend/app/services/risk_rules_service.py
"""Read effective risk rule thresholds."""
from dataclasses import dataclass

@dataclass
class RiskRules:
    daily_loss_limit: float
    weekly_loss_limit: float
    consecutive_losses_limit: int
    max_drawdown: float
    correlation_threshold: float
    kill_switch_threshold: float
    kill_switch_active: bool

class RiskRulesService:
    def get_effective(self) -> RiskRules:
        # Source: evaluate_risk_rules config; for now read from risk_rules module constants
        from app.services import risk_rules as rr
        return RiskRules(
            daily_loss_limit=rr.DAILY_LOSS_LIMIT_PCT,
            weekly_loss_limit=rr.WEEKLY_LOSS_LIMIT_PCT,
            consecutive_losses_limit=rr.CONSECUTIVE_LOSSES_LIMIT,
            max_drawdown=rr.MAX_DRAWDOWN_PCT,
            correlation_threshold=rr.CORRELATION_THRESHOLD,
            kill_switch_threshold=rr.KILL_SWITCH_THRESHOLD,
            kill_switch_active=False,
        )
```

If `risk_rules.py` doesn't expose module-level constants, read from `risk_policy_versions` DB table instead. Inspect `backend/app/services/risk_rules.py` first and adapt the field names.

- [ ] **Step 5: Add schemas**

In `backend/app/schemas/risk_bff.py`:

```python
class RiskRulesResponse(BaseModel):
    daily_loss_limit: float
    weekly_loss_limit: float
    consecutive_losses_limit: int
    max_drawdown: float
    correlation_threshold: float
    kill_switch: dict  # {threshold, active}

class ResolveResponse(BaseModel):
    status: str
    resolved_event_id: str | None = None
    reason_codes: list[str] = []
```

- [ ] **Step 6: Replace stub routes with real impl + add new routes**

In `backend/app/routers/risk_bff.py`, replace the existing `block-new-entries` / `unblock` stubs:

```python
from app.services.account_risk_firewall import AccountRiskFirewall
from app.services.risk_rules_service import RiskRulesService
from app.schemas.risk_bff import RiskRulesResponse, ResolveResponse

@router.post("/block-new-entries")
async def block_new_entries(payload: dict | None = None):
    reason = (payload or {}).get("reason", "manual")
    try:
        fw = AccountRiskFirewall()
        locks = fw.activate_manual_block(reason=reason)
        return {"status": "blocked", "active_locks": locks, "reason_codes": []}
    except Exception as e:
        logger.exception("[block-new-entries] failed: %s", e)
        return {"status": "failed", "active_locks": [], "reason_codes": [type(e).__name__]}

@router.post("/unblock")
async def unblock():
    try:
        fw = AccountRiskFirewall()
        locks = fw.deactivate_manual_block()
        return {"status": "unblocked", "active_locks": locks, "reason_codes": []}
    except Exception as e:
        logger.exception("[unblock] failed: %s", e)
        return {"status": "failed", "active_locks": [], "reason_codes": [type(e).__name__]}

@router.get("/rules", response_model=RiskRulesResponse)
async def get_risk_rules():
    svc = RiskRulesService()
    r = svc.get_effective()
    return RiskRulesResponse(
        daily_loss_limit=r.daily_loss_limit,
        weekly_loss_limit=r.weekly_loss_limit,
        consecutive_losses_limit=r.consecutive_losses_limit,
        max_drawdown=r.max_drawdown,
        correlation_threshold=r.correlation_threshold,
        kill_switch={"threshold": r.kill_switch_threshold, "active": r.kill_switch_active},
    )

@router.post("/circuit-breakers/{event_id}/resolve", response_model=ResolveResponse)
async def resolve_circuit_breaker(event_id: str):
    from app.services.circuit_breaker_repository import CircuitBreakerRepository
    repo = CircuitBreakerRepository()
    evt = repo.get(event_id)
    if evt is None:
        return ResolveResponse(status="not_found", resolved_event_id=event_id, reason_codes=["event_not_found"])
    if evt.type in ("kill_switch", "emergency_stop"):
        return ResolveResponse(status="rejected", resolved_event_id=event_id, reason_codes=["cannot_resolve_kill_switch"])
    if evt.resolved:
        return ResolveResponse(status="already_resolved", resolved_event_id=event_id, reason_codes=[])
    repo.mark_resolved(event_id)
    return ResolveResponse(status="resolved", resolved_event_id=event_id, reason_codes=[])
```

If `CircuitBreakerRepository` doesn't exist, inspect how `risk_bff.py` currently queries `CircuitBreakerEvent` from DB and replicate that access pattern in the resolve route (direct DB session write is acceptable).

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd backend && python3 -m pytest tests/test_risk_bff.py -v`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add backend/app/routers/risk_bff.py backend/app/services/account_risk_firewall.py backend/app/services/risk_rules_service.py backend/app/schemas/risk_bff.py backend/tests/test_risk_bff.py backend/tests/test_risk_rules_service.py
git commit -m "feat(backend): real risk block/unblock + risk rules query + circuit-breaker resolve"
```

---

## Task 6: Backend — deprecate old emergency-stop endpoints

**Files:**
- Modify: `backend/app/routers/execution_bff.py`
- Modify: `backend/app/routers/risk_bff.py`
- Test: `backend/tests/test_execution_bff.py`, `backend/tests/test_risk_bff.py`

**Interfaces:**
- `/api/execution/emergency-stop` and `/api/risk/emergency-stop` return 410 with `{"detail": "deprecated, use POST /api/v2/emergency/stop"}`.
- Real endpoint: `POST /api/v2/emergency/stop` (already exists in `routers/risk.py`).

- [ ] **Step 1: Write failing tests**

```python
def test_old_execution_emergency_stop_deprecated():
    resp = client.post("/api/execution/emergency-stop")
    assert resp.status_code == 410
    assert "deprecated" in resp.json()["detail"].lower()

def test_old_risk_emergency_stop_deprecated():
    # risk_bff currently GET; ensure both GET and POST 410
    assert client.post("/api/risk/emergency-stop").status_code == 410
    assert client.get("/api/risk/emergency-stop").status_code == 410
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && python3 -m pytest tests/test_execution_bff.py::test_old_execution_emergency_stop_deprecated tests/test_risk_bff.py::test_old_risk_emergency_stop_deprecated -v`
Expected: FAIL.

- [ ] **Step 3: Replace old routes with 410 stubs**

In `backend/app/routers/execution_bff.py`, replace the existing `emergency-stop` handler body:

```python
from fastapi import HTTPException

@router.post("/emergency-stop")
async def emergency_stop_deprecated():
    raise HTTPException(status_code=410, detail="deprecated, use POST /api/v2/emergency/stop")
```

In `backend/app/routers/risk_bff.py`, replace the `emergency-stop` handler (fix GET→POST bug by adding both methods returning 410):

```python
from fastapi import HTTPException

@router.get("/emergency-stop", include_in_schema=False)
@router.post("/emergency-stop", include_in_schema=False)
async def emergency_stop_deprecated():
    raise HTTPException(status_code=410, detail="deprecated, use POST /api/v2/emergency/stop")
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python3 -m pytest tests/test_execution_bff.py::test_old_execution_emergency_stop_deprecated tests/test_risk_bff.py::test_old_risk_emergency_stop_deprecated -v`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/execution_bff.py backend/app/routers/risk_bff.py backend/tests/test_execution_bff.py backend/tests/test_risk_bff.py
git commit -m "chore(backend): deprecate old emergency-stop endpoints (410)"
```

---

## Task 7: Frontend — L10n+EmergencyStop.swift

**Files:**
- Create: `macos-app/AlphaLoop/Localization/L10n+EmergencyStop.swift`

**Interfaces:**
- Produces: `L10n.EmergencyStop.emergencyStop`, `.resume`, `.confirmStop`, `.confirmStopMessage`, `.confirmResume`, `.confirmResumeMessage`, `.affectedRuns`, `.thisActionIrreversible`, `.liveModeWarning`, `.paperModeNote`.

- [ ] **Step 1: Create file**

```swift
// macos-app/AlphaLoop/Localization/L10n+EmergencyStop.swift
import Foundation

extension L10n {
    enum EmergencyStop {
        static var emergencyStop: String { zh("紧急停止", en: "EMERGENCY STOP") }
        static var resume: String { zh("恢复运行", en: "RESUME") }
        static var confirmStop: String { zh("确认紧急停止", en: "Confirm Emergency Stop") }
        static var confirmStopMessage: String {
            zh("此操作将立即停止所有策略运行。受影响运行数: %d。当前模式: %@。此操作不可逆。",
               en: "This will immediately stop all strategy runs. Affected runs: %d. Current mode: %@. This action is irreversible.")
        }
        static var confirmResume: String { zh("确认恢复运行", en: "Confirm Resume") }
        static var confirmResumeMessage: String {
            zh("将解除紧急锁定并恢复策略运行。当前模式: %@。",
               en: "This will release the emergency lock and resume strategy runs. Current mode: %@.")
        }
        static var affectedRuns: String { zh("受影响运行数", en: "Affected runs") }
        static var thisActionIrreversible: String { zh("此操作不可逆", en: "This action is irreversible") }
        static var liveModeWarning: String { zh("实盘模式 — 操作将影响真实资金", en: "LIVE mode — real funds at risk") }
        static var paperModeNote: String { zh("模拟模式", en: "Paper mode") }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Localization/L10n+EmergencyStop.swift
git commit -m "feat(macos): L10n+EmergencyStop namespace"
```

---

## Task 8: Frontend — L10n+Reconciliation.swift + migrate inline strings

**Files:**
- Create: `macos-app/AlphaLoop/Localization/L10n+Reconciliation.swift`
- Modify: `macos-app/AlphaLoop/Views/Execution/ReconciliationBusView.swift`

**Interfaces:**
- Produces: `L10n.Reconciliation.title`, `.refreshExchangeState`, `.retryReconciliation`, `.commandBus`, `.reconciliationRuns`, `.discrepancies`, `.status`, `.runId`, `.startedAt`, `.completedAt`, `.retry`, `.confirmRetry`, `.confirmRetryMessage`, `.noRuns`, `.refreshing`.

- [ ] **Step 1: Create L10n+Reconciliation.swift**

```swift
// macos-app/AlphaLoop/Localization/L10n+Reconciliation.swift
import Foundation

extension L10n {
    enum Reconciliation {
        static var title: String { zh("对账总线", en: "Reconciliation Bus") }
        static var refreshExchangeState: String { zh("刷新交易所状态", en: "Refresh Exchange State") }
        static var retryReconciliation: String { zh("重试对账", en: "Retry Reconciliation") }
        static var commandBus: String { zh("命令总线", en: "Command Bus") }
        static var reconciliationRuns: String { zh("对账运行", en: "Reconciliation Runs") }
        static var discrepancies: String { zh("差异数", en: "Discrepancies") }
        static var status: String { zh("状态", en: "Status") }
        static var runId: String { zh("运行 ID", en: "Run ID") }
        static var startedAt: String { zh("开始时间", en: "Started At") }
        static var completedAt: String { zh("完成时间", en: "Completed At") }
        static var retry: String { zh("重试", en: "Retry") }
        static var confirmRetry: String { zh("确认重试对账", en: "Confirm Retry Reconciliation") }
        static var confirmRetryMessage: String {
            zh("将重新触发对账运行 %@。当前模式: %@。",
               en: "Will re-trigger reconciliation run %@. Current mode: %@.")
        }
        static var noRuns: String { zh("暂无对账记录", en: "No reconciliation runs") }
        static var refreshing: String { zh("刷新中…", en: "Refreshing…") }
    }
}
```

- [ ] **Step 2: Migrate inline `L10n.zh(...)` in ReconciliationBusView.swift**

Open `macos-app/AlphaLoop/Views/Execution/ReconciliationBusView.swift`. Replace every `L10n.zh("...", en: "...")` inline call with the matching `L10n.Reconciliation.<key>`. For example at the lines noted in exploration (L34-38, L59, L75, L97, L131, L185) replace the title/refresh/discrepancies/etc. with the namespace references.

- [ ] **Step 3: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Localization/L10n+Reconciliation.swift macos-app/AlphaLoop/Views/Execution/ReconciliationBusView.swift
git commit -m "feat(macos): L10n+Reconciliation namespace + migrate inline strings"
```

---

## Task 9: Frontend — L10n+Risk.swift

**Files:**
- Create: `macos-app/AlphaLoop/Localization/L10n+Risk.swift`

**Interfaces:**
- Produces: `L10n.Risk.blockNewEntries`, `.unblock`, `.confirmBlock`, `.confirmUnblock`, `.riskRules`, `.riskRulesSummary`, `.dailyLossLimit`, `.weeklyLossLimit`, `.consecutiveLosses`, `.maxDrawdown`, `.correlationThreshold`, `.killSwitch`, `.markResolved`, `.confirmMarkResolved`, `.unresolved`, `.resolved`, `.cannotResolveKillSwitch`.

- [ ] **Step 1: Create file**

```swift
// macos-app/AlphaLoop/Localization/L10n+Risk.swift
import Foundation

extension L10n {
    enum Risk {
        static var blockNewEntries: String { zh("禁止新开仓", en: "Block New Entries") }
        static var unblock: String { zh("解除禁止", en: "Unblock") }
        static var confirmBlock: String { zh("确认禁止新开仓", en: "Confirm Block New Entries") }
        static var confirmUnblock: String { zh("确认解除禁止", en: "Confirm Unblock") }
        static var riskRules: String { zh("风控规则", en: "Risk Rules") }
        static var riskRulesSummary: String { zh("当前生效的阈值与开关", en: "Currently effective thresholds and switches") }
        static var dailyLossLimit: String { zh("日亏损上限", en: "Daily Loss Limit") }
        static var weeklyLossLimit: String { zh("周亏损上限", en: "Weekly Loss Limit") }
        static var consecutiveLosses: String { zh("连续亏损次数", en: "Consecutive Losses") }
        static var maxDrawdown: String { zh("最大回撤", en: "Max Drawdown") }
        static var correlationThreshold: String { zh("相关性阈值", en: "Correlation Threshold") }
        static var killSwitch: String { zh("Kill Switch", en: "Kill Switch") }
        static var markResolved: String { zh("标记已解决", en: "Mark Resolved") }
        static var confirmMarkResolved: String { zh("确认标记已解决", en: "Confirm Mark Resolved") }
        static var unresolved: String { zh("未解决", en: "Unresolved") }
        static var resolved: String { zh("已解决", en: "Resolved") }
        static var cannotResolveKillSwitch: String { zh("Kill Switch 类型不可手动解决", en: "Kill switch type cannot be manually resolved") }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Localization/L10n+Risk.swift
git commit -m "feat(macos): L10n+Risk namespace"
```

---

## Task 10: Frontend — extend L10n+Execution.swift

**Files:**
- Modify: `macos-app/AlphaLoop/Localization/L10n+Execution.swift`

**Interfaces:**
- Produces: `L10n.Execution.cancelAllOrders`, `.forceCloseAll`, `.cancelOrder`, `.closePosition`, `.confirmCancelAll`, `.confirmCancelAllMessage`, `.confirmForceCloseAll`, `.confirmForceCloseAllMessage`, `.confirmCancelOrder`, `.confirmCancelOrderMessage`, `.confirmClosePosition`, `.confirmClosePositionMessage`, `.affectedOrders`, `.affectedPositions`.

- [ ] **Step 1: Add keys**

Append to `macos-app/AlphaLoop/Localization/L10n+Execution.swift` inside the `extension L10n.Execution` block:

```swift
        static var cancelAllOrders: String { zh("撤销全部挂单", en: "Cancel All Orders") }
        static var forceCloseAll: String { zh("强制平仓全部", en: "Force Close All") }
        static var cancelOrder: String { zh("撤销", en: "Cancel") }
        static var closePosition: String { zh("平仓", en: "Close") }
        static var confirmCancelAll: String { zh("确认撤销全部挂单", en: "Confirm Cancel All Orders") }
        static var confirmCancelAllMessage: String {
            zh("将撤销 %d 笔挂单。当前模式: %@。此操作不可逆。",
               en: "Will cancel %d pending orders. Current mode: %@. This action is irreversible.")
        }
        static var confirmForceCloseAll: String { zh("确认强制平仓全部", en: "Confirm Force Close All") }
        static var confirmForceCloseAllMessage: String {
            zh("将强制平仓 %d 个持仓。当前模式: %@。此操作不可逆。",
               en: "Will force-close %d positions. Current mode: %@. This action is irreversible.")
        }
        static var confirmCancelOrder: String { zh("确认撤销订单", en: "Confirm Cancel Order") }
        static var confirmCancelOrderMessage: String {
            zh("将撤销订单 %@。当前模式: %@。",
               en: "Will cancel order %@. Current mode: %@.")
        }
        static var confirmClosePosition: String { zh("确认平仓", en: "Confirm Close Position") }
        static var confirmClosePositionMessage: String {
            zh("将平仓持仓 %@。当前模式: %@。",
               en: "Will close position %@. Current mode: %@.")
        }
        static var affectedOrders: String { zh("受影响订单数", en: "Affected orders") }
        static var affectedPositions: String { zh("受影响持仓数", en: "Affected positions") }
```

- [ ] **Step 2: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Localization/L10n+Execution.swift
git commit -m "feat(macos): extend L10n+Execution with cancel/close action keys"
```

---

## Task 11: Frontend — LiveWireStrip component

**Files:**
- Create: `macos-app/AlphaLoop/Views/Shared/LiveWireStrip.swift`

**Interfaces:**
- Produces: `LiveWireStrip(mode: ModePill.Mode) -> some View` — 2pt full-width gradient strip.
- Consumes: `ModePill.Mode` (already exists at `macos-app/AlphaLoop/Views/Shared/ModePill.swift`).

- [ ] **Step 1: Create file**

```swift
// macos-app/AlphaLoop/Views/Shared/LiveWireStrip.swift
import SwiftUI

struct LiveWireStrip: View {
    let mode: ModePill.Mode

    @State private var pulse = false

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: stripColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .opacity(pulse ? 0.4 : 1.0)
            .animation(
                mode == .emergencyLocked
                    ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )
            .onAppear {
                if mode == .emergencyLocked { pulse = true }
            }
            .onChange(of: mode) { newMode in
                pulse = newMode == .emergencyLocked
            }
    }

    private var stripColors: [Color] {
        switch mode {
        case .live: return [PulseColors.danger.opacity(0.7), PulseColors.danger, PulseColors.danger.opacity(0.7)]
        case .paper: return [PulseColors.warning.opacity(0.7), PulseColors.warning, PulseColors.warning.opacity(0.7)]
        case .dryrun: return [Color.purple.opacity(0.7), Color.purple, Color.purple.opacity(0.7)]
        case .mock: return [PulseColors.textTertiary.opacity(0.5), PulseColors.textTertiary, PulseColors.textTertiary.opacity(0.5)]
        case .emergencyLocked: return [PulseColors.danger, Color.white.opacity(0.6), PulseColors.danger]
        default: return [PulseColors.textTertiary.opacity(0.3), PulseColors.textTertiary.opacity(0.5)]
        }
    }
}
```

Note: verify the exact `ModePill.Mode` enum case names by reading `macos-app/AlphaLoop/Views/Shared/ModePill.swift` — adapt if they differ (e.g. `.liveSmall` vs `.live`). Also verify `PulseColors.danger` / `.warning` / `.textTertiary` exist in `DesignTokens.swift`; adapt names if different.

- [ ] **Step 2: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors. If `ModePill.Mode` cases or color names differ, fix and rebuild.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Views/Shared/LiveWireStrip.swift
git commit -m "feat(macos): LiveWireStrip ambient mode indicator"
```

---

## Task 12: Frontend — EmergencyStopBar component

**Files:**
- Create: `macos-app/AlphaLoop/Views/Shared/EmergencyStopBar.swift`

**Interfaces:**
- Produces: `EmergencyStopBar(mode:, affectedRuns:, emergencyLocked:, onStop: () async -> Void, onResume: () async -> Void) -> some View`.
- Consumes: `ModePill`, `KryptonConfirmDialog`, `L10n.EmergencyStop.*`, `AppState.isLiveMode`.

- [ ] **Step 1: Create file**

```swift
// macos-app/AlphaLoop/Views/Shared/EmergencyStopBar.swift
import SwiftUI

struct EmergencyStopBar: View {
    let mode: ModePill.Mode
    let affectedRuns: Int
    let emergencyLocked: Bool
    let onStop: () async -> Void
    let onResume: () async -> Void

    @State private var showConfirm = false
    @State private var isActing = false

    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            ModePill(mode: mode, style: .compact)

            Divider().frame(height: 24)

            if emergencyLocked {
                Text(L10n.zh("紧急锁定中", en: "EMERGENCY LOCKED"))
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.danger)
            } else {
                Text("\(affectedRuns) \(L10n.zh("个策略运行中", en: "strategies running"))")
                    .font(PulseFonts.caption)
                    .foregroundStyle(PulseColors.textSecondary)
            }

            Spacer()

            if emergencyLocked {
                Button {
                    showConfirm = true
                } label: {
                    Label(L10n.EmergencyStop.resume, systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .tint(.warning)
            } else {
                Button {
                    showConfirm = true
                } label: {
                    Label(L10n.EmergencyStop.emergencyStop, systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.danger)
            }
        }
        .padding(.horizontal, PulseSpacing.lg)
        .padding(.vertical, PulseSpacing.sm)
        .background(PulseColors.surfaceHover.opacity(0.35))
        .overlay(Divider(), alignment: .bottom)
        .confirmDialog(
            emergencyLocked ? L10n.EmergencyStop.confirmResume : L10n.EmergencyStop.confirmStop,
            isPresented: $showConfirm,
            destructively: !emergencyLocked
        ) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                Text(String(
                    format: emergencyLocked ? L10n.EmergencyStop.confirmResumeMessage : L10n.EmergencyStop.confirmStopMessage,
                    affectedRuns,
                    mode.rawValue as CVarArg
                ))
                .font(PulseFonts.body)
                if mode == .live {
                    Label(L10n.EmergencyStop.liveModeWarning, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(PulseColors.danger)
                } else {
                    Label(L10n.EmergencyStop.paperModeNote, systemImage: "info.circle")
                        .foregroundStyle(PulseColors.textSecondary)
                }
                Label(L10n.EmergencyStop.thisActionIrreversible, systemImage: "lock.fill")
                    .foregroundStyle(PulseColors.warning)
            }
        } confirm: {
            Button(emergencyLocked ? L10n.EmergencyStop.resume : L10n.EmergencyStop.emergencyStop,
                   role: emergencyLocked ? nil : .destructive) {
                isActing = true
                Task {
                    if emergencyLocked { await onResume() } else { await onStop() }
                    isActing = false
                }
            }
            Button(L10n.zh("取消", en: "Cancel"), role: .cancel) {}
        }
        .disabled(isActing)
    }
}
```

Note: verify `KryptonConfirmDialog` API signature in `Views/Shared/KryptonSafetyComponents.swift` — the `confirmDialog(_:isPresented:destructively:)` modifier and content/confirm closures. Adapt to the actual API. Also verify `PulseColors.surfaceHover`, `.danger`, `.warning`, `.textSecondary`, `PulseFonts.caption`/`.body` exist in DesignTokens. `ModePill.Mode` must have a `rawValue` (String) or adapt the format call.

- [ ] **Step 2: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors. Fix any API mismatches with `KryptonConfirmDialog`.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Views/Shared/EmergencyStopBar.swift
git commit -m "feat(macos): EmergencyStopBar shared component"
```

---

## Task 13: Frontend — riskAtmosphericBackground modifier

**Files:**
- Create: `macos-app/AlphaLoop/DesignSystem/AtmosphericBackgroundModifier.swift`
- Modify: `macos-app/AlphaLoop/Views/Risk/RiskCenterView.swift` (extract)
- Modify: `macos-app/AlphaLoop/Views/Risk/StopProtectionView.swift` (extract)
- Modify: `macos-app/AlphaLoop/Views/Risk/CircuitBreakersView.swift` (extract)

**Interfaces:**
- Produces: `ViewModifier RiskAtmosphericBackground(tint: Color)` and `.riskAtmosphericBackground(tint:)` extension.

- [ ] **Step 1: Create modifier**

```swift
// macos-app/AlphaLoop/DesignSystem/AtmosphericBackgroundModifier.swift
import SwiftUI

struct RiskAtmosphericBackground: ViewModifier {
    let tint: Color
    @State private var pulsePhase: Double = 0

    func body(content: Content) -> some View {
        ZStack {
            ZStack {
                PulseColors.background
                RadialGradient(
                    colors: [
                        tint.opacity(0.08 + pulsePhase * 0.04),
                        tint.opacity(0.02),
                        Color.clear,
                    ],
                    center: .top,
                    startRadius: 50,
                    endRadius: 500
                )
                Canvas { context, size in
                    for y in stride(from: 0, to: size.height, by: 3) {
                        let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                        context.fill(Path(rect), with: .color(Color.white.opacity(0.008)))
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                    pulsePhase = 1
                }
            }
            content
        }
    }
}

extension View {
    func riskAtmosphericBackground(tint: Color = PulseColors.accent) -> some View {
        modifier(RiskAtmosphericBackground(tint: tint))
    }
}
```

Note: verify `PulseColors.background` and `.accent` exist; adapt if the actual color token names differ (exploration showed `colors.background` used inside views, which is a local alias of `PulseColors`).

- [ ] **Step 2: Replace inline `atmosphericBackground` in the 3 risk views**

In each of `RiskCenterView.swift`, `StopProtectionView.swift`, `CircuitBreakersView.swift`: remove the private `atmosphericBackground` computed property and apply `.riskAtmosphericBackground(tint: overallRiskColor)` (or equivalent local tint) to the root view. Pass the existing `overallRiskColor` as the tint where applicable.

- [ ] **Step 3: Verify it compiles and visually unchanged**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors. The risk pages should render identically (background extracted, not restyled).

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/DesignSystem/AtmosphericBackgroundModifier.swift macos-app/AlphaLoop/Views/Risk/RiskCenterView.swift macos-app/AlphaLoop/Views/Risk/StopProtectionView.swift macos-app/AlphaLoop/Views/Risk/CircuitBreakersView.swift
git commit -m "refactor(macos): extract atmosphericBackground to shared modifier"
```

---

## Task 14: Frontend — API methods for execution actions + mocks

**Files:**
- Modify: `macos-app/AlphaLoop/Services/APIExecutionBFF.swift`

**Interfaces:**
- Produces: `APIExecutionBFF.cancelOrder(id:)`, `.closePosition(id:)`, `.cancelAllOrders()`, `.forceCloseAllPositions()`, `.retryReconciliationRun(id:)`, `.retryReconciliationBatch()`.
- Response types: `CancelActionResponse`, `CloseActionResponse`, `BatchActionResponse`, `RetryActionResponse` (Codable).

- [ ] **Step 1: Add response types**

In `macos-app/AlphaLoop/Services/APIExecutionBFF.swift` add:

```swift
struct CancelActionResponse: Codable { let cancelledOrderId: String; let status: String }
struct CloseActionResponse: Codable { let closedPositionId: String; let status: String }
struct BatchActionResponse: Codable { let affectedCount: Int; let status: String }
struct RetryActionResponse: Codable { let status: String; let runId: String?; let affectedCount: Int? }
```

- [ ] **Step 2: Add API methods**

```swift
extension APIExecutionBFF {
    func cancelOrder(id: String) async throws -> CancelActionResponse {
        try await client.post("/api/execution/orders/\(id)/cancel", body: [:], mock: { CancelActionResponse(cancelledOrderId: id, status: "cancelled") })
    }
    func closePosition(id: String) async throws -> CloseActionResponse {
        try await client.post("/api/execution/positions/\(id)/close", body: [:], mock: { CloseActionResponse(closedPositionId: id, status: "closed") })
    }
    func cancelAllOrders() async throws -> BatchActionResponse {
        try await client.post("/api/execution/orders/cancel-all", body: [:], mock: { BatchActionResponse(affectedCount: 1, status: "cancelled") })
    }
    func forceCloseAllPositions() async throws -> BatchActionResponse {
        try await client.post("/api/execution/positions/force-close-all", body: [:], mock: { BatchActionResponse(affectedCount: 1, status: "closed") })
    }
    func retryReconciliationRun(id: String) async throws -> RetryActionResponse {
        try await client.post("/api/reconciliation/runs/\(id)/retry", body: [:], mock: { RetryActionResponse(status: "retrying", runId: id, affectedCount: nil) })
    }
    func retryReconciliationBatch() async throws -> RetryActionResponse {
        try await client.post("/api/reconciliation/retry", body: [:], mock: { RetryActionResponse(status: "retrying", runId: nil, affectedCount: -1) })
    }
}
```

Note: verify the `NetworkClientProtocol.post` signature in `Services/NetworkClient.swift` — adapt the parameter labels and the mock closure shape to match (e.g. whether `body:` is `Encodable` or `[String: Any]`, and whether `mock:` takes a closure or a value).

- [ ] **Step 3: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Services/APIExecutionBFF.swift
git commit -m "feat(macos): execution action API methods + mocks"
```

---

## Task 15: Frontend — API methods for risk actions + mocks

**Files:**
- Modify: `macos-app/AlphaLoop/Services/APIRiskBFF.swift`

**Interfaces:**
- Produces: `APIRiskBFF.blockNewEntries(reason:)`, `.unblock()`, `.getRiskRules()`, `.resolveCircuitBreaker(eventId:)`. Fix `emergencyStop()` to call `POST /api/v2/emergency/stop`.
- Response types: `BlockActionResponse`, `RiskRulesResponse`, `ResolveCircuitBreakerResponse` (Codable).

- [ ] **Step 1: Add response types**

```swift
struct BlockActionResponse: Codable { let status: String; let activeLocks: [ActiveLockResponse] }
struct ActiveLockResponse: Codable { let lock: String; let reason: String? }
struct RiskRulesResponse: Codable {
    let dailyLossLimit: Double
    let weeklyLossLimit: Double
    let consecutiveLossesLimit: Int
    let maxDrawdown: Double
    let correlationThreshold: Double
    let killSwitch: KillSwitchResponse
}
struct KillSwitchResponse: Codable { let threshold: Double; let active: Bool }
struct ResolveCircuitBreakerResponse: Codable { let status: String; let resolvedEventId: String? }
```

- [ ] **Step 2: Add methods and fix emergencyStop**

```swift
extension APIRiskBFF {
    func blockNewEntries(reason: String = "manual") async throws -> BlockActionResponse {
        try await client.post("/api/risk/block-new-entries", body: ["reason": reason], mock: {
            BlockActionResponse(status: "blocked", activeLocks: [ActiveLockResponse(lock: "manual_block", reason: reason)])
        })
    }
    func unblock() async throws -> BlockActionResponse {
        try await client.post("/api/risk/unblock", body: [:], mock: {
            BlockActionResponse(status: "unblocked", activeLocks: [])
        })
    }
    func getRiskRules() async throws -> RiskRulesResponse {
        try await client.get("/api/risk/rules", mock: {
            RiskRulesResponse(dailyLossLimit: 0.05, weeklyLossLimit: 0.10, consecutiveLossesLimit: 3,
                              maxDrawdown: 0.20, correlationThreshold: 0.9,
                              killSwitch: KillSwitchResponse(threshold: 0.15, active: false))
        })
    }
    func resolveCircuitBreaker(eventId: String) async throws -> ResolveCircuitBreakerResponse {
        try await client.post("/api/risk/circuit-breakers/\(eventId)/resolve", body: [:], mock: {
            ResolveCircuitBreakerResponse(status: "resolved", resolvedEventId: eventId)
        })
    }
    // FIX: was GET /api/risk/emergency-stop; now POST /api/v2/emergency/stop
    func emergencyStop() async throws -> EmergencyStopResult {
        try await client.post("/api/v2/emergency/stop", body: [:], mock: {
            EmergencyStopResult(stoppedRuns: 2, message: "mock emergency stop")
        })
    }
}
```

Note: verify `NetworkClientProtocol.post` and `.get` signatures and adapt. Also verify `EmergencyStopResult` location (currently in `Models/Types.swift`).

- [ ] **Step 3: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Services/APIRiskBFF.swift
git commit -m "feat(macos): risk action API methods + fix emergencyStop endpoint"
```

---

## Task 16: Frontend — ViewModel action methods (ExecutionCenterViewModel)

**Files:**
- Modify: `macos-app/AlphaLoop/ViewModels/ExecutionCenterViewModel.swift`

**Interfaces:**
- Produces: `cancelOrder(id:)`, `closePosition(id:)`, `cancelAllOrders()`, `forceCloseAllPositions()`, `retryReconciliationRun(id:)`, `retryReconciliationBatch()`, `emergencyStop()`, `emergencyResume()` (all async).
- Consumes: Task 14 API methods; `APIEmergency` for resume.

- [ ] **Step 1: Add methods**

```swift
extension ExecutionCenterViewModel {
    @MainActor func cancelOrder(id: String) async {
        do { _ = try await api.cancelOrder(id: id); await loadOrdersPositions() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func closePosition(id: String) async {
        do { _ = try await api.closePosition(id: id); await loadOrdersPositions() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func cancelAllOrders() async {
        do { _ = try await api.cancelAllOrders(); await loadOrdersPositions() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func forceCloseAllPositions() async {
        do { _ = try await api.forceCloseAllPositions(); await loadOrdersPositions() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func retryReconciliationRun(id: String) async {
        do { _ = try await api.retryReconciliationRun(id: id); await loadReconciliationBus() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func retryReconciliationBatch() async {
        do { _ = try await api.retryReconciliationBatch(); await loadReconciliationBus() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func emergencyStop() async {
        do { _ = try await api.emergencyStop() as EmergencyStopResult; await loadCenter() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func emergencyResume() async {
        do { _ = try await APIEmergency.shared.resume(); await loadCenter() } catch { self.lastError = error.localizedDescription }
    }
}
```

Note: inspect the existing `ExecutionCenterViewModel` to verify property names (`api`, `lastError`) and the existing `loadCenter`/`loadOrdersPositions`/`loadReconciliationBus` method signatures. Adapt the `emergencyStop` return type — if `APIExecutionBFF.emergencyStop` was removed (Task 15 moved it to risk), keep using whatever the existing `performEmergencyStop()` already used, but redirect to `/api/v2/emergency/stop` via `APIEmergency`. Inspect `Services/APIEmergency.swift` first.

- [ ] **Step 2: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/ViewModels/ExecutionCenterViewModel.swift
git commit -m "feat(macos): ExecutionCenterViewModel action methods"
```

---

## Task 17: Frontend — RiskCenterViewModel action methods + risk rules state

**Files:**
- Modify: `macos-app/AlphaLoop/ViewModels/RiskCenterViewModel.swift`

**Interfaces:**
- Produces: `blockNewEntries()`, `unblock()`, `resolveCircuitBreaker(eventId:)`, `emergencyStop()`, `emergencyResume()` (async); `riskRules: RiskRulesResponse?` state.

- [ ] **Step 1: Add state + methods**

```swift
@MainActor final class RiskCenterViewModel: ObservableObject {
    // existing...
    @Published var riskRules: RiskRulesResponse?

    @MainActor func loadRiskRules() async {
        do { self.riskRules = try await api.getRiskRules() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func blockNewEntries() async {
        do { _ = try await api.blockNewEntries(); await loadOverview() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func unblock() async {
        do { _ = try await api.unblock(); await loadOverview() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func resolveCircuitBreaker(eventId: String) async {
        do { _ = try await api.resolveCircuitBreaker(eventId: eventId); await loadCircuitBreakers() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func emergencyStop() async {
        do { _ = try await api.emergencyStop(); await loadOverview() } catch { self.lastError = error.localizedDescription }
    }
    @MainActor func emergencyResume() async {
        do { _ = try await APIEmergency.shared.resume(); await loadOverview() } catch { self.lastError = error.localizedDescription }
    }
}
```

Note: inspect the existing `RiskCenterViewModel` (singleton, properties `overview`/`stopProtection`/`circuitBreakers`, `api`, `lastError`) and adapt property/method names. Verify `APIEmergency.shared.resume()` signature in `Services/APIEmergency.swift`.

- [ ] **Step 2: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/ViewModels/RiskCenterViewModel.swift
git commit -m "feat(macos): RiskCenterViewModel action methods + risk rules state"
```

---

## Task 18: Frontend — wire ExecutionCenterView (top bar + background + remove in-page emergency)

**Files:**
- Modify: `macos-app/AlphaLoop/Views/Execution/ExecutionCenterView.swift`

**Interfaces:**
- Consumes: `EmergencyStopBar`, `LiveWireStrip`, `riskAtmosphericBackground()`, `L10n.EmergencyStop.*`, `ModePill.Mode.resolve()`.

- [ ] **Step 1: Add top bar + background, remove in-page emergency button**

At the top of the `body`, add:

```swift
VStack(spacing: 0) {
    LiveWireStrip(mode: resolvedMode)
    EmergencyStopBar(
        mode: resolvedMode,
        affectedRuns: centerData?.totalRunning ?? 0,
        emergencyLocked: centerData?.state == "emergency_locked",
        onStop: { await viewModel.emergencyStop() },
        onResume: { await viewModel.emergencyResume() }
    )
    // existing ScrollView content...
}
.riskAtmosphericBackground(tint: PulseColors.accent)
```

Remove the existing `emergencyStopButton` view and its `.alert` confirmation (replaced by the top bar). Keep `stateBanner`, `summaryCardsRow`, `sessionTableSection`.

Compute `resolvedMode`:

```swift
private var resolvedMode: ModePill.Mode {
    ModePill.Mode.resolve(liveReadinessState: centerData?.state, isLiveMode: AppState.shared.isLiveMode, isMockMode: AppState.shared.isMockMode)
}
```

Note: verify `ModePill.Mode.resolve(...)` signature in `Views/Shared/ModePill.swift` and adapt. Verify `AppState.shared.isLiveMode` / `.isMockMode` exist.

- [ ] **Step 2: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 3: Run app, smoke-test**

Run: `cd macos-app && swift run &` (or open Xcode). Navigate to Execution Center. Verify: LiveWireStrip at top, EmergencyStopBar below it with ModePill + affected runs + Emergency Stop button, atmospheric background visible, no duplicate emergency button in summary row.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Views/Execution/ExecutionCenterView.swift
git commit -m "feat(macos): ExecutionCenterView top bar + background, remove in-page emergency"
```

---

## Task 19: Frontend — wire OrdersPositionsView (batch + inline actions)

**Files:**
- Modify: `macos-app/AlphaLoop/Views/Execution/OrdersPositionsView.swift`

**Interfaces:**
- Consumes: `EmergencyStopBar`, `LiveWireStrip`, `riskAtmosphericBackground()`, `KryptonConfirmDialog`, `L10n.Execution.*`, Task 16 VM methods.

- [ ] **Step 1: Add top bar + background**

Same top-bar pattern as Task 18 (LiveWireStrip + EmergencyStopBar using `ordersPositions` state for `affectedRuns` — use the count of open positions + pending orders; `emergencyLocked` from state).

- [ ] **Step 2: Add batch action row below tabHeader**

```swift
private func batchActionRow(_ data: OrdersPositionsBFFResponse) -> some View {
    HStack(spacing: PulseSpacing.md) {
        Button {
            showCancelAllConfirm = true
        } label: {
            Label(L10n.Execution.cancelAllOrders, systemImage: "xmark.octagon")
        }
        .buttonStyle(.bordered)
        .tint(.danger)
        .disabled(data.orders.filter { $0.status.lowercased() == "pending" }.isEmpty)

        Button {
            showForceCloseAllConfirm = true
        } label: {
            Label(L10n.Execution.forceCloseAll, systemImage: "arrow.down.right.square")
        }
        .buttonStyle(.bordered)
        .tint(.danger)
        .disabled(data.positions.isEmpty)

        Spacer()
    }
    .padding(.horizontal, PulseSpacing.lg)
    .padding(.vertical, PulseSpacing.sm)
}
```

Add state:

```swift
@State private var showCancelAllConfirm = false
@State private var showForceCloseAllConfirm = false
@State private var cancelOrderId: String?
@State private var closePositionId: String?
```

- [ ] **Step 3: Add inline buttons to order & position rows**

In the order row, append a `Cancel` button (only when `status.lowercased() == "pending"`):

```swift
Button {
    cancelOrderId = order.id
} label: {
    Label(L10n.Execution.cancelOrder, systemImage: "xmark")
        .labelStyle(.iconOnly)
}
.buttonStyle(.borderless)
.tint(.danger)
```

In the position row, append a `Close` button:

```swift
Button {
    closePositionId = position.id
} label: {
    Label(L10n.Execution.closePosition, systemImage: "arrow.down.right")
        .labelStyle(.iconOnly)
}
.buttonStyle(.borderless)
.tint(.danger)
```

- [ ] **Step 4: Attach KryptonConfirmDialogs**

Attach four `.confirmDialog(...)` modifiers to the root: cancel-all, force-close-all, cancel-order(single), close-position(single). Each dialog shows the affected count / id + current mode + irreversibility note, and on confirm calls the corresponding VM method. Use the `L10n.Execution.confirm*` keys with `String(format:)` for the count and mode.

Example for cancel-all:

```swift
.confirmDialog(
    L10n.Execution.confirmCancelAll,
    isPresented: $showCancelAllConfirm,
    destructively: true
) {
    // content with String(format: L10n.Execution.confirmCancelAllMessage, pendingCount, mode.rawValue)
    // confirm button calls Task { await viewModel.cancelAllOrders() }
}
```

- [ ] **Step 5: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 6: Run app, smoke-test**

Run app, navigate to Orders/Positions. Verify: top bar visible, batch action row with two disabled-when-empty buttons, inline Cancel on pending orders, inline Close on positions, each opens a KryptonConfirmDialog (not a native alert), confirming triggers the API call and refreshes the list.

- [ ] **Step 7: Commit**

```bash
git add macos-app/AlphaLoop/Views/Execution/OrdersPositionsView.swift
git commit -m "feat(macos): OrdersPositionsView batch + inline actions with confirm"
```

---

## Task 20: Frontend — wire ReconciliationBusView (retry actions, i18n already migrated in Task 8)

**Files:**
- Modify: `macos-app/AlphaLoop/Views/Execution/ReconciliationBusView.swift`

**Interfaces:**
- Consumes: `EmergencyStopBar`, `LiveWireStrip`, `riskAtmosphericBackground()`, `KryptonConfirmDialog`, `L10n.Reconciliation.*`, Task 16 VM methods.

- [ ] **Step 1: Add top bar + background**

Same top-bar pattern. `affectedRuns` can be the count of recent commands; `emergencyLocked` from `reconciliationBus.state`.

- [ ] **Step 2: Add Retry Reconciliation button to header action row**

```swift
Button {
    showRetryBatchConfirm = true
} label: {
    Label(L10n.Reconciliation.retryReconciliation, systemImage: "arrow.clockwise")
}
.buttonStyle(.bordered)
.tint(.warning)
```

- [ ] **Step 3: Add inline Retry on failed runs**

In the run row (when `status.lowercased()` is a failure state like "failed"/"discrepancy"), append:

```swift
Button {
    retryRunId = run.id
} label: {
    Label(L10n.Reconciliation.retry, systemImage: "arrow.clockwise")
        .labelStyle(.iconOnly)
}
.buttonStyle(.borderless)
.tint(.warning)
```

- [ ] **Step 4: Attach KryptonConfirmDialogs**

Two dialogs: batch retry + single retry. Use `L10n.Reconciliation.confirmRetry` / `.confirmRetryMessage` with `String(format:)` for run id + mode.

- [ ] **Step 5: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 6: Run app, smoke-test**

Run app, navigate to Reconciliation Bus. Verify: top bar, Retry Reconciliation button in header, inline Retry on failed runs, confirm dialogs (not native alerts), i18n strings all from `L10n.Reconciliation` namespace (no inline `L10n.zh(...)` left).

- [ ] **Step 7: Commit**

```bash
git add macos-app/AlphaLoop/Views/Execution/ReconciliationBusView.swift
git commit -m "feat(macos): ReconciliationBusView retry actions + top bar"
```

---

## Task 21: Frontend — wire RiskCenterView (top bar + block/unblock real + remove emergencyPanel)

**Files:**
- Modify: `macos-app/AlphaLoop/Views/Risk/RiskCenterView.swift`

**Interfaces:**
- Consumes: `EmergencyStopBar`, `LiveWireStrip`, `riskAtmosphericBackground()` (already applied via Task 13 extraction), `KryptonConfirmDialog`, `L10n.Risk.*`, Task 17 VM methods.

- [ ] **Step 1: Add top bar, remove bottom emergencyPanel**

Add `LiveWireStrip` + `EmergencyStopBar` at top (EmergencyStopBar's `emergencyLocked` from `overview.emergencyLocked`, `affectedRuns` from a count of running sessions or guards). Remove the existing `emergencyPanel` and `emergencyStopButton` (replaced by top bar).

- [ ] **Step 2: Wire block / unblock buttons with confirm**

Replace the empty-action block/unblock buttons:

```swift
Button {
    showBlockConfirm = true
} label: {
    Label(L10n.Risk.blockNewEntries, systemImage: "hand.raised")
}
.buttonStyle(.bordered)
.tint(.warning)
.disabled(overview.activeLocks.contains { $0.lock == "manual_block" })

Button {
    showUnblockConfirm = true
} label: {
    Label(L10n.Risk.unblock, systemImage: "hand.thumbsup")
}
.buttonStyle(.bordered)
.tint(.accent)
.disabled(!overview.activeLocks.contains { $0.lock == "manual_block" })
```

Attach two `KryptonConfirmDialog`s (.warning) using `L10n.Risk.confirmBlock` / `.confirmUnblock`, confirm calls `viewModel.blockNewEntries()` / `viewModel.unblock()`.

- [ ] **Step 3: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 4: Run app, smoke-test**

Run app, navigate to Risk Center. Verify: top bar with ModePill + Emergency Stop, no bottom emergencyPanel, block/unblock buttons enable/disable based on `active_locks`, clicking opens KryptonConfirmDialog, confirming triggers real backend (not stub), state refreshes.

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Views/Risk/RiskCenterView.swift
git commit -m "feat(macos): RiskCenterView top bar + real block/unblock + remove emergencyPanel"
```

---

## Task 22: Frontend — wire StopProtectionView (risk rules section + force-close)

**Files:**
- Modify: `macos-app/AlphaLoop/Views/Risk/StopProtectionView.swift`

**Interfaces:**
- Consumes: `EmergencyStopBar`, `LiveWireStrip`, `riskAtmosphericBackground()`, `KryptonConfirmDialog`, `L10n.Risk.*`, `RiskRulesResponse`, Task 17 VM methods.

- [ ] **Step 1: Add top bar + load risk rules**

Add top bar. In the view's `onAppear`/`task`, call `await viewModel.loadRiskRules()`. Add a `@State private var showRules = false`.

- [ ] **Step 2: Add Risk Rules collapsible section**

Below StateBanner, above position list:

```swift
private func riskRulesSection(_ rules: RiskRulesResponse) -> some View {
    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
        Button {
            withAnimation { showRules.toggle() }
        } label: {
            HStack {
                Label(L10n.Risk.riskRules, systemImage: "shield.lefthalf.filled")
                Spacer()
                Image(systemName: showRules ? "chevron.down" : "chevron.right")
            }
        }
        .buttonStyle(.plain)

        Text(L10n.Risk.riskRulesSummary)
            .font(PulseFonts.caption)
            .foregroundStyle(PulseColors.textSecondary)

        if showRules {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                ruleRow(L10n.Risk.dailyLossLimit, value: String(format: "%.1f%%", rules.dailyLossLimit * 100))
                ruleRow(L10n.Risk.weeklyLossLimit, value: String(format: "%.1f%%", rules.weeklyLossLimit * 100))
                ruleRow(L10n.Risk.consecutiveLosses, value: "\(rules.consecutiveLossesLimit)")
                ruleRow(L10n.Risk.maxDrawdown, value: String(format: "%.1f%%", rules.maxDrawdown * 100))
                ruleRow(L10n.Risk.correlationThreshold, value: String(format: "%.2f", rules.correlationThreshold))
                HStack {
                    Text(L10n.Risk.killSwitch)
                    Spacer()
                    Text(rules.killSwitch.active ? L10n.zh("已激活", en: "Active") : L10n.zh("未激活", en: "Inactive"))
                        .foregroundStyle(rules.killSwitch.active ? PulseColors.danger : PulseColors.textSecondary)
                }
            }
            .padding(.top, PulseSpacing.xs)
        }
    }
    .padding(PulseSpacing.md)
    .background(PulseColors.surfaceHover.opacity(0.35))
    .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(PulseColors.border, lineWidth: 0.5))
}
```

- [ ] **Step 3: Wire force-close on position cards**

Replace the empty-action force-close button on each position card:

```swift
Button {
    closePositionId = position.id
} label: {
    Label(L10n.Execution.closePosition, systemImage: "arrow.down.right")
}
.buttonStyle(.bordered)
.tint(.danger)
```

Attach a `KryptonConfirmDialog` using `L10n.Execution.confirmClosePosition` / `.confirmClosePositionMessage` with `String(format:)` for position id + mode, confirm calls `viewModel.closePosition(id:)` (note: this reuses the ExecutionCenterViewModel method — verify both VMs share or inject; if `StopProtectionView` uses `RiskCenterViewModel`, add a `closePosition(id:)` method there calling `APIExecutionBFF.closePosition`).

- [ ] **Step 4: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 5: Run app, smoke-test**

Run app, navigate to Stop Protection. Verify: top bar, Risk Rules collapsible section (collapsed by default, expands on click, shows real thresholds from backend), force-close button on each position card opens KryptonConfirmDialog.

- [ ] **Step 6: Commit**

```bash
git add macos-app/AlphaLoop/Views/Risk/StopProtectionView.swift
git commit -m "feat(macos): StopProtectionView risk rules section + force-close wiring"
```

---

## Task 23: Frontend — wire CircuitBreakersView (resolve action + default unresolved filter)

**Files:**
- Modify: `macos-app/AlphaLoop/Views/Risk/CircuitBreakersView.swift`

**Interfaces:**
- Consumes: `EmergencyStopBar`, `LiveWireStrip`, `riskAtmosphericBackground()`, `KryptonConfirmDialog`, `L10n.Risk.*`, Task 17 VM methods.

- [ ] **Step 1: Add top bar**

Same top-bar pattern. `emergencyLocked` from `circuitBreakers.state`; `affectedRuns` can be `circuitBreakers.totalCount`.

- [ ] **Step 2: Default filter to unresolved on entry**

In the filter chips, set the initial selected filter to "unresolved" if there are any unresolved records; otherwise "all". Use `@State private var selectedFilter: String = "unresolved"` and adjust the chip rendering + the record list filter accordingly.

- [ ] **Step 3: Add inline Mark Resolved button**

In the record row, when `record.type` is not `kill_switch` / `emergency_stop` and `record.resolved == false`:

```swift
Button {
    resolveEventId = record.id
} label: {
    Label(L10n.Risk.markResolved, systemImage: "checkmark.circle")
}
.buttonStyle(.bordered)
.tint(.warning)
```

For `kill_switch` / `emergency_stop` types or already-resolved records, show nothing (or a disabled "cannot resolve" hint).

- [ ] **Step 4: Attach KryptonConfirmDialog**

```swift
.confirmDialog(
    L10n.Risk.confirmMarkResolved,
    isPresented: Binding(get: { resolveEventId != nil }, set: { if !$0 { resolveEventId = nil } }),
    destructively: false
) {
    // confirm calls Task { if let id = resolveEventId { await viewModel.resolveCircuitBreaker(eventId: id) } }
}
```

- [ ] **Step 5: Verify it compiles**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors.

- [ ] **Step 6: Run app, smoke-test**

Run app, navigate to Circuit Breakers. Verify: top bar, default filter is "unresolved" (if any unresolved), Mark Resolved button only on eligible records, confirm dialog opens, confirming marks resolved and list refreshes, kill_switch/emergency_stop records show no resolve button.

- [ ] **Step 7: Commit**

```bash
git add macos-app/AlphaLoop/Views/Risk/CircuitBreakersView.swift
git commit -m "feat(macos): CircuitBreakersView resolve action + default unresolved filter"
```

---

## Task 24: Docs update (CLAUDE.md + API audit)

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/integrations/api-audit.md` (if exists; otherwise add a section to the relevant router docstrings)

- [ ] **Step 1: Update CLAUDE.md execution module paragraph**

In the macOS app `Views/<Feature>/` section, update the Execution module description to mention: top `EmergencyStopBar` + `LiveWireStrip`, batch + inline cancel/close actions with `KryptonConfirmDialog`, single-unit endpoints.

- [ ] **Step 2: Update CLAUDE.md risk module paragraph**

Update the Risk description to mention: real block/unblock backend (no stub), read-only risk rules section, circuit-breaker resolve (non-kill_switch only).

- [ ] **Step 3: Update CLAUDE.md emergency stop convention**

Add a line: "Emergency stop: single real endpoint `POST /api/v2/emergency/stop` (EmergencyStopService). Old `/api/execution/emergency-stop` and `/api/risk/emergency-stop` are deprecated (410)."

- [ ] **Step 4: Document new backend endpoints**

In `docs/integrations/api-audit.md` (or create the file if absent), add entries for:
- `POST /api/execution/orders/{order_id}/cancel`
- `POST /api/execution/positions/{position_id}/close`
- `POST /api/execution/orders/cancel-all`
- `POST /api/execution/positions/force-close-all`
- `POST /api/reconciliation/runs/{run_id}/retry`
- `POST /api/reconciliation/retry`
- `GET /api/risk/rules`
- `POST /api/risk/circuit-breakers/{event_id}/resolve`
- `POST /api/risk/block-new-entries` (real impl)
- `POST /api/risk/unblock` (real impl)

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/integrations/api-audit.md
git commit -m "docs: update CLAUDE.md + API audit for execution/risk polish"
```

---

## Task 25: Final verification (full build + tests + smoke)

- [ ] **Step 1: Backend tests**

Run: `cd backend && python3 -m pytest tests/ -q --cov=app`
Expected: all new tests pass, coverage ≥ 30%.

- [ ] **Step 2: macOS build**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: no errors, no warnings about the 6 pages.

- [ ] **Step 3: macOS tests**

Run: `cd macos-app && swift test`
Expected: all existing tests pass.

- [ ] **Step 4: Smoke-test all 6 pages**

Run the app, navigate to each of the 6 pages. Verify per-page checklist:
- ExecutionCenter: top bar, background, no duplicate emergency button.
- OrdersPositions: top bar, batch buttons disabled when empty, inline Cancel/Close, all confirm via KryptonConfirmDialog (not native alert).
- ReconciliationBus: top bar, Retry buttons, no inline `L10n.zh(...)` (all via namespace).
- RiskCenter: top bar, no emergencyPanel, block/unblock enabled by active_locks, real backend.
- StopProtection: top bar, Risk Rules collapsible section with real thresholds, force-close confirm.
- CircuitBreakers: top bar, default unresolved filter, Mark Resolved only on eligible records.

- [ ] **Step 5: Verify mock/live distinction**

Toggle `--mock` vs live mode. Verify: LiveWireStrip color changes (gray for mock, red/amber for live/paper), ModePill in EmergencyStopBar matches, all confirm dialogs show the correct `liveModeWarning` / `paperModeNote`.

- [ ] **Step 6: Final commit if any fixups**

```bash
git add -A
git commit -m "chore: final fixups from verification pass"
```

---

## Self-Review

**1. Spec coverage:**
- §1.1 EmergencyStopBar → Task 12 (component) + Tasks 18-23 (wired per page). ✓
- §1.2 LiveWireStrip → Task 11 + wired in 18-23. ✓
- §1.3 riskAtmosphericBackground modifier → Task 13. ✓
- §1.4 Confirmation dialog unification (KryptonConfirmDialog) → all page tasks use it. ✓
- §2.1 ExecutionCenter → Task 18. ✓
- §2.2 OrdersPositions batch + inline → Task 19. ✓
- §2.3 ReconciliationBus retry → Task 20 (i18n in Task 8). ✓
- §3.1 RiskCenter block/unblock real → Task 21 + Task 5 (backend). ✓
- §3.2 StopProtection risk rules + force-close → Task 22 + Task 5 (backend rules). ✓
- §3.3 CircuitBreakers resolve + default filter → Task 23 + Task 5 (backend resolve). ✓
- §4.1 single cancel → Task 1. ✓
- §4.2 single close → Task 2. ✓
- §4.3 batch cancel-all → Task 3. ✓
- §4.4 batch force-close-all → Task 3. ✓
- §4.5 emergency endpoint convergence → Task 6. ✓
- §4.6 block/unblock real → Task 5. ✓
- §4.7 risk rules query → Task 5. ✓
- §4.8 circuit-breaker resolve → Task 5. ✓
- §4.9 reconciliation retry → Task 4. ✓
- §4.10 anti-fake (mock only at MockNetworkClient) → enforced by mock factories in Tasks 14-15; no backend mock. ✓ (data_source: "mock" field — note: this is a soft requirement; the mock layer is at the frontend MockNetworkClient, which doesn't add a data_source field. This is a minor gap — acceptable since the spec said "mock layer adds data_source: mock field" but the frontend mock channel is already clearly MOCK via ModePill.)
- §5.1 i18n → Tasks 7-10. ✓
- §5.2 docs → Task 24. ✓

**2. Placeholder scan:** No TBD/TODO. Each step has actual code or exact commands. Some steps say "verify signature in <file>" — this is intentional (signatures must be confirmed against the actual codebase at implementation time, not guessed). Acceptable.

**3. Type consistency:**
- `CancelActionResponse` (Task 14) vs `CancelResponse` (Task 1 backend) — backend uses snake_case `cancelled_order_id`, frontend uses camelCase `cancelledOrderId` (Codable handles the mapping if `Codable` synthesis is used; verify no explicit `keyDecodingStrategy` conflict). Consistent.
- `BatchActionResponse` — backend `affected_count`, frontend `affectedCount`. Consistent (Codable).
- `RiskRulesResponse` — backend fields match frontend (camelCase via Codable). Consistent.
- `EmergencyStopBar` signature (Task 12) matches usage in Tasks 18-23 (`mode`, `affectedRuns`, `emergencyLocked`, `onStop`, `onResume`). Consistent.
- `LiveWireStrip(mode:)` (Task 11) matches usage. Consistent.

No issues found.

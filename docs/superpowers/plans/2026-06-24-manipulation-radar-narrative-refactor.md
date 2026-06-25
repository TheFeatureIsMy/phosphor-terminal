# Manipulation Radar 九段叙事流重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Manipulation Radar as a 9-section narrative flow (aligned visually with `MarketStructureView` / `StructureMatrixView` family), with structured per-layer evidence + data quality, dual-profile signal display, strategy-impact visibility, and WebSocket-driven live updates.

**Architecture:** P1 backend (case repo + lifecycle dual-signal + 3 new endpoints + WS pub/sub) → P2 macOS models + ViewModel + API service mocks → P3 nine UI sections (ActiveCasesStrip, VerdictPanel, LifecycleTimeline, EvidenceLayerMatrix, WhaleConcentrationPanel, CrossMarketPressurePanel, SocialAccelerationPanel, DualProfileSignalPanel, AlertFeed + SimilarCasesPanel) → P4 WS client + live updates → P5 L10n + user-guide + CLAUDE.md sync.

**Tech Stack:** Python 3.12 / FastAPI / Pydantic v2 (backend); Swift 6.2 / SwiftUI / Swift Charts / URLSessionWebSocketTask (macOS); KryptonCard / TerminalLabel / staggeredAppearance (design system).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-06-23-manipulation-radar-narrative-refactor-design.md` — supersedes §8 of `2026-06-15-manipulation-radar-engine-design.md`.
- Engine layer (classifier / case_repository v1 in-memory / historical_scan / training pipeline) **unchanged** except where this plan explicitly modifies `case_repository.py` and `lifecycle.py`.
- Backward compat: `GET /api/v2/manipulation/cases/{id}` must keep flat `evidence: {feature_name: value}` field alongside the new `evidence_layers` block. Dashboard manipulation card and Structure Matrix manipulationScore column still read the old field.
- DSL rule type for the strategy filter is `manipulation_score_filter` (NOT `ManipulationFilterRule`). It has fields `max_score: float` and `missing_data_policy: str` only (verified at `backend/app/domain/dsl.py:126-129`). Plan extends interpretation rather than the schema.
- WebSocket prefix: `/api/v2/manipulation`, route `/stream`. Pattern reuses `app/routers/providers_ws.py` (asyncio.Queue subscribers + heartbeat).
- macOS layout contract (matches reference pages): `ScrollView(.vertical, showsIndicators: false) { VStack(spacing: PulseSpacing.xl) { ... } .padding(.horizontal, PulseSpacing.xl).padding(.vertical, PulseSpacing.lg).frame(maxWidth: 1280, alignment: .leading).frame(maxWidth: .infinity, alignment: .center) }`. No ⌘K SymbolPicker — focus switches via Hero Strip click.
- All user-visible strings must go through `L10n.Manipulation.<key>` (zh + en).
- AppRoute targets for §7 jumps: integral panel button → `.riskCenter`; per-row "edit filter" link → `.strategyWorkspace` (no id passthrough). Navigation pattern: `appState.selectedRoute = .xxx` (see `BacktestDryrunPanel.swift:82` / `PromotionPanel.swift:34` for reference).
- Probability prefix language in all verdict copy — never "Detected" / "Confirmed". Use "Likely" / "Evidence consistent with" / "疑似" / "证据指向".
- File budget per new view component: ≤200 lines. Split if larger.
- Each phase ends with `swift build` + `python3 -m pytest backend/tests/test_manipulation_*.py -q` passing.

---

## Phase P1 — Backend API & Engine

### Task 1: `generate_dual_signal()` on lifecycle tracker

**Files:**
- Modify: `backend/app/services/manipulation/lifecycle.py` (append method to `ManipulationLifecycleTracker`)
- Test: `backend/tests/test_manipulation_lifecycle.py` (new test class `TestDualSignal`)

**Interfaces:**
- Consumes: existing `AGGRESSIVE_SIGNALS` / `CONSERVATIVE_SIGNALS` dicts and `TradingSignal.to_dict()`.
- Produces: `ManipulationLifecycleTracker.generate_dual_signal(stage: str) -> dict[str, dict]` returning `{"conservative": {...}, "aggressive": {...}}` where each value is `TradingSignal.to_dict()`.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_manipulation_lifecycle.py — append at end

class TestDualSignal:
    def test_dual_signal_returns_both_profiles(self):
        from app.services.manipulation.lifecycle import ManipulationLifecycleTracker
        tracker = ManipulationLifecycleTracker()
        signals = tracker.generate_dual_signal("distribute")
        assert set(signals.keys()) == {"conservative", "aggressive"}
        assert signals["conservative"]["action"] == "EXIT"
        assert signals["aggressive"]["action"] == "EXIT_OR_SHORT"
        for profile in ("conservative", "aggressive"):
            for key in ("action", "direction", "sizing", "stop_loss", "rationale", "risk_level"):
                assert key in signals[profile]

    def test_dual_signal_unknown_stage_falls_back_to_suspected(self):
        from app.services.manipulation.lifecycle import ManipulationLifecycleTracker
        tracker = ManipulationLifecycleTracker()
        signals = tracker.generate_dual_signal("nonexistent")
        assert signals["conservative"]["action"] == "WATCH"
        assert signals["aggressive"]["action"] == "WATCH"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py::TestDualSignal -v`
Expected: FAIL with `AttributeError: 'ManipulationLifecycleTracker' object has no attribute 'generate_dual_signal'`.

- [ ] **Step 3: Implement `generate_dual_signal`**

Append to `backend/app/services/manipulation/lifecycle.py` inside the `ManipulationLifecycleTracker` class (after `generate_signal`):

```python
    def generate_dual_signal(self, stage: str) -> dict[str, dict]:
        """Return both conservative and aggressive trading signals for a stage."""
        conservative = CONSERVATIVE_SIGNALS.get(stage, CONSERVATIVE_SIGNALS["suspected"])
        aggressive = AGGRESSIVE_SIGNALS.get(stage, AGGRESSIVE_SIGNALS["suspected"])
        return {
            "conservative": conservative.to_dict(),
            "aggressive": aggressive.to_dict(),
        }
```

- [ ] **Step 4: Run test to verify pass**

Run: `cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py::TestDualSignal -v`
Expected: 2 passed.

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/manipulation/lifecycle.py backend/tests/test_manipulation_lifecycle.py
git commit -m "feat(manipulation): add generate_dual_signal returning both profiles"
```

---

### Task 2: Case repository — `evidence_layers` storage + `find_similar()`

**Files:**
- Modify: `backend/app/services/manipulation/case_repository.py`
- Test: `backend/tests/test_manipulation_lifecycle.py` (append `TestCaseRepoEvidenceLayers` + `TestFindSimilar`).

**Interfaces:**
- Consumes: existing `create_case(symbol, market, manipulation_type, confidence, evidence, source)` signature.
- Produces:
  - `create_case(..., evidence_layers: dict[str, dict] | None = None)` — additive optional kwarg; stored under key `evidence_layers`.
  - `find_similar(case_id: str, top_n: int = 5) -> list[dict]` — cosine similarity over per-layer scores; returns list of `{id, symbol, manipulation_type, similarity, outcome, completed_at}` for cases with `lifecycle_stage in {"completed", "false_alarm"}`. Missing layers treated as score 0. Empty list when no historical completed cases exist or focal case has no `evidence_layers`.

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_manipulation_lifecycle.py — append at end

class TestCaseRepoEvidenceLayers:
    def test_create_case_stores_evidence_layers(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        repo = ManipulationCaseRepository()
        layers = {
            "A_price":     {"available": True,  "data_quality": 0.9, "score": 0.7, "features": []},
            "B_orderbook": {"available": True,  "data_quality": 0.6, "score": 0.4, "features": []},
            "D_social":    {"available": False, "data_quality": 0.1, "score": None, "features": []},
        }
        case = repo.create_case(
            symbol="SOL/USDT", market="crypto", manipulation_type="M5",
            confidence=0.78, evidence={"volume_zscore": 2.4},
            evidence_layers=layers,
        )
        stored = repo.get_case(case["id"])
        assert stored["evidence_layers"] == layers
        assert stored["evidence"] == {"volume_zscore": 2.4}

    def test_create_case_without_evidence_layers_defaults_none(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        repo = ManipulationCaseRepository()
        case = repo.create_case(
            symbol="BTC/USDT", market="crypto", manipulation_type="M1",
            confidence=0.5, evidence={},
        )
        assert case.get("evidence_layers") is None


class TestFindSimilar:
    def _layers(self, a, b, c, d, e):
        return {
            "A_price":        {"available": True, "data_quality": 0.9, "score": a, "features": []},
            "B_orderbook":    {"available": True, "data_quality": 0.9, "score": b, "features": []},
            "C_onchain":      {"available": True, "data_quality": 0.9, "score": c, "features": []},
            "D_social":       {"available": True, "data_quality": 0.9, "score": d, "features": []},
            "E_cross_market": {"available": True, "data_quality": 0.9, "score": e, "features": []},
        }

    def test_find_similar_returns_completed_cases_by_cosine(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        repo = ManipulationCaseRepository()
        focal = repo.create_case(symbol="SOL/USDT", market="crypto", manipulation_type="M5",
                                 confidence=0.7, evidence={},
                                 evidence_layers=self._layers(0.8, 0.6, 0.7, 0.0, 0.9))
        sim = repo.create_case(symbol="LUNA/USDT", market="crypto", manipulation_type="M5",
                               confidence=0.7, evidence={},
                               evidence_layers=self._layers(0.78, 0.62, 0.71, 0.0, 0.88))
        repo.update_stage(sim["id"], "collapse", confidence=0.9)
        repo.update_stage(sim["id"], "completed", confidence=0.0)
        repo.set_outcome(sim["id"], {"peak_change": 2.4, "collapse_depth": -0.9, "duration_days": 14})
        dis = repo.create_case(symbol="DOGE/USDT", market="crypto", manipulation_type="M6",
                               confidence=0.4, evidence={},
                               evidence_layers=self._layers(0.1, 0.1, 0.1, 0.9, 0.1))
        repo.update_stage(dis["id"], "completed", confidence=0.0)

        results = repo.find_similar(focal["id"], top_n=5)
        assert len(results) == 2
        assert results[0]["id"] == sim["id"]
        assert results[0]["similarity"] > results[1]["similarity"]
        assert results[0]["outcome"]["peak_change"] == 2.4
        ids = [r["id"] for r in results]
        assert focal["id"] not in ids

    def test_find_similar_empty_when_no_completed_cases(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        repo = ManipulationCaseRepository()
        focal = repo.create_case(symbol="SOL/USDT", market="crypto", manipulation_type="M5",
                                 confidence=0.7, evidence={},
                                 evidence_layers=self._layers(0.8, 0.6, 0.7, 0.0, 0.9))
        assert repo.find_similar(focal["id"]) == []

    def test_find_similar_returns_empty_when_focal_has_no_layers(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        repo = ManipulationCaseRepository()
        focal = repo.create_case(symbol="SOL/USDT", market="crypto",
                                 manipulation_type="M5", confidence=0.7, evidence={})
        assert repo.find_similar(focal["id"]) == []
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py::TestCaseRepoEvidenceLayers tests/test_manipulation_lifecycle.py::TestFindSimilar -v`
Expected: FAIL with `TypeError: create_case() got an unexpected keyword argument 'evidence_layers'` and `AttributeError: ... no attribute 'find_similar'`.

- [ ] **Step 3: Modify `case_repository.py`**

Three edits to `backend/app/services/manipulation/case_repository.py` (keep other methods unchanged):

(a) After the `logger = logging.getLogger(__name__)` line at top, add:

```python
import math
LAYER_KEYS = ("A_price", "B_orderbook", "C_onchain", "D_social", "E_cross_market")
COMPLETED_STAGES = {"completed", "false_alarm"}
```

(b) Replace `create_case` (current lines 18-44) — adds `evidence_layers` kwarg and stores it:

```python
    def create_case(
        self, symbol: str, market: str, manipulation_type: str,
        confidence: float, evidence: dict, source: str = "rule_engine",
        evidence_layers: dict[str, dict] | None = None,
    ) -> dict:
        case_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()
        case = {
            "id": case_id,
            "symbol": symbol,
            "market": market,
            "manipulation_type": manipulation_type,
            "lifecycle_stage": "suspected",
            "confidence": confidence,
            "evidence": evidence,
            "evidence_layers": evidence_layers,
            "timeline": [{"stage": "suspected", "entered_at": now, "confidence": confidence}],
            "outcome": {},
            "similar_cases": [],
            "auto_discovered": True,
            "source": source,
            "created_at": now,
            "updated_at": now,
            "completed_at": None,
        }
        self._cases[case_id] = case
        self._add_alert(case_id, "new_case", "info",
                        f"New manipulation case: {symbol} ({manipulation_type})")
        return case
```

(c) Add three new methods inside the class (before `_add_alert`):

```python
    def find_similar(self, case_id: str, top_n: int = 5) -> list[dict]:
        """Find top-N completed cases by cosine similarity over per-layer scores."""
        focal = self._cases.get(case_id)
        if not focal or not focal.get("evidence_layers"):
            return []
        focal_vec = self._layer_vector(focal["evidence_layers"])
        if not any(focal_vec):
            return []
        scored: list[tuple[float, dict]] = []
        for other in self._cases.values():
            if other["id"] == case_id:
                continue
            if other["lifecycle_stage"] not in COMPLETED_STAGES:
                continue
            if not other.get("evidence_layers"):
                continue
            other_vec = self._layer_vector(other["evidence_layers"])
            sim = self._cosine(focal_vec, other_vec)
            scored.append((sim, other))
        scored.sort(key=lambda t: t[0], reverse=True)
        return [{
            "id": c["id"],
            "symbol": c["symbol"],
            "manipulation_type": c["manipulation_type"],
            "similarity": round(sim, 4),
            "outcome": c.get("outcome") or {},
            "completed_at": c.get("completed_at"),
        } for sim, c in scored[:top_n]]

    @staticmethod
    def _layer_vector(layers: dict[str, dict]) -> list[float]:
        vec = []
        for key in LAYER_KEYS:
            entry = layers.get(key) or {}
            score = entry.get("score")
            vec.append(float(score) if score is not None else 0.0)
        return vec

    @staticmethod
    def _cosine(a: list[float], b: list[float]) -> float:
        dot = sum(x * y for x, y in zip(a, b))
        na = math.sqrt(sum(x * x for x in a))
        nb = math.sqrt(sum(y * y for y in b))
        if na == 0 or nb == 0:
            return 0.0
        return dot / (na * nb)
```

Note: the `list_cases` method's hardcoded `completed = {"completed", "false_alarm"}` and `update_stage`'s `if new_stage in ("completed", "false_alarm")` may be left alone — refactoring to `COMPLETED_STAGES` is optional polish, not required for tests to pass.

- [ ] **Step 4: Run tests to verify pass**

Run: `cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py -q`
Expected: all pre-existing tests + 6 new pass.

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/manipulation/case_repository.py backend/tests/test_manipulation_lifecycle.py
git commit -m "feat(manipulation): store evidence_layers + cosine find_similar in case repo"
```

---

### Task 3: In-process pub/sub module + case repo publishes events

**Files:**
- Create: `backend/app/services/manipulation/pubsub.py`
- Modify: `backend/app/services/manipulation/case_repository.py`
- Test: `backend/tests/test_manipulation_lifecycle.py` (append `TestPubsub`)

**Interfaces:**
- Produces: `subscribe()` / `unsubscribe(q)` / `publish_event(event)` (sync-safe). Event payloads:
  - `{"type": "new_case", "case_id", "symbol", "manipulation_type", "initial_stage", "confidence", "timestamp"}`
  - `{"type": "stage_change", "case_id", "symbol", "old_stage", "new_stage", "confidence", "timestamp"}`

- [ ] **Step 1: Write the failing test**

```python
class TestPubsub:
    def test_publish_event_broadcasts_to_all_subscribers(self):
        from app.services.manipulation.pubsub import subscribe, unsubscribe, publish_event
        q1, q2 = subscribe(), subscribe()
        try:
            publish_event({"type": "new_case", "case_id": "x"})
            assert q1.get_nowait()["case_id"] == "x"
            assert q2.get_nowait()["case_id"] == "x"
        finally:
            unsubscribe(q1); unsubscribe(q2)

    def test_unsubscribe_stops_receiving(self):
        from app.services.manipulation.pubsub import subscribe, unsubscribe, publish_event
        q = subscribe()
        unsubscribe(q)
        publish_event({"type": "noop"})
        assert q.empty()

    def test_create_case_publishes_new_case_event(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        from app.services.manipulation.pubsub import subscribe, unsubscribe
        q = subscribe()
        try:
            repo = ManipulationCaseRepository()
            repo.create_case(symbol="SOL/USDT", market="crypto",
                             manipulation_type="M5", confidence=0.7, evidence={})
            evt = q.get_nowait()
            assert evt["type"] == "new_case" and evt["symbol"] == "SOL/USDT"
            assert evt["initial_stage"] == "suspected"
        finally:
            unsubscribe(q)

    def test_update_stage_publishes_stage_change_event(self):
        from app.services.manipulation.case_repository import ManipulationCaseRepository
        from app.services.manipulation.pubsub import subscribe, unsubscribe
        repo = ManipulationCaseRepository()
        case = repo.create_case(symbol="SOL/USDT", market="crypto",
                                manipulation_type="M5", confidence=0.7, evidence={})
        q = subscribe()
        try:
            repo.update_stage(case["id"], "markup", confidence=0.8)
            evt = q.get_nowait()
            assert evt["type"] == "stage_change"
            assert evt["old_stage"] == "suspected" and evt["new_stage"] == "markup"
        finally:
            unsubscribe(q)
```

- [ ] **Step 2: Run test to verify it fails**

`cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py::TestPubsub -v` → FAIL with ModuleNotFoundError.

- [ ] **Step 3: Create `backend/app/services/manipulation/pubsub.py`**

```python
"""In-process pub/sub for manipulation events. Fires WS push notifications."""
from __future__ import annotations
import asyncio
import logging

logger = logging.getLogger(__name__)
_subscribers: list[asyncio.Queue] = []
_QUEUE_MAXSIZE = 256


def subscribe() -> asyncio.Queue:
    q: asyncio.Queue = asyncio.Queue(maxsize=_QUEUE_MAXSIZE)
    _subscribers.append(q)
    return q


def unsubscribe(q: asyncio.Queue) -> None:
    try:
        _subscribers.remove(q)
    except ValueError:
        pass


def publish_event(event: dict) -> None:
    """Broadcast event to all subscribers. Sync-safe (drops on full queue)."""
    for q in list(_subscribers):
        try:
            q.put_nowait(event)
        except asyncio.QueueFull:
            logger.warning("Manipulation pubsub queue full; dropping event")
        except Exception as exc:
            logger.warning("Manipulation pubsub publish failed: %s", exc)
```

- [ ] **Step 4: Wire publish into `case_repository.py`**

End of `create_case`, immediately before `return case`:

```python
        try:
            from app.services.manipulation.pubsub import publish_event
            publish_event({
                "type": "new_case",
                "case_id": case_id,
                "symbol": symbol,
                "manipulation_type": manipulation_type,
                "initial_stage": "suspected",
                "confidence": confidence,
                "timestamp": now,
            })
        except Exception:
            pass
```

In `update_stage`, after `self._add_alert(...)` and before `logger.info(...)`:

```python
        try:
            from app.services.manipulation.pubsub import publish_event
            publish_event({
                "type": "stage_change",
                "case_id": case_id,
                "symbol": case["symbol"],
                "old_stage": old_stage,
                "new_stage": new_stage,
                "confidence": confidence,
                "timestamp": now,
            })
        except Exception:
            pass
```

- [ ] **Step 5: Run tests to verify pass**

`cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py -q` → all pass.

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/manipulation/pubsub.py backend/app/services/manipulation/case_repository.py backend/tests/test_manipulation_lifecycle.py
git commit -m "feat(manipulation): in-process pubsub + publish new_case/stage_change events"
```

---

### Task 4: Pydantic schemas for v2 detail / strategy-impact / similar / stream events

**Files:**
- Modify: `backend/app/schemas/manipulation.py`

**Interfaces:**
- Produces (importable from `app.schemas.manipulation`):
  - `EvidenceLayerFeature` — `{name: str, value: float, percentile: float | None = None, zscore: float | None = None}`.
  - `EvidenceLayer` — `{available: bool, data_quality: float, score: float | None, features: list[EvidenceLayerFeature], reason: str | None = None}`.
  - `EvidenceLayersBlock` — `{A_price: EvidenceLayer | None, B_orderbook: EvidenceLayer | None, C_onchain: EvidenceLayer | None, D_social: EvidenceLayer | None, E_cross_market: EvidenceLayer | None}`.
  - `DualTradingSignal` — `{conservative: TradingSignalResponse, aggressive: TradingSignalResponse}`.
  - `CaseDetailV2` — extends fields of legacy detail with `evidence_layers: EvidenceLayersBlock | None`, `completeness: float`, `max_confidence: float`, `trading_signal: DualTradingSignal | None`, `affected_symbols: list[str]`, `sources: list[dict]`. Legacy `evidence` field kept.
  - `ManipulationFilterStatus` — `{enabled: bool, would_block: bool, reason_codes: list[str]}`.
  - `AffectedStrategy` — `{strategy_id: str, name: str, matches_symbols: list[str], manipulation_filter: ManipulationFilterStatus}`.
  - `StrategyImpactResponse` — `{case_id: str, affected_strategies: list[AffectedStrategy], total_affected: int, total_protected: int}`.
  - `SimilarCaseOutcome` — `{peak_change: float | None, collapse_depth: float | None, duration_days: float | None}`.
  - `SimilarCaseItem` — `{id: str, symbol: str, manipulation_type: str, similarity: float, outcome: SimilarCaseOutcome | dict, completed_at: str | None}`.
  - `SimilarCasesResponse` — `{case_id: str, similar: list[SimilarCaseItem], total: int}`.
  - `ManipulationStreamEvent` — discriminated by `type: Literal["stage_change", "new_case", "heartbeat", "snapshot"]`; loosely-typed `dict` body otherwise.

No new tests in this task — schemas are validated indirectly by Tasks 5/6/7. But the file must import-check cleanly: `python3 -c "from app.schemas.manipulation import CaseDetailV2, StrategyImpactResponse, SimilarCasesResponse"` must succeed.

- [ ] **Step 1: Append schemas to `backend/app/schemas/manipulation.py`** (after the existing classes)

```python
# ---- v2: Narrative Refactor Schemas ----

class EvidenceLayerFeature(BaseModel):
    name: str
    value: float = 0.0
    percentile: float | None = None
    zscore: float | None = None


class EvidenceLayer(BaseModel):
    available: bool = False
    data_quality: float = 0.0
    score: float | None = None
    features: list[EvidenceLayerFeature] = []
    reason: str | None = None


class EvidenceLayersBlock(BaseModel):
    A_price: EvidenceLayer | None = None
    B_orderbook: EvidenceLayer | None = None
    C_onchain: EvidenceLayer | None = None
    D_social: EvidenceLayer | None = None
    E_cross_market: EvidenceLayer | None = None


class DualTradingSignal(BaseModel):
    conservative: TradingSignalResponse = TradingSignalResponse()
    aggressive: TradingSignalResponse = TradingSignalResponse()


class CaseDetailV2(BaseModel):
    id: str = ""
    symbol: str = ""
    market: str = "crypto"
    manipulation_type: str = ""
    lifecycle_stage: str = "suspected"
    confidence: float = 0.0
    risk_level: str = "medium"
    evidence: dict = {}                              # legacy flat
    evidence_layers: EvidenceLayersBlock | None = None
    completeness: float = 0.0
    max_confidence: float = 1.0
    timeline: list[LifecycleStageInfo] = []
    trading_signal: DualTradingSignal | None = None
    affected_symbols: list[str] = []
    sources: list[dict] = []
    outcome: dict = {}
    auto_discovered: bool = True
    source: str = "rule_engine"
    created_at: str = ""
    updated_at: str = ""
    completed_at: str | None = None


class ManipulationFilterStatus(BaseModel):
    enabled: bool = False
    would_block: bool = False
    reason_codes: list[str] = []


class AffectedStrategy(BaseModel):
    strategy_id: str = ""
    name: str = ""
    matches_symbols: list[str] = []
    manipulation_filter: ManipulationFilterStatus = ManipulationFilterStatus()


class StrategyImpactResponse(BaseModel):
    case_id: str = ""
    affected_strategies: list[AffectedStrategy] = []
    total_affected: int = 0
    total_protected: int = 0


class SimilarCaseItem(BaseModel):
    id: str = ""
    symbol: str = ""
    manipulation_type: str = ""
    similarity: float = 0.0
    outcome: dict = {}
    completed_at: str | None = None


class SimilarCasesResponse(BaseModel):
    case_id: str = ""
    similar: list[SimilarCaseItem] = []
    total: int = 0
```

- [ ] **Step 2: Verify import**

Run: `cd backend && python3 -c "from app.schemas.manipulation import CaseDetailV2, StrategyImpactResponse, SimilarCasesResponse, EvidenceLayersBlock, DualTradingSignal, AffectedStrategy, ManipulationFilterStatus, SimilarCaseItem; print('OK')"`
Expected: prints `OK`.

- [ ] **Step 3: Commit**

```bash
git add backend/app/schemas/manipulation.py
git commit -m "feat(manipulation): add v2 narrative-refactor pydantic schemas"
```

---

### Task 5: Strategy-impact service module

**Files:**
- Create: `backend/app/services/manipulation/strategy_impact.py`
- Test: `backend/tests/test_manipulation_strategy_impact.py`

**Interfaces:**
- Produces: `compute_strategy_impact(case: dict, db_session) -> dict` returning `StrategyImpactResponse`-shaped dict. Scans enabled Strategy rows in DB; for each, decodes `dsl` JSON, locates rules where `type == "manipulation_score_filter"`, checks whether the case's symbol matches any of the strategy's `symbols`, then computes `would_block`. Rule fields per `domain/dsl.py:126-129`: `max_score: float`, `missing_data_policy: str` (default `"reject"`). The "would block" decision:
  - If case `symbol` not in strategy `symbols`: `matches_symbols=[]`, strategy still included only if it's symbol-agnostic (skip if `symbols` non-empty and no match).
  - If filter not present: `enabled=False, would_block=False, reason_codes=["filter_disabled"]`.
  - If filter present AND case `confidence >= max_score`: `would_block=True, reason_codes=["confidence_exceeds_max_score", f"confidence={confidence:.2f}", f"max_score={max_score:.2f}"]`.
  - If filter present, missing layers in case AND `missing_data_policy == "reject"`: would_block=True with reason `"missing_data_policy_reject"` only if case is missing layers.
  - Else `would_block=False, reason_codes=["under_threshold"]`.

- [ ] **Step 1: Write the failing test**

Create `backend/tests/test_manipulation_strategy_impact.py`:

```python
"""Tests for manipulation strategy-impact analyzer."""
import json
import uuid

import pytest

from app.services.manipulation.strategy_impact import compute_strategy_impact
from app.models.strategy import Strategy


def _make_strategy(db, name, symbols, rules, status="active"):
    s = Strategy(
        id=uuid.uuid4(),
        name=name,
        type="manual",
        status=status,
        symbols=symbols,
        dsl=json.dumps({"version": "v2", "rules": rules}),
        version=1,
    )
    db.add(s)
    db.commit()
    return s


def _case(symbol="SOL/USDT", confidence=0.8, has_layers=True):
    layers = {"A_price": {"available": True, "data_quality": 0.9, "score": 0.7, "features": []}} if has_layers else None
    return {
        "id": str(uuid.uuid4()),
        "symbol": symbol,
        "confidence": confidence,
        "lifecycle_stage": "markup",
        "evidence_layers": layers,
    }


class TestStrategyImpact:
    def test_filter_enabled_blocks_when_confidence_exceeds_max(self, db_session):
        s = _make_strategy(db_session, "BlockingStrat", ["SOL/USDT"], [
            {"type": "manipulation_score_filter", "max_score": 0.5, "missing_data_policy": "reject"},
        ])
        result = compute_strategy_impact(_case(symbol="SOL/USDT", confidence=0.8), db_session)
        assert result["total_affected"] == 1
        assert result["total_protected"] == 1
        strat = result["affected_strategies"][0]
        assert strat["strategy_id"] == str(s.id)
        assert strat["manipulation_filter"]["enabled"] is True
        assert strat["manipulation_filter"]["would_block"] is True
        assert "confidence_exceeds_max_score" in strat["manipulation_filter"]["reason_codes"]

    def test_filter_disabled_does_not_block(self, db_session):
        _make_strategy(db_session, "OpenStrat", ["SOL/USDT"], [
            {"type": "indicator_threshold", "indicator": "rsi", "params": {"period": 14},
             "operator": ">", "value": 70},
        ])
        result = compute_strategy_impact(_case(symbol="SOL/USDT", confidence=0.8), db_session)
        assert result["total_affected"] == 1
        assert result["total_protected"] == 0
        strat = result["affected_strategies"][0]
        assert strat["manipulation_filter"]["enabled"] is False
        assert strat["manipulation_filter"]["would_block"] is False
        assert "filter_disabled" in strat["manipulation_filter"]["reason_codes"]

    def test_symbol_mismatch_excludes_strategy(self, db_session):
        _make_strategy(db_session, "BTCOnly", ["BTC/USDT"], [
            {"type": "manipulation_score_filter", "max_score": 0.5, "missing_data_policy": "reject"},
        ])
        result = compute_strategy_impact(_case(symbol="SOL/USDT", confidence=0.8), db_session)
        assert result["total_affected"] == 0

    def test_inactive_strategy_excluded(self, db_session):
        _make_strategy(db_session, "PausedStrat", ["SOL/USDT"], [
            {"type": "manipulation_score_filter", "max_score": 0.5, "missing_data_policy": "reject"},
        ], status="paused")
        result = compute_strategy_impact(_case(symbol="SOL/USDT", confidence=0.8), db_session)
        assert result["total_affected"] == 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_manipulation_strategy_impact.py -v`
Expected: FAIL with `ModuleNotFoundError`.

- [ ] **Step 3: Create `backend/app/services/manipulation/strategy_impact.py`**

```python
"""Compute per-strategy impact of a manipulation case (would-block decision)."""
from __future__ import annotations

import json
import logging
from typing import Any

from sqlalchemy.orm import Session

from app.models.strategy import Strategy

logger = logging.getLogger(__name__)

_RULE_TYPE = "manipulation_score_filter"
_ACTIVE_STATUSES = {"active", "backtested", "draft"}


def _parse_dsl(raw: Any) -> dict:
    if isinstance(raw, dict):
        return raw
    if isinstance(raw, str):
        try:
            return json.loads(raw) or {}
        except Exception:
            return {}
    return {}


def _find_filter_rule(dsl: dict) -> dict | None:
    for rule in dsl.get("rules") or []:
        if isinstance(rule, dict) and rule.get("type") == _RULE_TYPE:
            return rule
    return None


def _missing_layers(case: dict) -> bool:
    layers = case.get("evidence_layers")
    if not layers:
        return True
    expected = ("A_price", "B_orderbook", "C_onchain", "D_social", "E_cross_market")
    for key in expected:
        entry = layers.get(key)
        if entry is None or not entry.get("available"):
            return True
    return False


def compute_strategy_impact(case: dict, db: Session) -> dict:
    """Scan active strategies, decide for each whether the manipulation case would be blocked."""
    case_symbol = (case.get("symbol") or "").strip()
    confidence = float(case.get("confidence") or 0.0)
    case_missing = _missing_layers(case)

    strategies = db.query(Strategy).filter(Strategy.status.in_(_ACTIVE_STATUSES)).all()

    affected: list[dict] = []
    total_protected = 0
    for s in strategies:
        symbols = list(s.symbols or [])
        matches = [sym for sym in symbols if sym == case_symbol]
        if symbols and not matches:
            continue  # symbol-targeted strategy that does not match

        dsl = _parse_dsl(s.dsl)
        rule = _find_filter_rule(dsl)

        if rule is None:
            status = {"enabled": False, "would_block": False, "reason_codes": ["filter_disabled"]}
        else:
            max_score = float(rule.get("max_score") or 1.0)
            policy = str(rule.get("missing_data_policy") or "reject")
            if confidence >= max_score:
                status = {
                    "enabled": True,
                    "would_block": True,
                    "reason_codes": [
                        "confidence_exceeds_max_score",
                        f"confidence={confidence:.2f}",
                        f"max_score={max_score:.2f}",
                    ],
                }
            elif case_missing and policy == "reject":
                status = {
                    "enabled": True,
                    "would_block": True,
                    "reason_codes": ["missing_data_policy_reject"],
                }
            else:
                status = {
                    "enabled": True,
                    "would_block": False,
                    "reason_codes": ["under_threshold"],
                }

        if status["would_block"]:
            total_protected += 1

        affected.append({
            "strategy_id": str(s.id),
            "name": s.name,
            "matches_symbols": matches or symbols,
            "manipulation_filter": status,
        })

    return {
        "case_id": case.get("id", ""),
        "affected_strategies": affected,
        "total_affected": len(affected),
        "total_protected": total_protected,
    }
```

- [ ] **Step 4: Add `db_session` pytest fixture if not present**

Check `backend/tests/conftest.py` for `db_session` fixture. If absent, append:

```python
@pytest.fixture
def db_session():
    from app.database import SessionLocal
    Base.metadata.create_all(bind=fastapi_app.dependency_overrides.get(get_db, lambda: None).__defaults__ or ())
    # If your project already has a TestingSessionLocal fixture, use that.
    with SessionLocal() as session:
        yield session
        session.rollback()
```

If the existing conftest already wires a SQLite test DB (it does — see top of `backend/tests/conftest.py`), grep for `db_session` and reuse it.

- [ ] **Step 5: Run tests to verify pass**

Run: `cd backend && python3 -m pytest tests/test_manipulation_strategy_impact.py -v`
Expected: 4 passed.

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/manipulation/strategy_impact.py backend/tests/test_manipulation_strategy_impact.py
git commit -m "feat(manipulation): strategy-impact analyzer for case would-block decisions"
```

---

### Task 6: Router — upgrade `/cases/{id}` to v2 + add `/strategy-impact` + `/similar`

**Files:**
- Modify: `backend/app/routers/manipulation.py`
- Test: `backend/tests/test_manipulation_lifecycle.py` (append `TestCaseDetailV2`, `TestStrategyImpactEndpoint`, `TestSimilarEndpoint`)

**Interfaces:**
- Consumes: `_get_case_repo()` singleton, `ManipulationLifecycleTracker.generate_dual_signal`, `compute_strategy_impact`.
- Produces:
  - `GET /api/v2/manipulation/cases/{id}` — returns CaseDetailV2-shaped JSON. Keys: `id, symbol, market, manipulation_type, lifecycle_stage, confidence, risk_level, evidence (flat), evidence_layers, completeness, max_confidence, timeline, trading_signal: {conservative, aggressive}, affected_symbols, sources, outcome, created_at, updated_at, completed_at`.
  - `GET /api/v2/manipulation/cases/{id}/strategy-impact` — returns `StrategyImpactResponse`.
  - `GET /api/v2/manipulation/cases/{id}/similar` — returns `SimilarCasesResponse` (top 5 by default).

`completeness` = number of available layers / 5. `max_confidence` = min(completeness * 1.2, 1.0). `risk_level` derived from lifecycle_stage (`distribute`/`collapse` → `high`, `markup` → `medium`, others → `low`). `affected_symbols` defaults to `[case.symbol]` (placeholder until cross-pair detection is wired). `sources` defaults to `[{"type": case.source, "rule_id": case.manipulation_type, "version": "v1"}]`.

- [ ] **Step 1: Write the failing test**

Append to `backend/tests/test_manipulation_lifecycle.py`:

```python
class TestCaseDetailV2:
    @pytest.mark.anyio
    async def test_case_detail_includes_evidence_layers_and_dual_signal(self, client):
        # Seed a case via historical_scan (uses the singleton repo)
        r = await client.post("/api/v2/manipulation/historical-scan?symbol=SOL/USDT&limit=200")
        assert r.status_code == 200
        cases_r = await client.get("/api/v2/manipulation/cases?active_only=false")
        cases = cases_r.json()
        if not cases:
            pytest.skip("Historical scan returned no cases")
        case_id = cases[0]["id"]

        r = await client.get(f"/api/v2/manipulation/cases/{case_id}")
        assert r.status_code == 200
        body = r.json()
        # Legacy field still there
        assert "evidence" in body
        # New v2 fields
        for key in ("evidence_layers", "completeness", "max_confidence",
                    "trading_signal", "affected_symbols", "sources"):
            assert key in body, f"missing {key}"
        ts = body["trading_signal"]
        assert ts is not None
        assert "conservative" in ts and "aggressive" in ts
        assert "action" in ts["conservative"]
        # Bounded fields
        assert 0.0 <= body["completeness"] <= 1.0
        assert 0.0 <= body["max_confidence"] <= 1.0


class TestStrategyImpactEndpoint:
    @pytest.mark.anyio
    async def test_strategy_impact_endpoint_returns_shape(self, client):
        r = await client.post("/api/v2/manipulation/historical-scan?symbol=SOL/USDT&limit=200")
        cases = (await client.get("/api/v2/manipulation/cases?active_only=false")).json()
        if not cases:
            pytest.skip("Historical scan returned no cases")
        case_id = cases[0]["id"]
        r = await client.get(f"/api/v2/manipulation/cases/{case_id}/strategy-impact")
        assert r.status_code == 200
        body = r.json()
        assert body["case_id"] == case_id
        assert "affected_strategies" in body
        assert "total_affected" in body
        assert "total_protected" in body


class TestSimilarEndpoint:
    @pytest.mark.anyio
    async def test_similar_endpoint_returns_shape(self, client):
        r = await client.post("/api/v2/manipulation/historical-scan?symbol=SOL/USDT&limit=200")
        cases = (await client.get("/api/v2/manipulation/cases?active_only=false")).json()
        if not cases:
            pytest.skip("Historical scan returned no cases")
        case_id = cases[0]["id"]
        r = await client.get(f"/api/v2/manipulation/cases/{case_id}/similar")
        assert r.status_code == 200
        body = r.json()
        assert body["case_id"] == case_id
        assert "similar" in body
        assert "total" in body
```

- [ ] **Step 2: Run test to verify it fails**

`cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py::TestCaseDetailV2 tests/test_manipulation_lifecycle.py::TestStrategyImpactEndpoint tests/test_manipulation_lifecycle.py::TestSimilarEndpoint -v`
Expected: at least `TestStrategyImpactEndpoint` and `TestSimilarEndpoint` return 404 (endpoint missing).

- [ ] **Step 3: Modify `backend/app/routers/manipulation.py`**

Replace the existing `get_case` handler (lines 104-119) and add two new handlers. Add imports near top:

```python
from app.database import get_db
from app.services.manipulation.lifecycle import ManipulationLifecycleTracker
from app.services.manipulation.strategy_impact import compute_strategy_impact

_LIFECYCLE_TRACKER = ManipulationLifecycleTracker()

LAYER_KEYS = ("A_price", "B_orderbook", "C_onchain", "D_social", "E_cross_market")


def _risk_level_from_stage(stage: str) -> str:
    if stage in ("distribute", "collapse"):
        return "high"
    if stage == "markup":
        return "medium"
    return "low"


def _completeness(layers: dict | None) -> float:
    if not layers:
        return 0.0
    available = sum(1 for k in LAYER_KEYS if layers.get(k) and layers[k].get("available"))
    return round(available / len(LAYER_KEYS), 4)


def _build_case_detail_v2(case: dict) -> dict:
    layers = case.get("evidence_layers")
    completeness = _completeness(layers)
    max_confidence = round(min(completeness * 1.2, 1.0), 4)
    dual = _LIFECYCLE_TRACKER.generate_dual_signal(case["lifecycle_stage"])
    return {
        "id": case["id"],
        "symbol": case["symbol"],
        "market": case["market"],
        "manipulation_type": case["manipulation_type"],
        "lifecycle_stage": case["lifecycle_stage"],
        "confidence": case["confidence"],
        "risk_level": _risk_level_from_stage(case["lifecycle_stage"]),
        "evidence": case.get("evidence", {}),
        "evidence_layers": layers,
        "completeness": completeness,
        "max_confidence": max_confidence,
        "timeline": case.get("timeline", []),
        "trading_signal": dual,
        "affected_symbols": [case["symbol"]],
        "sources": [{
            "type": case.get("source", "rule_engine"),
            "rule_id": case["manipulation_type"],
            "version": "v1",
        }],
        "outcome": case.get("outcome") or {},
        "auto_discovered": case.get("auto_discovered", True),
        "source": case.get("source", "rule_engine"),
        "created_at": case["created_at"],
        "updated_at": case["updated_at"],
        "completed_at": case.get("completed_at"),
    }
```

Replace existing `get_case`:

```python
@router.get("/cases/{case_id}")
async def get_case(case_id: str):
    try:
        repo = _get_case_repo()
        case = repo.get_case(case_id)
        if not case:
            raise HTTPException(404, "Case not found")
        return _build_case_detail_v2(case)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Get case failed: %s", exc)
        raise HTTPException(status_code=503, detail={
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        })


@router.get("/cases/{case_id}/strategy-impact")
async def get_strategy_impact(case_id: str, db: Session = Depends(get_db)):
    try:
        repo = _get_case_repo()
        case = repo.get_case(case_id)
        if not case:
            raise HTTPException(404, "Case not found")
        return compute_strategy_impact(case, db)
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Strategy impact failed: %s", exc)
        return {
            "case_id": case_id,
            "affected_strategies": [],
            "total_affected": 0,
            "total_protected": 0,
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        }


@router.get("/cases/{case_id}/similar")
async def get_similar(case_id: str, top_n: int = 5):
    try:
        repo = _get_case_repo()
        case = repo.get_case(case_id)
        if not case:
            raise HTTPException(404, "Case not found")
        similar = repo.find_similar(case_id, top_n=top_n)
        return {"case_id": case_id, "similar": similar, "total": len(similar)}
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("Similar cases failed: %s", exc)
        return {
            "case_id": case_id,
            "similar": [],
            "total": 0,
            "state": "data_source_unavailable",
            "reason_codes": ["data_source_unavailable", type(exc).__name__],
        }
```

- [ ] **Step 4: Run tests to verify pass**

Run: `cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py -q`
Expected: all pass (including new V2 tests).

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/manipulation.py backend/tests/test_manipulation_lifecycle.py
git commit -m "feat(manipulation): /cases/{id} v2 + strategy-impact + similar endpoints"
```

---

### Task 7: WebSocket `/stream` endpoint + main.py registration

**Files:**
- Create: `backend/app/routers/manipulation_ws.py`
- Modify: `backend/app/main.py` (register router)
- Test: `backend/tests/test_manipulation_lifecycle.py` (append `TestManipulationStream`)

**Interfaces:**
- Produces: `GET /api/v2/manipulation/stream` (WebSocket). On connect: sends `{"type":"snapshot","ts":"...","active_cases":[<radar summary>]}`. Then forwards `pubsub` events. Heartbeat every 30s. Disconnect cleans up subscriber queue.

- [ ] **Step 1: Write the failing test**

Append to `backend/tests/test_manipulation_lifecycle.py`:

```python
class TestManipulationStream:
    def test_stream_sends_snapshot_and_forwards_stage_change(self):
        from fastapi.testclient import TestClient
        from app.main import app
        from app.routers.manipulation import _get_case_repo
        client = TestClient(app)
        with client.websocket_connect("/api/v2/manipulation/stream") as ws:
            snap = ws.receive_json()
            assert snap["type"] == "snapshot"
            assert "active_cases" in snap
            # Trigger an event from inside the same process — pubsub will fan out
            repo = _get_case_repo()
            case = repo.create_case(symbol="DOGE/USDT", market="crypto",
                                    manipulation_type="M8", confidence=0.4, evidence={})
            evt = ws.receive_json()
            assert evt["type"] == "new_case"
            repo.update_stage(case["id"], "markup", confidence=0.6)
            evt2 = ws.receive_json()
            assert evt2["type"] == "stage_change"
            assert evt2["new_stage"] == "markup"
```

- [ ] **Step 2: Run test to verify it fails**

`cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py::TestManipulationStream -v`
Expected: FAIL with 404 / handshake refusal.

- [ ] **Step 3: Create `backend/app/routers/manipulation_ws.py`**

```python
"""WebSocket route for Manipulation Radar real-time events."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.services.manipulation.pubsub import subscribe, unsubscribe

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v2/manipulation", tags=["manipulation-radar-ws"])


def _snapshot_payload() -> dict:
    try:
        from app.routers.manipulation import _get_case_repo
        repo = _get_case_repo()
        overview = repo.get_radar_overview()
        return {
            "type": "snapshot",
            "ts": datetime.now(timezone.utc).isoformat(),
            "active_cases": overview.get("active_cases", []),
        }
    except Exception as exc:
        logger.warning("Snapshot build failed: %s", exc)
        return {"type": "snapshot", "ts": datetime.now(timezone.utc).isoformat(), "active_cases": []}


@router.websocket("/stream")
async def manipulation_stream(websocket: WebSocket) -> None:
    await websocket.accept()
    queue = subscribe()
    try:
        await websocket.send_json(_snapshot_payload())
        while True:
            try:
                msg = await asyncio.wait_for(queue.get(), timeout=30.0)
                await websocket.send_json(msg)
            except asyncio.TimeoutError:
                await websocket.send_json({
                    "type": "heartbeat",
                    "ts": datetime.now(timezone.utc).isoformat(),
                })
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.exception("Manipulation WS error: %s", exc)
    finally:
        unsubscribe(queue)
```

- [ ] **Step 4: Register router in `backend/app/main.py`**

Find the existing block where `manipulation` router is registered (`app.include_router(manipulation.router)`) and add immediately after it:

```python
from app.routers.manipulation_ws import router as manipulation_ws_router
app.include_router(manipulation_ws_router)
```

- [ ] **Step 5: Run tests to verify pass**

Run: `cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py::TestManipulationStream -v`
Expected: 1 passed.

Then full pytest: `cd backend && python3 -m pytest tests/test_manipulation_lifecycle.py -q`.

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/manipulation_ws.py backend/app/main.py backend/tests/test_manipulation_lifecycle.py
git commit -m "feat(manipulation): WebSocket /stream — snapshot + pubsub forwarding + heartbeat"
```

---

### Task 8: Phase P1 verification

- [ ] **Step 1: Full backend test run**

`cd backend && python3 -m pytest tests/ -q`
Expected: all pass (coverage ≥ 30%).

- [ ] **Step 2: Curl smoke**

Start backend: `cd backend && python3 run.py` (background or separate terminal).
Verify:
```bash
curl -s http://localhost:8000/api/v2/manipulation/historical-scan -X POST -d 'symbol=SOL/USDT' | head -50
curl -s http://localhost:8000/api/v2/manipulation/cases | python3 -m json.tool | head -30
# Pick a returned case id
curl -s http://localhost:8000/api/v2/manipulation/cases/<id> | python3 -m json.tool | head -40
curl -s http://localhost:8000/api/v2/manipulation/cases/<id>/strategy-impact | python3 -m json.tool
curl -s http://localhost:8000/api/v2/manipulation/cases/<id>/similar | python3 -m json.tool
```
Expected: all endpoints return JSON; `cases/{id}` includes `evidence_layers`, `trading_signal: {conservative, aggressive}`, `completeness`, `max_confidence`.

- [ ] **Step 3: Commit nothing (verification only)**

---

## Phase P2 — macOS Models, API Service, ViewModel Extensions

### Task 9: macOS Codable models for v2 detail / strategy impact / similar / stream events

**Files:**
- Modify: `macos-app/AlphaLoop/Services/APIManipulation.swift`

**Interfaces:**
- Produces (all Codable):
  - `EvidenceLayerFeaturePayload`, `EvidenceLayerPayload`, `EvidenceLayersBlock` (CodingKeys remap `A_price` etc.)
  - `DualTradingSignalPayload { conservative, aggressive: ManipulationTradingSignal }`
  - `ManipulationFilterStatusPayload`, `AffectedStrategyPayload`, `StrategyImpactResponsePayload`
  - `SimilarCaseOutcomePayload`, `SimilarCasePayload`, `SimilarCasesResponsePayload`
  - `SourceTag`
  - `ManipulationStreamEvent` — single struct with optional fields for `new_case` / `stage_change` / `heartbeat` / `snapshot`
  - Upgraded `ManipulationCaseDetail` with `evidenceLayers`, `completeness`, `maxConfidence`, `riskLevel`, `affectedSymbols`, `sources`, `tradingSignal: DualTradingSignalPayload?`.

- [ ] **Step 1: Append new Codable types in `APIManipulation.swift` before `MARK: - Mock Data`**

```swift
// MARK: - v2 Narrative Refactor Models

struct EvidenceLayerFeaturePayload: Codable, Hashable {
    var name: String = ""
    var value: Double = 0
    var percentile: Double? = nil
    var zscore: Double? = nil
}

struct EvidenceLayerPayload: Codable, Hashable {
    var available: Bool = false
    var dataQuality: Double = 0
    var score: Double? = nil
    var features: [EvidenceLayerFeaturePayload] = []
    var reason: String? = nil

    enum CodingKeys: String, CodingKey {
        case available, score, features, reason
        case dataQuality = "data_quality"
    }
}

struct EvidenceLayersBlock: Codable, Hashable {
    var aPrice: EvidenceLayerPayload? = nil
    var bOrderbook: EvidenceLayerPayload? = nil
    var cOnchain: EvidenceLayerPayload? = nil
    var dSocial: EvidenceLayerPayload? = nil
    var eCrossMarket: EvidenceLayerPayload? = nil

    enum CodingKeys: String, CodingKey {
        case aPrice = "A_price"
        case bOrderbook = "B_orderbook"
        case cOnchain = "C_onchain"
        case dSocial = "D_social"
        case eCrossMarket = "E_cross_market"
    }

    var ordered: [(key: String, layer: EvidenceLayerPayload?)] {
        [("A_price", aPrice), ("B_orderbook", bOrderbook),
         ("C_onchain", cOnchain), ("D_social", dSocial),
         ("E_cross_market", eCrossMarket)]
    }
}

struct DualTradingSignalPayload: Codable, Hashable {
    var conservative: ManipulationTradingSignal = ManipulationTradingSignal()
    var aggressive: ManipulationTradingSignal = ManipulationTradingSignal()
}

struct ManipulationFilterStatusPayload: Codable, Hashable {
    var enabled: Bool = false
    var wouldBlock: Bool = false
    var reasonCodes: [String] = []

    enum CodingKeys: String, CodingKey {
        case enabled
        case wouldBlock = "would_block"
        case reasonCodes = "reason_codes"
    }
}

struct AffectedStrategyPayload: Codable, Hashable, Identifiable {
    var id: String { strategyId }
    var strategyId: String = ""
    var name: String = ""
    var matchesSymbols: [String] = []
    var manipulationFilter: ManipulationFilterStatusPayload = ManipulationFilterStatusPayload()

    enum CodingKeys: String, CodingKey {
        case name
        case strategyId = "strategy_id"
        case matchesSymbols = "matches_symbols"
        case manipulationFilter = "manipulation_filter"
    }
}

struct StrategyImpactResponsePayload: Codable, Hashable {
    var caseId: String = ""
    var affectedStrategies: [AffectedStrategyPayload] = []
    var totalAffected: Int = 0
    var totalProtected: Int = 0

    enum CodingKeys: String, CodingKey {
        case caseId = "case_id"
        case affectedStrategies = "affected_strategies"
        case totalAffected = "total_affected"
        case totalProtected = "total_protected"
    }
}

struct SimilarCaseOutcomePayload: Codable, Hashable {
    var peakChange: Double? = nil
    var collapseDepth: Double? = nil
    var durationDays: Double? = nil

    enum CodingKeys: String, CodingKey {
        case peakChange = "peak_change"
        case collapseDepth = "collapse_depth"
        case durationDays = "duration_days"
    }
}

struct SimilarCasePayload: Codable, Hashable, Identifiable {
    var id: String = ""
    var symbol: String = ""
    var manipulationType: String = ""
    var similarity: Double = 0
    var outcome: SimilarCaseOutcomePayload? = nil
    var completedAt: String? = nil

    enum CodingKeys: String, CodingKey {
        case id, symbol, similarity, outcome
        case manipulationType = "manipulation_type"
        case completedAt = "completed_at"
    }
}

struct SimilarCasesResponsePayload: Codable, Hashable {
    var caseId: String = ""
    var similar: [SimilarCasePayload] = []
    var total: Int = 0

    enum CodingKeys: String, CodingKey {
        case similar, total
        case caseId = "case_id"
    }
}

struct SourceTag: Codable, Hashable {
    var type: String = ""
    var ruleId: String? = nil
    var version: String? = nil

    enum CodingKeys: String, CodingKey {
        case type
        case ruleId = "rule_id"
        case version
    }
}

struct ManipulationStreamEvent: Codable {
    var type: String = ""
    var caseId: String? = nil
    var symbol: String? = nil
    var manipulationType: String? = nil
    var initialStage: String? = nil
    var oldStage: String? = nil
    var newStage: String? = nil
    var confidence: Double? = nil
    var timestamp: String? = nil
    var ts: String? = nil
    var activeCases: [ManipulationCaseSummary]? = nil

    enum CodingKeys: String, CodingKey {
        case type, symbol, confidence, timestamp, ts
        case caseId = "case_id"
        case manipulationType = "manipulation_type"
        case initialStage = "initial_stage"
        case oldStage = "old_stage"
        case newStage = "new_stage"
        case activeCases = "active_cases"
    }
}
```

- [ ] **Step 2: Replace `ManipulationCaseDetail` struct (current lines 86-108)**

```swift
struct ManipulationCaseDetail: Codable, Identifiable {
    var id: String = ""
    var symbol: String = ""
    var market: String = "crypto"
    var manipulationType: String = ""
    var lifecycleStage: String = "suspected"
    var confidence: Double = 0
    var riskLevel: String = "medium"
    var evidence: [String: Double] = [:]
    var evidenceLayers: EvidenceLayersBlock? = nil
    var completeness: Double = 0
    var maxConfidence: Double = 1.0
    var timeline: [ManipulationStageEntry] = []
    var outcome: [String: Double] = [:]
    var tradingSignal: DualTradingSignalPayload? = nil
    var affectedSymbols: [String] = []
    var sources: [SourceTag] = []
    var createdAt: String = ""
    var updatedAt: String = ""

    enum CodingKeys: String, CodingKey {
        case id, symbol, market, evidence, timeline, outcome, confidence, sources
        case manipulationType = "manipulation_type"
        case lifecycleStage = "lifecycle_stage"
        case riskLevel = "risk_level"
        case evidenceLayers = "evidence_layers"
        case completeness
        case maxConfidence = "max_confidence"
        case tradingSignal = "trading_signal"
        case affectedSymbols = "affected_symbols"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
```

- [ ] **Step 3: Build to confirm syntax (mock still references old shape — fix in Task 10)**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: most errors localized to `MockManipulation.caseDetail` (uses old `tradingSignal:` init). That is fixed in Task 10. Other unrelated parts must still compile.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Services/APIManipulation.swift
git commit -m "feat(macos): add v2 Codable models — evidence layers, dual signal, strategy impact, similar"
```

---

### Task 10: API service methods + updated mocks

**Files:**
- Modify: `macos-app/AlphaLoop/Services/APIManipulation.swift`

**Interfaces:**
- Produces: `APIManipulation.getStrategyImpact(_:)`, `APIManipulation.getSimilarCases(_:topN:)`, updated `MockManipulation.caseDetail` + new factories `strategyImpact(caseId:)`, `similar(caseId:)`.

- [ ] **Step 1: Rewrite `MockManipulation.caseDetail` inside `enum MockManipulation` (current lines 146-159)**

```swift
    static var caseDetail: ManipulationCaseDetail {
        ManipulationCaseDetail(
            id: "mock-1", symbol: "SOL/USDT", market: "crypto",
            manipulationType: "M5", lifecycleStage: "markup", confidence: 0.78,
            riskLevel: "medium",
            evidence: ["pump_dump": 65, "volume_zscore": 55],
            evidenceLayers: EvidenceLayersBlock(
                aPrice: EvidenceLayerPayload(available: true, dataQuality: 0.95, score: 0.78,
                    features: [
                        EvidenceLayerFeaturePayload(name: "volume_zscore", value: 2.4, percentile: 0.92),
                        EvidenceLayerFeaturePayload(name: "price_range_spike", value: 1.6, percentile: 0.78),
                    ]),
                bOrderbook: EvidenceLayerPayload(available: true, dataQuality: 0.60, score: 0.42,
                    features: [EvidenceLayerFeaturePayload(name: "depth_zscore", value: 0.9, percentile: 0.58)]),
                cOnchain: EvidenceLayerPayload(available: true, dataQuality: 0.55, score: 0.65,
                    features: [EvidenceLayerFeaturePayload(name: "top10_concentration", value: 0.71, percentile: 0.88)]),
                dSocial: EvidenceLayerPayload(available: false, dataQuality: 0.10, score: nil,
                    features: [], reason: "no adapter configured"),
                eCrossMarket: EvidenceLayerPayload(available: true, dataQuality: 0.85, score: 0.89,
                    features: [EvidenceLayerFeaturePayload(name: "funding_rate_zscore", value: 2.8, percentile: 0.94)])
            ),
            completeness: 0.8, maxConfidence: 0.96,
            timeline: [
                ManipulationStageEntry(stage: "suspected", enteredAt: "2026-06-14T08:00:00Z", confidence: 0.45),
                ManipulationStageEntry(stage: "accumulate", enteredAt: "2026-06-14T16:00:00Z", confidence: 0.62),
                ManipulationStageEntry(stage: "markup", enteredAt: "2026-06-15T10:00:00Z", confidence: 0.78),
            ],
            tradingSignal: DualTradingSignalPayload(
                conservative: ManipulationTradingSignal(
                    action: "CAUTION", direction: "none", sizing: "none", stopLoss: "none",
                    rationale: "Manipulation markup underway — if holding, set strict risk limits",
                    riskLevel: "high"),
                aggressive: ManipulationTradingSignal(
                    action: "RIDE", direction: "long", sizing: "medium", stopLoss: "trailing",
                    rationale: "Markup confirmed — ride with trailing stop",
                    riskLevel: "medium")
            ),
            affectedSymbols: ["SOL/USDT", "SOL/USDC"],
            sources: [SourceTag(type: "rule_engine", ruleId: "M5_CROSS_MARKET", version: "v1.2")],
            createdAt: "2026-06-14T08:00:00Z", updatedAt: "2026-06-15T10:00:00Z"
        )
    }

    static func strategyImpact(caseId: String) -> StrategyImpactResponsePayload {
        StrategyImpactResponsePayload(
            caseId: caseId,
            affectedStrategies: [
                AffectedStrategyPayload(
                    strategyId: "mock-strat-1", name: "BTC Momentum v3",
                    matchesSymbols: ["SOL/USDT"],
                    manipulationFilter: ManipulationFilterStatusPayload(
                        enabled: true, wouldBlock: true,
                        reasonCodes: ["confidence_exceeds_max_score", "confidence=0.78", "max_score=0.50"])),
                AffectedStrategyPayload(
                    strategyId: "mock-strat-2", name: "SOL Breakout v2",
                    matchesSymbols: ["SOL/USDT"],
                    manipulationFilter: ManipulationFilterStatusPayload(
                        enabled: false, wouldBlock: false, reasonCodes: ["filter_disabled"])),
            ],
            totalAffected: 2, totalProtected: 1
        )
    }

    static func similar(caseId: String) -> SimilarCasesResponsePayload {
        SimilarCasesResponsePayload(
            caseId: caseId,
            similar: [
                SimilarCasePayload(
                    id: "hist-1", symbol: "LUNA/USDT", manipulationType: "M5", similarity: 0.87,
                    outcome: SimilarCaseOutcomePayload(peakChange: 2.4, collapseDepth: -0.92, durationDays: 14),
                    completedAt: "2025-08-15T00:00:00Z"),
                SimilarCasePayload(
                    id: "hist-2", symbol: "AVAX/USDT", manipulationType: "M5", similarity: 0.74,
                    outcome: SimilarCaseOutcomePayload(peakChange: 1.6, collapseDepth: -0.55, durationDays: 9),
                    completedAt: "2024-11-22T00:00:00Z"),
            ],
            total: 2
        )
    }
```


- [ ] **Step 2: Add API methods inside `APIManipulation` (after `getSignals`)**

```swift
    func getStrategyImpact(_ caseId: String) async throws -> StrategyImpactResponsePayload {
        try await client.get("/api/v2/manipulation/cases/\(caseId)/strategy-impact") {
            MockManipulation.strategyImpact(caseId: caseId)
        }
    }

    func getSimilarCases(_ caseId: String, topN: Int = 5) async throws -> SimilarCasesResponsePayload {
        try await client.get("/api/v2/manipulation/cases/\(caseId)/similar?top_n=\(topN)") {
            MockManipulation.similar(caseId: caseId)
        }
    }
```

- [ ] **Step 3: Build**

Run: `cd macos-app && swift build`
Expected: clean build.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Services/APIManipulation.swift
git commit -m "feat(macos): APIManipulation getStrategyImpact/getSimilarCases + v2 mocks"
```

---


### Task 11: WebSocket client `ManipulationStreamClient` (actor)

**Files:**
- Create: `macos-app/AlphaLoop/Services/ManipulationStreamClient.swift`

**Interfaces:**
- Produces:
  - `actor ManipulationStreamClient`
  - `init(client: NetworkClientProtocol)`
  - `func events() -> AsyncStream<ManipulationStreamEvent>` — empty stream for `MockNetworkClient`; `ws://localhost:8000/api/v2/manipulation/stream` for live mode.
  - `func stop()` — closes socket and stops reconnect loop.

- [ ] **Step 1: Create `ManipulationStreamClient.swift`**

```swift
// ManipulationStreamClient.swift — WebSocket client for Manipulation Radar real-time events.

import Foundation

actor ManipulationStreamClient {
    private let client: NetworkClientProtocol
    private var task: URLSessionWebSocketTask?
    private var stopped = false

    init(client: NetworkClientProtocol) {
        self.client = client
    }

    func events() -> AsyncStream<ManipulationStreamEvent> {
        guard client is LiveNetworkClient else {
            return AsyncStream { continuation in continuation.finish() }
        }
        let url = URL(string: "ws://localhost:8000/api/v2/manipulation/stream")!
        return AsyncStream { continuation in
            Task { await self.run(url: url, continuation: continuation) }
            continuation.onTermination = { _ in Task { await self.stop() } }
        }
    }

    func stop() {
        stopped = true
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }

    private func run(url: URL, continuation: AsyncStream<ManipulationStreamEvent>.Continuation) async {
        while !stopped {
            let session = URLSession(configuration: .default)
            let socket = session.webSocketTask(with: url)
            task = socket
            socket.resume()
            do {
                while !stopped {
                    let message = try await socket.receive()
                    switch message {
                    case .string(let text):
                        guard let data = text.data(using: .utf8) else { continue }
                        if let event = try? JSONDecoder().decode(ManipulationStreamEvent.self, from: data) {
                            continuation.yield(event)
                        }
                    case .data(let data):
                        if let event = try? JSONDecoder().decode(ManipulationStreamEvent.self, from: data) {
                            continuation.yield(event)
                        }
                    @unknown default:
                        break
                    }
                }
            } catch {
                socket.cancel()
                task = nil
                if stopped { break }
                try? await Task.sleep(for: .seconds(5))
            }
        }
        continuation.finish()
    }
}
```

- [ ] **Step 2: Build**

Run: `cd macos-app && swift build`
Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Services/ManipulationStreamClient.swift
git commit -m "feat(macos): add ManipulationStreamClient for manipulation radar stream"
```

---

### Task 12: ViewModel state — focus switching + three endpoint load + live updates

**Files:**
- Modify: `macos-app/AlphaLoop/ViewModels/ManipulationViewModel.swift`
- Test: `macos-app/Tests/ViewModelTests.swift`

**Interfaces:**
- Produces ViewModel state:
  - `var focusedCaseId: String?`
  - `var focusedDetail: ManipulationCaseDetail?`
  - `var strategyImpact: StrategyImpactResponsePayload?`
  - `var similarCases: SimilarCasesResponsePayload?`
  - `var streamEvents: [ManipulationStreamEvent] = []`
  - `var strategyImpactError: String?`, `var similarError: String?`, `var detailError: String?`
- Produces methods:
  - `func focusCase(_ caseId: String) async`
  - `func startLiveUpdates()`
  - `func stopLiveUpdates()`
- Keeps `userProfile` property for legacy `getSignals(userProfile:)`; removes UI use of `toggleUserProfile()`.

- [ ] **Step 1: Add failing tests**

Append to `macos-app/Tests/ViewModelTests.swift`:

```swift
@MainActor @Test func manipulationViewModelFocusCaseLoadsThreeEndpoints() async {
    let client = MockNetworkClient()
    let vm = ManipulationViewModel(client: client)
    await vm.loadRadar()
    await vm.focusCase("mock-1")
    #expect(vm.focusedCaseId == "mock-1")
    #expect(vm.focusedDetail?.id == "mock-1")
    #expect(vm.strategyImpact?.caseId == "mock-1")
    #expect(vm.similarCases?.caseId == "mock-1")
}

@MainActor @Test func manipulationViewModelLiveUpdatesNoOpInMockMode() async {
    let client = MockNetworkClient()
    let vm = ManipulationViewModel(client: client)
    vm.startLiveUpdates()
    vm.stopLiveUpdates()
    #expect(vm.error == nil)
}
```

- [ ] **Step 2: Run tests and verify failure**

Run: `cd macos-app && swift test --filter manipulationViewModelFocusCaseLoadsThreeEndpoints`
Expected: FAIL because `focusCase` is missing.

- [ ] **Step 3: Replace ViewModel implementation**

Use this shape in `ManipulationViewModel.swift` (preserve `scan()`, `sortedScores`, `riskOrder` helpers):

```swift
@Observable
@MainActor
final class ManipulationViewModel {
    var radarOverview: ManipulationRadarOverview?
    var selectedCase: ManipulationCaseDetail? { focusedDetail }
    var focusedCaseId: String?
    var focusedDetail: ManipulationCaseDetail?
    var strategyImpact: StrategyImpactResponsePayload?
    var similarCases: SimilarCasesResponsePayload?
    var alerts: [ManipulationAlertItem] = []
    var streamEvents: [ManipulationStreamEvent] = []
    var userProfile: String = "conservative"
    var scanSymbol: String = ""
    var scores: [ManipulationScoreV2] = []
    var isLoading = false
    var error: String?
    var detailError: String?
    var strategyImpactError: String?
    var similarError: String?
    var errorHandler: ErrorHandler?

    private let api: APIManipulation
    private let streamClient: ManipulationStreamClient
    private var pollingTask: Task<Void, Never>?
    private var streamTask: Task<Void, Never>?

    init(client: NetworkClientProtocol) {
        self.api = APIManipulation(client: client)
        self.streamClient = ManipulationStreamClient(client: client)
    }

    func load() async { await loadRadar() }

    func loadRadar() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let overviewTask = api.getRadarOverview()
            async let alertsTask = api.getAlerts()
            async let scoresTask = api.listScores(limit: 20)
            let overview = try await overviewTask
            radarOverview = overview
            alerts = try await alertsTask
            scores = (try? await scoresTask) ?? []
            if focusedCaseId == nil, let first = overview.activeCases.first {
                await focusCase(first.id)
            }
        } catch {
            errorHandler?.handle(error, context: "加载操纵雷达")
            self.error = error.localizedDescription
        }
    }

    func focusCase(_ caseId: String) async {
        focusedCaseId = caseId
        async let detailTask = loadFocusedDetail(caseId)
        async let impactTask = loadStrategyImpact(caseId)
        async let similarTask = loadSimilar(caseId)
        _ = await (detailTask, impactTask, similarTask)
    }

    private func loadFocusedDetail(_ caseId: String) async {
        do { focusedDetail = try await api.getCaseDetail(caseId); detailError = nil }
        catch { detailError = error.localizedDescription }
    }

    private func loadStrategyImpact(_ caseId: String) async {
        do { strategyImpact = try await api.getStrategyImpact(caseId); strategyImpactError = nil }
        catch { strategyImpactError = error.localizedDescription; strategyImpact = nil }
    }

    private func loadSimilar(_ caseId: String) async {
        do { similarCases = try await api.getSimilarCases(caseId); similarError = nil }
        catch { similarError = error.localizedDescription; similarCases = nil }
    }

    func startLiveUpdates() {
        pollingTask?.cancel()
        streamTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await self?.loadRadar()
            }
        }
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await event in await streamClient.events() {
                await self.handleStreamEvent(event)
            }
        }
    }

    func stopLiveUpdates() {
        pollingTask?.cancel(); pollingTask = nil
        streamTask?.cancel(); streamTask = nil
        Task { await streamClient.stop() }
    }

    func startPolling() { startLiveUpdates() }
    func stopPolling() { stopLiveUpdates() }

    private func handleStreamEvent(_ event: ManipulationStreamEvent) async {
        streamEvents.insert(event, at: 0)
        if event.type == "new_case" || event.type == "stage_change" {
            await loadRadar()
            if let caseId = event.caseId, caseId == focusedCaseId {
                await focusCase(caseId)
            }
        }
    }
}
```

- [ ] **Step 4: Re-add existing `scan()`, `sortedScores`, and `riskOrder`**

Keep the current implementations from `ManipulationViewModel.swift:32-43` and `95-108` unchanged.

- [ ] **Step 5: Run tests**

Run: `cd macos-app && swift test --filter manipulationViewModel`
Expected: new tests pass. If the suite still crashes due to unrelated existing SIGTRAP, document in commit body and verify `swift build`.

- [ ] **Step 6: Commit**

```bash
git add macos-app/AlphaLoop/ViewModels/ManipulationViewModel.swift macos-app/Tests/ViewModelTests.swift
git commit -m "feat(macos): ManipulationViewModel focusCase + strategy impact/similar/live updates"
```

---


## Phase P3 — UI Nine-Section Narrative Flow

### Task 13: L10n keys for all new manipulation sections

**Files:**
- Modify: `macos-app/AlphaLoop/Localization/L10n+Manipulation.swift`

**Interfaces:**
- Produces all keys referenced by Tasks 14-21:
  - uncertainty: `disclaimer`, `likely`, `evidenceConsistentWith`, `dataUnavailable`, `dataQuality`, `dataCompleteness`, `maxConfidence`
  - section titles: `verdict`, `lifecycleTimeline`, `evidenceMatrix`, `whaleConcentration`, `crossMarketPressure`, `socialAcceleration`, `defenseStrategyImpact`, `similarHistoricalCases`
  - layer labels: `layerPrice`, `layerOrderbook`, `layerOnchain`, `layerSocial`, `layerCrossMarket`
  - defense labels: `affectedSymbols`, `strategyImpact`, `wouldBlock`, `filterDisabled`, `openStrategyRisk`, `openStrategyWorkspace`, `conservativeProfile`, `aggressiveProfile`
  - feature labels: `featTop10Concentration`, `featExchangeInflow`, `featFundingRate`, `featOpenInterest`, `featLongShortRatio`, `featBasis`

- [ ] **Step 1: Append L10n keys**

Add to `enum Manipulation`:

```swift
        // MARK: - Narrative Refactor
        static var disclaimer: String { zh("操纵雷达是统计推断系统，输出“基于证据的怀疑”而非“定罪”。请结合多源信息独立判断。", en: "Manipulation radar is a statistical inference system; it surfaces evidence-based suspicions, not verdicts.") }
        static var likely: String { zh("疑似", en: "Likely") }
        static var evidenceConsistentWith: String { zh("证据指向", en: "Evidence consistent with") }
        static var dataUnavailable: String { zh("数据不可用", en: "Data unavailable") }
        static var dataQuality: String { zh("数据质量", en: "Data quality") }
        static var dataCompleteness: String { zh("数据完整度", en: "Data completeness") }
        static var maxConfidence: String { zh("置信上限", en: "Max confidence") }
        static var verdict: String { zh("判定", en: "VERDICT") }
        static var lifecycleTimeline: String { zh("生命周期", en: "LIFECYCLE") }
        static var evidenceMatrix: String { zh("证据矩阵", en: "EVIDENCE MATRIX") }
        static var whaleConcentration: String { zh("巨鲸与筹码集中", en: "WHALE & CONCENTRATION") }
        static var crossMarketPressure: String { zh("跨市场压力", en: "CROSS-MARKET PRESSURE") }
        static var socialAcceleration: String { zh("社交加速", en: "SOCIAL ACCELERATION") }
        static var defenseStrategyImpact: String { zh("防御与策略联动", en: "DEFENSE & STRATEGY IMPACT") }
        static var similarHistoricalCases: String { zh("相似历史案例", en: "SIMILAR HISTORICAL CASES") }
        static var layerPrice: String { zh("Layer A · 价格量能", en: "Layer A · Price/Volume") }
        static var layerOrderbook: String { zh("Layer B · 盘口流动性", en: "Layer B · Orderbook Liquidity") }
        static var layerOnchain: String { zh("Layer C · 链上", en: "Layer C · On-Chain") }
        static var layerSocial: String { zh("Layer D · 社交新闻", en: "Layer D · Social & News") }
        static var layerCrossMarket: String { zh("Layer E · 跨市场", en: "Layer E · Cross-Market") }
        static var affectedSymbols: String { zh("影响交易对", en: "Affected symbols") }
        static var strategyImpact: String { zh("当前策略联动", en: "Strategy impact") }
        static var wouldBlock: String { zh("将阻断", en: "Will block") }
        static var filterDisabled: String { zh("过滤器未启用", en: "Filter disabled") }
        static var openStrategyRisk: String { zh("跳转风控配置", en: "Open risk config") }
        static var openStrategyWorkspace: String { zh("编辑过滤器", en: "Edit filter") }
        static var conservativeProfile: String { zh("保守画像", en: "CONSERVATIVE") }
        static var aggressiveProfile: String { zh("激进画像", en: "AGGRESSIVE") }
        static var featTop10Concentration: String { zh("Top-10 集中度", en: "Top-10 concentration") }
        static var featExchangeInflow: String { zh("交易所充值", en: "Exchange inflow") }
        static var featFundingRate: String { zh("资金费率", en: "Funding rate") }
        static var featOpenInterest: String { zh("持仓量", en: "Open interest") }
        static var featLongShortRatio: String { zh("多空比", en: "Long/Short ratio") }
        static var featBasis: String { zh("现货-永续基差", en: "Spot-perp basis") }
```

- [ ] **Step 2: Build**

Run: `cd macos-app && swift build`
Expected: clean build.

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Localization/L10n+Manipulation.swift
git commit -m "feat(macos): add Manipulation Radar narrative L10n keys"
```

---

### Task 14: Shared manipulation view helpers — labels, colors, ring, layer labels

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/ManipulationUIHelpers.swift`

**Interfaces:**
- Produces:
  - `func manipulationTypeLabel(_ type: String) -> String`
  - `func manipulationStageLabel(_ stage: String) -> String`
  - `func manipulationSignalLabel(_ action: String) -> String`
  - `func manipulationStageColor(_ stage: String) -> Color`
  - `func manipulationLayerLabel(_ key: String) -> String`
  - `struct ManipulationConfidenceRing: View`
  - `struct QualityBadge: View`

- [ ] **Step 1: Create helper file**

```swift
import SwiftUI

func manipulationTypeLabel(_ type: String) -> String {
    switch type {
    case "M1": L10n.Manipulation.typeM1
    case "M2": L10n.Manipulation.typeM2
    case "M3": L10n.Manipulation.typeM3
    case "M4": L10n.Manipulation.typeM4
    case "M5": L10n.Manipulation.typeM5
    case "M6": L10n.Manipulation.typeM6
    case "M7": L10n.Manipulation.typeM7
    case "M8": L10n.Manipulation.typeM8
    default: type
    }
}

func manipulationStageLabel(_ stage: String) -> String {
    switch stage.lowercased() {
    case "suspected": L10n.Manipulation.stageSuspected
    case "accumulate": L10n.Manipulation.stageAccumulate
    case "markup": L10n.Manipulation.stageMarkup
    case "distribute": L10n.Manipulation.stageDistribute
    case "collapse": L10n.Manipulation.stageCollapse
    case "completed": L10n.Manipulation.stageCompleted
    case "false_alarm": L10n.Manipulation.stageFalseAlarm
    default: stage.uppercased()
    }
}

func manipulationSignalLabel(_ action: String) -> String {
    switch action.uppercased() {
    case "AMBUSH": L10n.Manipulation.signalAmbush
    case "RIDE": L10n.Manipulation.signalRide
    case "EXIT_OR_SHORT": L10n.Manipulation.signalExitOrShort
    case "AVOID": L10n.Manipulation.signalAvoid
    case "WATCH": L10n.Manipulation.signalWatch
    case "CAUTION": L10n.Manipulation.signalCaution
    case "EXIT": L10n.Manipulation.signalExit
    default: action
    }
}

func manipulationStageColor(_ stage: String) -> Color {
    switch stage.lowercased() {
    case "suspected": PulseColors.info
    case "accumulate": PulseColors.accent
    case "markup": PulseColors.success
    case "distribute": PulseColors.amber
    case "collapse": PulseColors.danger
    default: PulseColors.info
    }
}

func manipulationLayerLabel(_ key: String) -> String {
    switch key {
    case "A_price": L10n.Manipulation.layerPrice
    case "B_orderbook": L10n.Manipulation.layerOrderbook
    case "C_onchain": L10n.Manipulation.layerOnchain
    case "D_social": L10n.Manipulation.layerSocial
    case "E_cross_market": L10n.Manipulation.layerCrossMarket
    default: key
    }
}

struct ManipulationConfidenceRing: View {
    let value: Double
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.12), lineWidth: 8)
            Circle()
                .trim(from: 0, to: max(0, min(value, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(value * 100))%")
                .font(PulseFonts.tabular)
                .foregroundStyle(color)
        }
        .frame(width: 76, height: 76)
    }
}

struct QualityBadge: View {
    @Environment(PulseColors.self) private var colors
    let quality: Double
    var body: some View {
        Text("quality \(String(format: "%.2f", quality))")
            .font(PulseFonts.micro)
            .foregroundStyle(quality < 0.3 ? PulseColors.danger : colors.textMuted)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill((quality < 0.3 ? PulseColors.danger : PulseColors.info).opacity(0.10)))
    }
}
```

- [ ] **Step 2: Build** — `cd macos-app && swift build`

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Views/Manipulation/Components/ManipulationUIHelpers.swift
git commit -m "feat(macos): add Manipulation Radar UI helpers"
```

---


### Task 15: §0 `ActiveCasesStrip`

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/ActiveCasesStrip.swift`
- Modify: `macos-app/AlphaLoop/Views/Manipulation/CaseCardView.swift` — later delete or leave unused until Task 22 cleanup.

**Interfaces:**
- Consumes: `[ManipulationCaseSummary]`, `focusedCaseId: String?`, `onSelect: (String) -> Void`.
- Produces: horizontal scroll card strip; each card shows symbol, M-type, stage, confidence bar, selected border.

- [ ] **Step 1: Create component**

```swift
import SwiftUI

struct ActiveCasesStrip: View {
    let cases: [ManipulationCaseSummary]
    let focusedCaseId: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            TerminalLabel(text: L10n.Manipulation.activeCases)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PulseSpacing.sm) {
                    ForEach(cases) { item in
                        ActiveCasesStripCard(item: item, isSelected: item.id == focusedCaseId)
                            .onTapGesture { onSelect(item.id) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct ActiveCasesStripCard: View {
    @Environment(PulseColors.self) private var colors
    let item: ManipulationCaseSummary
    let isSelected: Bool

    var body: some View {
        KryptonCard(emphasis: isSelected ? .standard : .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                HStack {
                    Text(item.symbol)
                        .font(PulseFonts.captionMedium)
                        .foregroundStyle(colors.textPrimary)
                    Spacer()
                    Text(item.manipulationType)
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.amber)
                }
                Text("\(L10n.Manipulation.evidenceConsistentWith) \(manipulationTypeLabel(item.manipulationType))")
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
                    .lineLimit(1)
                HStack(spacing: PulseSpacing.xs) {
                    Text(manipulationStageLabel(item.lifecycleStage))
                        .font(PulseFonts.micro)
                        .foregroundStyle(manipulationStageColor(item.lifecycleStage))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(colors.border.opacity(0.25))
                            Capsule()
                                .fill(manipulationStageColor(item.lifecycleStage))
                                .frame(width: geo.size.width * max(0, min(item.confidence, 1)))
                        }
                    }
                    .frame(height: 4)
                    Text("\(Int(item.confidence * 100))%")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
            .frame(width: 240, alignment: .leading)
        }
        .overlay {
            RoundedRectangle(cornerRadius: PulseRadii.card)
                .stroke(isSelected ? PulseColors.accent.opacity(0.6) : .clear, lineWidth: 1)
        }
    }
}
```

- [ ] **Step 2: Build** — `cd macos-app && swift build`

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Views/Manipulation/Components/ActiveCasesStrip.swift
git commit -m "feat(macos): add Manipulation ActiveCasesStrip"
```

---

### Task 16: §1 `VerdictPanel`

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/VerdictPanel.swift`

**Interfaces:**
- Consumes: `ManipulationCaseDetail`.
- Produces: KryptonCard with probabilistic verdict sentence, M-type, lifecycle stage, confidence ring, data completeness N/5, max confidence.

- [ ] **Step 1: Create component**

```swift
import SwiftUI

struct VerdictPanel: View {
    @Environment(PulseColors.self) private var colors
    let detail: ManipulationCaseDetail

    private var availableLayerCount: Int {
        detail.evidenceLayers?.ordered.filter { $0.layer?.available == true }.count ?? 0
    }

    var body: some View {
        KryptonCard(emphasis: .standard) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                TerminalLabel(text: L10n.Manipulation.verdict)
                HStack(alignment: .center, spacing: PulseSpacing.lg) {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text("\(L10n.Manipulation.likely) \(manipulationTypeLabel(detail.manipulationType))")
                            .font(PulseFonts.displaySubheading)
                            .foregroundStyle(colors.textPrimary)
                        Text("\(L10n.Manipulation.evidenceConsistentWith) \(detail.manipulationType) · \(manipulationStageLabel(detail.lifecycleStage))")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                        HStack(spacing: PulseSpacing.xs) {
                            tag(detail.manipulationType, color: PulseColors.amber)
                            tag(manipulationStageLabel(detail.lifecycleStage), color: manipulationStageColor(detail.lifecycleStage))
                            tag(detail.riskLevel.uppercased(), color: detail.riskLevel == "high" ? PulseColors.danger : PulseColors.info)
                        }
                    }
                    Spacer()
                    ManipulationConfidenceRing(value: detail.confidence, color: manipulationStageColor(detail.lifecycleStage))
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        metric(L10n.Manipulation.dataCompleteness, "\(availableLayerCount)/5")
                        metric(L10n.Manipulation.maxConfidence, "\(Int(detail.maxConfidence * 100))%")
                    }
                }
                HStack(alignment: .top, spacing: PulseSpacing.xs) {
                    Text("ⓘ").font(PulseFonts.caption)
                    Text(L10n.Manipulation.disclaimer)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(PulseFonts.micro)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.10)))
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(PulseFonts.tabular).foregroundStyle(colors.textPrimary)
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
        }
    }
}
```

- [ ] **Step 2: Build** — `cd macos-app && swift build`

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Views/Manipulation/Components/VerdictPanel.swift
git commit -m "feat(macos): add Manipulation VerdictPanel with uncertainty copy"
```

---


### Task 17: §2 `LifecycleTimeline`

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/LifecycleTimeline.swift`
- Modify: `macos-app/AlphaLoop/Views/Manipulation/LifecycleIndicator.swift` (optional keep; no longer used by root)

**Interfaces:**
- Consumes: `currentStage: String`, `timeline: [ManipulationStageEntry]`.
- Produces: horizontal 5-stage timeline: suspected → accumulate → markup → distribute → collapse. Current stage has larger glowing node; reached stages solid; unreached stages muted outline.

- [ ] **Step 1: Create component**

```swift
import SwiftUI

struct LifecycleTimeline: View {
    @Environment(PulseColors.self) private var colors
    let currentStage: String
    let timeline: [ManipulationStageEntry]
    private let stages = ["suspected", "accumulate", "markup", "distribute", "collapse"]

    private var currentIndex: Int { stages.firstIndex(of: currentStage.lowercased()) ?? 0 }

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                TerminalLabel(text: L10n.Manipulation.lifecycleTimeline)
                HStack(spacing: 0) {
                    ForEach(Array(stages.enumerated()), id: \.offset) { index, stage in
                        node(stage: stage, index: index)
                        if index < stages.count - 1 { connector(after: index) }
                    }
                }
            }
        }
    }

    private func node(stage: String, index: Int) -> some View {
        let isCurrent = index == currentIndex
        let reached = index <= currentIndex
        let color = reached ? manipulationStageColor(stage) : colors.textMuted.opacity(0.35)
        let entry = timeline.last { $0.stage.lowercased() == stage }
        return VStack(spacing: PulseSpacing.xxs) {
            ZStack {
                if isCurrent { Circle().fill(color.opacity(0.18)).frame(width: 34, height: 34).blur(radius: 4) }
                Circle()
                    .fill(reached ? color : .clear)
                    .overlay(Circle().stroke(color, lineWidth: reached ? 0 : 1))
                    .frame(width: isCurrent ? 18 : 13, height: isCurrent ? 18 : 13)
            }
            Text(manipulationStageLabel(stage)).font(PulseFonts.micro).foregroundStyle(color)
            Text(entry?.enteredAt.prefix(10) ?? "—").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            Text("\(Int((entry?.confidence ?? 0) * 100))%").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
        }
        .frame(width: 132)
    }

    private func connector(after index: Int) -> some View {
        Rectangle()
            .fill(index < currentIndex ? manipulationStageColor(stages[index + 1]).opacity(0.55) : colors.border.opacity(0.25))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 46)
    }
}
```

- [ ] **Step 2: Build** — `cd macos-app && swift build`

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Views/Manipulation/Components/LifecycleTimeline.swift
git commit -m "feat(macos): add horizontal Manipulation lifecycle timeline"
```

---

### Task 18: §3 `EvidenceLayerMatrix`

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/EvidenceLayerMatrix.swift`

**Interfaces:**
- Consumes: `EvidenceLayersBlock?`.
- Produces: 5 layer rows with score bar, quality badge, available/unavailable state, expandable feature list. If data_quality < 0.3 or `available == false`, display `Data unavailable`.

- [ ] **Step 1: Create component**

```swift
import SwiftUI

struct EvidenceLayerMatrix: View {
    @Environment(PulseColors.self) private var colors
    let layers: EvidenceLayersBlock?
    @State private var expanded: Set<String> = []

    var body: some View {
        KryptonCard(emphasis: .standard) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                TerminalLabel(text: L10n.Manipulation.evidenceMatrix)
                ForEach(orderedLayers(), id: \.key) { key, layer in
                    layerRow(key: key, layer: layer)
                }
            }
        }
    }

    private func orderedLayers() -> [(key: String, layer: EvidenceLayerPayload?)] {
        layers?.ordered ?? [("A_price", nil), ("B_orderbook", nil), ("C_onchain", nil), ("D_social", nil), ("E_cross_market", nil)]
    }

    private func layerRow(key: String, layer: EvidenceLayerPayload?) -> some View {
        let available = (layer?.available == true) && (layer?.dataQuality ?? 0) >= 0.3
        let score = layer?.score ?? 0
        return VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Button {
                if expanded.contains(key) { expanded.remove(key) } else { expanded.insert(key) }
            } label: {
                HStack(spacing: PulseSpacing.sm) {
                    Text(manipulationLayerLabel(key)).font(PulseFonts.captionMedium).foregroundStyle(colors.textPrimary)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(colors.border.opacity(0.18))
                            Capsule().fill(available ? PulseColors.accent : colors.textMuted.opacity(0.25))
                                .frame(width: geo.size.width * max(0, min(score, 1)))
                        }
                    }
                    .frame(height: 6)
                    Text(available ? String(format: "%.2f", score) : "—")
                        .font(PulseFonts.tabular).foregroundStyle(colors.textPrimary)
                    QualityBadge(quality: layer?.dataQuality ?? 0)
                    if !available { Text(L10n.Manipulation.dataUnavailable).font(PulseFonts.micro).foregroundStyle(PulseColors.danger) }
                    Image(systemName: expanded.contains(key) ? "chevron.up" : "chevron.down")
                        .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                }
            }
            .buttonStyle(.plain)

            if expanded.contains(key) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(layer?.features ?? [], id: \.name) { feature in
                        HStack {
                            Text(feature.name).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                            Spacer()
                            Text(String(format: "%.2f", feature.value)).font(PulseFonts.micro).foregroundStyle(colors.textPrimary)
                            if let p = feature.percentile { Text("p\(Int(p * 100))").font(PulseFonts.micro).foregroundStyle(PulseColors.info) }
                        }
                    }
                    if (layer?.features ?? []).isEmpty {
                        Text(layer?.reason ?? L10n.Manipulation.dataUnavailable)
                            .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                    }
                }
                .padding(.leading, PulseSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, PulseSpacing.xs)
        .overlay(alignment: .bottom) { Rectangle().fill(colors.border.opacity(0.10)).frame(height: 1) }
    }
}
```

- [ ] **Step 2: Build** — `cd macos-app && swift build`

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Views/Manipulation/Components/EvidenceLayerMatrix.swift
git commit -m "feat(macos): add Manipulation EvidenceLayerMatrix"
```

---


### Task 19: §4/§5/§6 layer-detail panels (Whale, Cross-Market, Social)

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/WhaleConcentrationPanel.swift`
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/CrossMarketPressurePanel.swift`
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/SocialAccelerationPanel.swift`

**Interfaces:**
- Each consumes `EvidenceLayerPayload?`.
- Each renders a KryptonCard; if unavailable or `dataQuality < 0.3`, render a muted "Data unavailable" block.
- These are summary/detail cards only; no new backend fields required beyond `features`.

- [ ] **Step 1: Create `WhaleConcentrationPanel.swift`**

```swift
import SwiftUI

struct WhaleConcentrationPanel: View {
    @Environment(PulseColors.self) private var colors
    let layer: EvidenceLayerPayload?
    var body: some View {
        detailCard(title: L10n.Manipulation.whaleConcentration, color: PulseColors.amber)
    }
    private func detailCard(title: String, color: Color) -> some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                TerminalLabel(text: title)
                if layer?.available == true, (layer?.dataQuality ?? 0) >= 0.3 {
                    featureRows(features: layer?.features ?? [], color: color)
                    QualityBadge(quality: layer?.dataQuality ?? 0)
                } else {
                    unavailable(reason: layer?.reason)
                }
            }
        }
    }
    private func featureRows(features: [EvidenceLayerFeaturePayload], color: Color) -> some View {
        VStack(spacing: PulseSpacing.xs) {
            ForEach(features, id: \.name) { feature in
                HStack {
                    Text(feature.name).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                    Spacer()
                    Text(String(format: "%.2f", feature.value)).font(PulseFonts.tabular).foregroundStyle(color)
                }
            }
        }
    }
    private func unavailable(reason: String?) -> some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.Manipulation.dataUnavailable).font(PulseFonts.captionMedium).foregroundStyle(PulseColors.danger)
            Text(reason ?? L10n.Manipulation.disclaimer).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
        }
    }
}
```

- [ ] **Step 2: Create `CrossMarketPressurePanel.swift`**

Same structure, title `L10n.Manipulation.crossMarketPressure`, color `PulseColors.info`; keep file under 120 lines.

- [ ] **Step 3: Create `SocialAccelerationPanel.swift`**

Same structure, title `L10n.Manipulation.socialAcceleration`, color `PulseColors.accent`. For unavailable data, use `L10n.Manipulation.dataUnavailable` prominently because social layer is expected to be missing often.

- [ ] **Step 4: Build** — `cd macos-app && swift build`

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Views/Manipulation/Components/WhaleConcentrationPanel.swift \
        macos-app/AlphaLoop/Views/Manipulation/Components/CrossMarketPressurePanel.swift \
        macos-app/AlphaLoop/Views/Manipulation/Components/SocialAccelerationPanel.swift
git commit -m "feat(macos): add Manipulation layer detail panels"
```

---

### Task 20: §7 `DualProfileSignalPanel` with strategy-impact navigation

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/DualProfileSignalPanel.swift`

**Interfaces:**
- Consumes: `detail: ManipulationCaseDetail`, `impact: StrategyImpactResponsePayload?`, `onOpenRisk: () -> Void`, `onEditStrategy: () -> Void`.
- Produces: conservative/aggressive side-by-side cards + affected symbols chips + strategy impact list. Button "Open risk config" calls `.riskCenter`; each row's "Edit filter" calls `.strategyWorkspace` in root view.

- [ ] **Step 1: Create component**

```swift
import SwiftUI

struct DualProfileSignalPanel: View {
    @Environment(PulseColors.self) private var colors
    let detail: ManipulationCaseDetail
    let impact: StrategyImpactResponsePayload?
    let onOpenRisk: () -> Void
    let onEditStrategy: () -> Void

    var body: some View {
        KryptonCard(emphasis: .standard) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                TerminalLabel(text: L10n.Manipulation.defenseStrategyImpact)
                HStack(alignment: .top, spacing: PulseSpacing.md) {
                    signalCard(title: L10n.Manipulation.conservativeProfile, signal: detail.tradingSignal?.conservative, color: PulseColors.info)
                    signalCard(title: L10n.Manipulation.aggressiveProfile, signal: detail.tradingSignal?.aggressive, color: PulseColors.amber)
                }
                affectedSymbols
                strategyRows
                KryptonButton(title: L10n.Manipulation.openStrategyRisk, action: onOpenRisk)
            }
        }
    }

    private func signalCard(title: String, signal: ManipulationTradingSignal?, color: Color) -> some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                Text(title).font(PulseFonts.captionMedium).foregroundStyle(color)
                Text(manipulationSignalLabel(signal?.action ?? "WATCH"))
                    .font(PulseFonts.displaySubheading).foregroundStyle(colors.textPrimary)
                Text(signal?.rationale ?? "—")
                    .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Text(signal?.sizing ?? "—").font(PulseFonts.micro).foregroundStyle(color)
                    Text(signal?.stopLoss ?? "—").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    Spacer()
                    Text(signal?.riskLevel.uppercased() ?? "—").font(PulseFonts.micro).foregroundStyle(color)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var affectedSymbols: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.Manipulation.affectedSymbols).font(PulseFonts.captionMedium).foregroundStyle(colors.textPrimary)
            FlowLayout(spacing: PulseSpacing.xs) {
                ForEach(detail.affectedSymbols.isEmpty ? [detail.symbol] : detail.affectedSymbols, id: \.self) { symbol in
                    Text(symbol).font(PulseFonts.micro).foregroundStyle(PulseColors.accent)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(PulseColors.accent.opacity(0.10)))
                }
            }
        }
    }

    private var strategyRows: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            Text(L10n.Manipulation.strategyImpact).font(PulseFonts.captionMedium).foregroundStyle(colors.textPrimary)
            ForEach(impact?.affectedStrategies ?? []) { strategy in
                HStack(spacing: PulseSpacing.sm) {
                    Image(systemName: strategy.manipulationFilter.wouldBlock ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .foregroundStyle(strategy.manipulationFilter.wouldBlock ? PulseColors.success : PulseColors.amber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(strategy.name).font(PulseFonts.caption).foregroundStyle(colors.textPrimary)
                        Text(strategy.manipulationFilter.wouldBlock ? L10n.Manipulation.wouldBlock : L10n.Manipulation.filterDisabled)
                            .font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    }
                    Spacer()
                    Button(L10n.Manipulation.openStrategyWorkspace, action: onEditStrategy)
                        .buttonStyle(.plain)
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.accent)
                }
                .padding(.vertical, PulseSpacing.xxs)
            }
            if (impact?.affectedStrategies ?? []).isEmpty {
                Text("—").font(PulseFonts.caption).foregroundStyle(colors.textMuted)
            }
        }
    }
}
```

If `FlowLayout` is unavailable, replace `FlowLayout` with a simple `HStack` that line-limits chips for this task.

- [ ] **Step 2: Build** — `cd macos-app && swift build`

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Views/Manipulation/Components/DualProfileSignalPanel.swift
git commit -m "feat(macos): add dual-profile signal + strategy impact panel"
```

---


### Task 21: §8 `SimilarCasesPanel` + reuse alert feed

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/SimilarCasesPanel.swift`
- Modify: `macos-app/AlphaLoop/Views/Manipulation/ManipulationAlertFeed.swift` only if it contains hardcoded strings or fixed width.

**Interfaces:**
- Consumes: `SimilarCasesResponsePayload?`.
- Produces: right-half card listing similar historical cases with symbol, M-type, similarity %, outcome stats.

- [ ] **Step 1: Create `SimilarCasesPanel.swift`**

```swift
import SwiftUI

struct SimilarCasesPanel: View {
    @Environment(PulseColors.self) private var colors
    let similar: SimilarCasesResponsePayload?

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                TerminalLabel(text: L10n.Manipulation.similarHistoricalCases)
                ForEach(similar?.similar ?? []) { item in
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        HStack {
                            Text(item.symbol).font(PulseFonts.captionMedium).foregroundStyle(colors.textPrimary)
                            Text(item.manipulationType).font(PulseFonts.micro).foregroundStyle(PulseColors.amber)
                            Spacer()
                            Text("\(Int(item.similarity * 100))%")
                                .font(PulseFonts.tabular).foregroundStyle(PulseColors.accent)
                        }
                        HStack(spacing: PulseSpacing.sm) {
                            stat("peak", item.outcome?.peakChange)
                            stat("collapse", item.outcome?.collapseDepth)
                            stat("days", item.outcome?.durationDays)
                        }
                    }
                    .padding(.vertical, PulseSpacing.xs)
                    .overlay(alignment: .bottom) { Rectangle().fill(colors.border.opacity(0.10)).frame(height: 1) }
                }
                if (similar?.similar ?? []).isEmpty {
                    Text("—").font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                }
            }
        }
    }

    private func stat(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map { String(format: "%.2f", $0) } ?? "—")
                .font(PulseFonts.micro).foregroundStyle(colors.textPrimary)
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
        }
    }
}
```

- [ ] **Step 2: Build** — `cd macos-app && swift build`

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Views/Manipulation/Components/SimilarCasesPanel.swift
git commit -m "feat(macos): add SimilarCasesPanel"
```

---

### Task 22: Rewrite `ManipulationRadarView` root as nine-section narrative flow

**Files:**
- Modify: `macos-app/AlphaLoop/Views/Manipulation/ManipulationRadarView.swift`
- Delete: `macos-app/AlphaLoop/Views/Manipulation/CaseDetailView.swift` (sheet mode removed)
- Delete or leave unused: `macos-app/AlphaLoop/Views/Manipulation/CaseCardView.swift` (superseded by `ActiveCasesStripCard`; delete after grep confirms no references)

**Interfaces:**
- Consumes ViewModel from Task 12 and all components from Tasks 15-21.
- Produces 10 staggered sections: Masthead index 0, Strip 1, Verdict 2, Lifecycle 3, Evidence 4, Whale 5, Cross-market 6, Social 7, Dual profile 8, Alert+Similar 9.

- [ ] **Step 1: Grep references before deletion**

Run:
```bash
grep -rn "CaseDetailView(" macos-app/AlphaLoop || true
grep -rn "CaseCardView(" macos-app/AlphaLoop || true
```
Expected: only current `ManipulationRadarView.swift` references. Delete files after rewriting root.

- [ ] **Step 2: Replace `ManipulationRadarView.swift`**

```swift
import SwiftUI

struct ManipulationRadarView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Environment(AppState.self) private var appState
    @State private var viewModel: ManipulationViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                LoadingView(type: .dashboard).padding(PulseSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(settingsState.language)
        .task {
            if viewModel == nil {
                let vm = ManipulationViewModel(client: networkClient)
                viewModel = vm
                await vm.loadRadar()
                vm.startLiveUpdates()
            }
        }
        .onDisappear { viewModel?.stopLiveUpdates() }
    }

    private func content(vm: ManipulationViewModel) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: PulseSpacing.xl) {
                masthead.staggeredAppearance(index: 0)

                ActiveCasesStrip(
                    cases: vm.radarOverview?.activeCases ?? [],
                    focusedCaseId: vm.focusedCaseId,
                    onSelect: { id in Task { await vm.focusCase(id) } }
                )
                .staggeredAppearance(index: 1)

                if vm.isLoading && vm.focusedDetail == nil {
                    LoadingView(type: .detail).frame(maxWidth: .infinity)
                } else if let detail = vm.focusedDetail {
                    VerdictPanel(detail: detail).staggeredAppearance(index: 2)
                    LifecycleTimeline(currentStage: detail.lifecycleStage, timeline: detail.timeline).staggeredAppearance(index: 3)
                    EvidenceLayerMatrix(layers: detail.evidenceLayers).staggeredAppearance(index: 4)
                    WhaleConcentrationPanel(layer: detail.evidenceLayers?.cOnchain).staggeredAppearance(index: 5)
                    CrossMarketPressurePanel(layer: detail.evidenceLayers?.eCrossMarket).staggeredAppearance(index: 6)
                    SocialAccelerationPanel(layer: detail.evidenceLayers?.dSocial).staggeredAppearance(index: 7)
                    DualProfileSignalPanel(
                        detail: detail,
                        impact: vm.strategyImpact,
                        onOpenRisk: { appState.selectedRoute = .riskCenter },
                        onEditStrategy: { appState.selectedRoute = .strategyWorkspace }
                    )
                    .staggeredAppearance(index: 8)
                    alertAndSimilar(vm: vm).staggeredAppearance(index: 9)
                } else {
                    EmptyStateView(icon: "shield.checkered", title: L10n.Manipulation.noCases, description: L10n.Manipulation.disclaimer)
                }
            }
            .padding(.horizontal, PulseSpacing.xl)
            .padding(.vertical, PulseSpacing.lg)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .scrollEdgeEffectStyle(.soft, for: .vertical)
    }

    private var masthead: some View {
        KryptonCard(emphasis: .standard) {
            VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                Text("ALPHALOOP · MANIPULATION RADAR · STATISTICAL INFERENCE")
                    .font(PulseFonts.displaySubheading)
                    .foregroundStyle(colors.textPrimary)
                Text(L10n.Manipulation.disclaimer)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }
        }
    }

    private func alertAndSimilar(vm: ManipulationViewModel) -> some View {
        HStack(alignment: .top, spacing: PulseSpacing.md) {
            KryptonCard(emphasis: .subtle) {
                VStack(alignment: .leading, spacing: PulseSpacing.md) {
                    TerminalLabel(text: L10n.Manipulation.alertFeed)
                    ManipulationAlertFeed(alerts: vm.alerts)
                }
            }
            SimilarCasesPanel(similar: vm.similarCases)
        }
    }
}
```

- [ ] **Step 3: Delete sheet detail/card files**

```bash
rm macos-app/AlphaLoop/Views/Manipulation/CaseDetailView.swift
rm macos-app/AlphaLoop/Views/Manipulation/CaseCardView.swift
```

- [ ] **Step 4: Build**

Run: `cd macos-app && swift build`
Expected: clean build. If `FlowLayout` missing from Task 20, switch to `HStack`.

- [ ] **Step 5: Commit**

```bash
git add macos-app/AlphaLoop/Views/Manipulation/ManipulationRadarView.swift \
        macos-app/AlphaLoop/Views/Manipulation/CaseDetailView.swift \
        macos-app/AlphaLoop/Views/Manipulation/CaseCardView.swift
git commit -m "feat(macos): rewrite ManipulationRadarView as nine-section narrative flow"
```

---


## Phase P4 — Real-time behavior, tests, manual verification

### Task 23: macOS tests for `focusCase` and stream fallback + build verification

**Files:**
- Modify: `macos-app/Tests/ViewModelTests.swift` (if Task 12 tests not already added)

**Interfaces:**
- Verifies Task 12/22 behavior and makes sure UI compile is intact.

- [ ] **Step 1: Run focused tests**

```bash
cd macos-app
swift test --filter manipulationViewModelFocusCaseLoadsThreeEndpoints
swift test --filter manipulationViewModelLiveUpdatesNoOpInMockMode
```
Expected: both pass. If Swift Testing filter syntax differs, run `swift test` and grep the test names in output.

- [ ] **Step 2: Run build**

`cd macos-app && swift build`
Expected: success.

- [ ] **Step 3: Launch UI manually**

Run: `cd macos-app && swift run`
Manual acceptance:
- Navigate to Manipulation Radar.
- Confirm no sheet appears; detail renders inline.
- Confirm 1280-centered layout and 10 staggered blocks.
- Click Hero Strip case; lower sections update.
- Confirm §7 buttons navigate to Risk Center and Strategy Workspace.
- Toggle zh/en in settings; all new copy changes language.

- [ ] **Step 4: Commit only if tests changed**

```bash
git add macos-app/Tests/ViewModelTests.swift
git commit -m "test(macos): cover ManipulationViewModel focusCase and stream fallback"
```

---

### Task 24: End-to-end backend + WS verification

**Files:**
- No code expected unless failures are found.

- [ ] **Step 1: Run backend tests**

`cd backend && python3 -m pytest tests/test_manipulation_*.py -q`
Expected: all manipulation tests pass.

- [ ] **Step 2: Full backend suite**

`cd backend && python3 -m pytest tests/ -q --cov=app`
Expected: pass and coverage ≥30%.

- [ ] **Step 3: WebSocket smoke**

Use a small Python client against running backend:

```python
# /tmp/ws_smoke.py
import asyncio, websockets, json
async def main():
    async with websockets.connect("ws://localhost:8000/api/v2/manipulation/stream") as ws:
        msg = await ws.recv()
        print(json.loads(msg)["type"])
asyncio.run(main())
```

Run: `python3 /tmp/ws_smoke.py`
Expected: prints `snapshot`.

---

## Phase P5 — Documentation sync + completion

### Task 25: Docs sync (CLAUDE.md, user guide, old spec superseded-by)

**Files:**
- Modify: `CLAUDE.md` — verify existing ManipulationRadarView paragraph matches implemented sections; update only if implementation names differ.
- Modify: `docs/user-guide/content/zh/pages/structure/manipulation-radar.html`
- Modify: `docs/user-guide/content/en/pages/structure/manipulation-radar.html`
- Modify: `docs/superpowers/specs/2026-06-15-manipulation-radar-engine-design.md` — add `superseded-by` frontmatter entry for §8 only.

**Interfaces:**
- User guide must explain statistical inference (not verdict), active-case strip, evidence layers/data quality, dual profiles, strategy impact, similar historical cases.

- [ ] **Step 1: Update old engine spec frontmatter**

At the top frontmatter of `docs/superpowers/specs/2026-06-15-manipulation-radar-engine-design.md`, add:

```yaml
superseded-by:
  - docs/superpowers/specs/2026-06-23-manipulation-radar-narrative-refactor-design.md (§8 UI only)
```

- [ ] **Step 2: Update zh user guide page**

Rewrite the main content of `docs/user-guide/content/zh/pages/structure/manipulation-radar.html` to include:
- 操纵雷达是统计推断系统，不是定罪工具。
- 页面阅读顺序：活跃案例 → 判定 → 生命周期 → 证据矩阵 → 巨鲸/跨市场/社交 → 防御与策略联动 → 告警/相似案例。
- 数据质量 badge 含义：`quality < 0.3` 显示数据不可用。
- 保守/激进双画像如何解读。
- 策略联动：`将阻断` vs `过滤器未启用`。

- [ ] **Step 3: Update en user guide page**

Mirror the zh content in English, using "statistical inference", "evidence-based suspicions, not verdicts", and "conservative/aggressive profile" language.

- [ ] **Step 4: Verify guide links remain registered**

Search:
```bash
grep -n "manipulation-radar" docs/user-guide/assets/app.js docs/user-guide/assets/search-index.json
```
Expected: existing entries remain; no NAV changes needed unless filenames changed (they did not).

- [ ] **Step 5: Commit docs**

```bash
git add CLAUDE.md \
        docs/user-guide/content/zh/pages/structure/manipulation-radar.html \
        docs/user-guide/content/en/pages/structure/manipulation-radar.html \
        docs/superpowers/specs/2026-06-15-manipulation-radar-engine-design.md
git commit -m "docs: sync Manipulation Radar nine-section narrative guide"
```

---

### Task 26: Final branch verification and push

**Files:**
- No code changes expected.

- [ ] **Step 1: Check status**

`git status -sb`
Expected: clean working tree.

- [ ] **Step 2: Run final verification**

```bash
cd backend && python3 -m pytest tests/test_manipulation_*.py -q
cd ../macos-app && swift build
```
Expected: both pass.

- [ ] **Step 3: Manual UI verification**

`cd macos-app && swift run`
Acceptance checklist:
- [ ] Page skeleton: 1280 centered, 10 staggered frames, KryptonCard/TerminalLabel reused.
- [ ] Copy: probability prefix + masthead disclaimer.
- [ ] Data completeness: Verdict N/5 + max confidence; each layer quality; unavailable layer shown honestly.
- [ ] Dual profile: conservative + aggressive visible simultaneously; no top toggle.
- [ ] Strategy impact: affected strategies + filter status + jump buttons.
- [ ] Similar cases: top-N historical cases with outcomes.
- [ ] Realtime: backend WS snapshot works; UI remains usable if WS unavailable (polling fallback).
- [ ] L10n: zh/en toggle changes all new strings.

- [ ] **Step 4: Push**

```bash
git push origin strategy-workbench-canvas-first
```

- [ ] **Step 5: Completion flow**

Use `superpowers:finishing-a-development-branch` after implementation and verification pass.

---

## Self-review checklist

- Spec coverage:
  - P1 backend: `/cases/{id}` v2 evidence layers + dual signal, `/strategy-impact`, `/similar`, `/stream` covered by Tasks 1-8.
  - P2 macOS API/ViewModel/WS client covered by Tasks 9-12.
  - P3 UI nine sections covered by Tasks 13-22.
  - P4 verification covered by Tasks 23-24.
  - P5 docs sync covered by Tasks 25-26.
- Placeholder scan: no `TBD`, `TODO`, "write tests for above" without code. Task 19 allows same-structure duplication for two simple panels but specifies exact title/color variations; acceptable because each is a mechanical clone under 120 lines.
- Type consistency: `EvidenceLayersBlock.ordered`, `ManipulationCaseDetail.evidenceLayers`, `DualTradingSignalPayload`, `StrategyImpactResponsePayload`, `SimilarCasesResponsePayload`, and `ManipulationStreamEvent` are used consistently across Tasks 9-22.

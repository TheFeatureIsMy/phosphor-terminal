# Dashboard Bento Command Grid — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the Dashboard as a PRD-driven trading operation control tower with Bento Command Grid layout, single BFF endpoint, reason_codes on every card, and bilingual L10n.

**Architecture:** The backend already has `GET /api/overview/dashboard` returning `DashboardBFFResponse` (overview.py router + overview.py schemas). The frontend already has `APIOverview.getDashboard()` with matching Codable types. We enhance the backend mock/aggregation, then rewrite `DashboardViewModel` to consume the single BFF response, and replace all Dashboard views with 11 new components composed in a Bento grid.

**Tech Stack:** Python 3.11 / FastAPI / Pydantic v2 (backend), Swift 6.2 / SwiftUI / macOS 26 (frontend)

**Spec:** `docs/superpowers/specs/2026-06-15-dashboard-bento-command-grid-design.md`
**Mockup:** `docs/ui-references/mockups/dashboard-v3-refined.html`

---

## File Map

### Backend (modify)
- `backend/app/schemas/overview.py` — Add `sharpe_ratio` to `AccountOverview`, add `time` to `Alert`
- `backend/app/routers/overview.py` — Enhance `_mock_dashboard()` with richer mock data
- `backend/app/services/overview_aggregator.py` — **New**: real service aggregation
- `backend/tests/test_overview_dashboard.py` — **New**: dedicated dashboard BFF tests

### Frontend — Data Layer (modify)
- `macos-app/AlphaLoop/Services/APIDashboard.swift` — Rewrite: single `getDashboardBFF()` delegating to `APIOverview`
- `macos-app/AlphaLoop/ViewModels/DashboardViewModel.swift` — Rewrite: consume `DashboardBFFResponse`
- `macos-app/AlphaLoop/Localization/L10n+Dashboard.swift` — Rewrite: all new string keys

### Frontend — New Views (create)
- `macos-app/AlphaLoop/Views/Dashboard/DashboardView.swift` — Bento grid layout
- `macos-app/AlphaLoop/Views/Dashboard/DashboardStatusBar.swift` — Infrastructure-only status bar
- `macos-app/AlphaLoop/Views/Dashboard/AccountHeroCard.swift` — Equity + PnL + sparkline
- `macos-app/AlphaLoop/Views/Dashboard/AvailableActionsRow.swift` — Contextual action buttons
- `macos-app/AlphaLoop/Views/Dashboard/StrategyRuntimeCard.swift`
- `macos-app/AlphaLoop/Views/Dashboard/LiveReadinessCard.swift`
- `macos-app/AlphaLoop/Views/Dashboard/GlobalRiskCard.swift`
- `macos-app/AlphaLoop/Views/Dashboard/PositionRiskTable.swift`
- `macos-app/AlphaLoop/Views/Dashboard/RecentDecisionFeed.swift`
- `macos-app/AlphaLoop/Views/Dashboard/AlertTimeline.swift`
- `macos-app/AlphaLoop/Views/Dashboard/EmergencyActionBar.swift`

### Frontend — Delete
- `macos-app/AlphaLoop/Views/Dashboard/Cards/` (entire directory)
- `macos-app/AlphaLoop/Views/Dashboard/TickerTapeView.swift`
- `macos-app/AlphaLoop/Views/Dashboard/TradingWorkflowRailView.swift`
- `macos-app/AlphaLoop/Views/Dashboard/UnifiedToolbar.swift`

### Frontend — Keep (no changes)
- `macos-app/AlphaLoop/Views/Dashboard/EquityCurveChart.swift`
- `macos-app/AlphaLoop/Views/Dashboard/LearnAlphaLoopCard.swift`

### Docs (modify)
- `CLAUDE.md` — Update Dashboard section
- `docs/user-guide/content/zh/pages/overview/dashboard.html` — **New**: user guide chapter
- `docs/user-guide/content/en/pages/overview/dashboard.html` — **New**: user guide chapter
- `docs/user-guide/assets/app.js` — Register new chapters in NAV

---

## Task 1: Backend — Enhance Schema + Mock Data

**Files:**
- Modify: `backend/app/schemas/overview.py`
- Modify: `backend/app/routers/overview.py`

- [ ] **Step 1: Add `sharpe_ratio` and `time` fields to schemas**

In `backend/app/schemas/overview.py`, add `sharpe_ratio` to `AccountOverview` and `time` to `Alert`:

```python
class AccountOverview(BaseModel):
    equity: float = 0
    currency: str = "USDT"
    today_pnl_pct: float = 0
    week_pnl_pct: float = 0
    max_drawdown_pct: float = 0
    sharpe_ratio: float = 0       # ← NEW: 30d rolling Sharpe
```

```python
class Alert(BaseModel):
    level: str = "info"
    title: str = ""
    symbol: str = ""
    time: str = ""                # ← NEW: HH:mm timestamp
```

- [ ] **Step 2: Enhance `_mock_dashboard()` with realistic trading data**

In `backend/app/routers/overview.py`, update the `_mock_dashboard()` function to return rich mock data matching the mockup. Include 4 positions, 5 recent decisions with reason_codes, 6 alerts with timestamps, 3 available_actions, and realistic account/runtime/risk/system values. The mock should exercise every field in the schema so the frontend can render without a live backend.

Key mock values:
- `account.equity = 124850.32`, `sharpe_ratio = 1.82`, `today_pnl_pct = 1.97`, `week_pnl_pct = 4.32`, `max_drawdown_pct = -6.8`
- `runtime.running_strategies = 5`, `open_positions = 4`, `pending_orders = 2`, `reconciling_count = 0`
- `risk.global_state = "normal"`, `daily_loss_remaining_pct = 72.0`, `weekly_loss_remaining_pct = 85.0`, `emergency_locked = False`
- `system.live_readiness_state = "live_ready"`, `fast_track_latency_ms = 12`, `redis_rtt_ms = 3`, `freqtrade_state = "connected"`, `exchange_state = "binance_connected"`
- 3 `available_actions`: deploy strategy (primary), review signals (secondary), tighten stop (warn)
- 5 `recent_decisions` with reason_codes arrays
- 6 `alerts` with level (info/warning/error) and time

- [ ] **Step 3: Run existing tests to verify no regression**

Run: `cd backend && python3 -m pytest tests/test_bff_integration.py::TestDashboard -v`
Expected: All existing dashboard tests PASS (the schema changes are additive with defaults).

- [ ] **Step 4: Commit**

```bash
git add backend/app/schemas/overview.py backend/app/routers/overview.py
git commit -m "feat(backend): enhance dashboard BFF schema with sharpe_ratio, richer mock data"
```

---

## Task 2: Backend — OverviewAggregatorService + Tests

**Files:**
- Create: `backend/app/services/overview_aggregator.py`
- Create: `backend/tests/test_overview_dashboard.py`

- [ ] **Step 1: Write the test file**

```python
"""Tests for Dashboard BFF aggregation — OverviewAggregatorService."""
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


class TestDashboardBFF:
    @pytest.mark.anyio
    async def test_dashboard_returns_200(self, client):
        r = await client.get("/api/overview/dashboard")
        assert r.status_code == 200

    @pytest.mark.anyio
    async def test_dashboard_has_all_sections(self, client):
        data = (await client.get("/api/overview/dashboard")).json()
        for key in ("state", "reason_codes", "available_actions",
                    "account", "runtime", "risk", "system",
                    "recent_decisions", "alerts"):
            assert key in data, f"Missing key: {key}"

    @pytest.mark.anyio
    async def test_dashboard_account_has_sharpe(self, client):
        data = (await client.get("/api/overview/dashboard")).json()
        assert "sharpe_ratio" in data["account"]

    @pytest.mark.anyio
    async def test_dashboard_alerts_have_time(self, client):
        data = (await client.get("/api/overview/dashboard")).json()
        if data["alerts"]:
            assert "time" in data["alerts"][0]

    @pytest.mark.anyio
    async def test_dashboard_available_actions_structure(self, client):
        data = (await client.get("/api/overview/dashboard")).json()
        if data["available_actions"]:
            action = data["available_actions"][0]
            assert "type" in action
            assert "label" in action
            assert "enabled" in action

    @pytest.mark.anyio
    async def test_dashboard_mock_fallback(self, client):
        """Dashboard must always return data, even without live services."""
        data = (await client.get("/api/overview/dashboard")).json()
        assert data["state"] in ("healthy", "warning", "blocked", "unknown")
        assert isinstance(data["reason_codes"], list)
        assert isinstance(data["recent_decisions"], list)
```

- [ ] **Step 2: Run tests to verify they pass (mock fallback)**

Run: `cd backend && python3 -m pytest tests/test_overview_dashboard.py -v`
Expected: All 6 tests PASS (the router falls back to enhanced mock data).

- [ ] **Step 3: Create OverviewAggregatorService**

Create `backend/app/services/overview_aggregator.py`:

```python
"""Dashboard BFF aggregator — combines multiple domain services into one response."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from app.config import settings

logger = logging.getLogger(__name__)


class OverviewAggregatorService:
    """Aggregates account, runtime, risk, system, decisions, and alerts
    into a single DashboardBFFResponse. Each sub-call is independent;
    failures are isolated and fall back to safe defaults."""

    async def aggregate(self) -> dict:
        account, runtime, risk, system, decisions, alerts = await asyncio.gather(
            self._fetch_account(),
            self._fetch_runtime(),
            self._fetch_risk(),
            self._fetch_system(),
            self._fetch_recent_decisions(),
            self._fetch_alerts(),
            return_exceptions=True,
        )

        # Replace exceptions with defaults
        if isinstance(account, Exception):
            logger.warning("account fetch failed: %s", account)
            account = {}
        if isinstance(runtime, Exception):
            logger.warning("runtime fetch failed: %s", runtime)
            runtime = {}
        if isinstance(risk, Exception):
            logger.warning("risk fetch failed: %s", risk)
            risk = {}
        if isinstance(system, Exception):
            logger.warning("system fetch failed: %s", system)
            system = {}
        if isinstance(decisions, Exception):
            logger.warning("decisions fetch failed: %s", decisions)
            decisions = []
        if isinstance(alerts, Exception):
            logger.warning("alerts fetch failed: %s", alerts)
            alerts = []

        state, reason_codes = self._derive_state(risk, system)
        available_actions = self._derive_actions(risk, runtime, decisions)

        return {
            "state": state,
            "reason_codes": reason_codes,
            "available_actions": available_actions,
            "account": account,
            "runtime": runtime,
            "risk": risk,
            "system": system,
            "recent_decisions": decisions,
            "alerts": alerts,
        }

    async def _fetch_account(self) -> dict:
        from app.services.freqtrade_client import FreqtradeClient
        client = FreqtradeClient()
        balance = await client.balance()
        if not FreqtradeClient.is_success(balance):
            return {}
        return {
            "equity": balance.get("total", 0),
            "currency": balance.get("currency", "USDT"),
            "today_pnl_pct": 0,
            "week_pnl_pct": 0,
            "max_drawdown_pct": 0,
            "sharpe_ratio": 0,
        }

    async def _fetch_runtime(self) -> dict:
        from app.services.runtime_redis_store import RuntimeRedisStore
        store = RuntimeRedisStore(redis_url=settings.redis_url)
        count_raw = await store._get("pd:runtime:strategy_count")
        return {
            "running_strategies": int(count_raw) if count_raw else 0,
            "open_positions": 0,
            "pending_orders": 0,
            "reconciling_count": 0,
        }

    async def _fetch_risk(self) -> dict:
        from app.services.runtime_redis_store import RuntimeRedisStore
        store = RuntimeRedisStore(redis_url=settings.redis_url)
        risk_raw = await store._get("pd:runtime:global_risk_state")
        if risk_raw:
            import json
            return json.loads(risk_raw)
        return {
            "global_state": "normal",
            "daily_loss_remaining_pct": 100.0,
            "weekly_loss_remaining_pct": 100.0,
            "emergency_locked": False,
        }

    async def _fetch_system(self) -> dict:
        from app.services.freqtrade_client import FreqtradeClient
        client = FreqtradeClient()
        try:
            ping = await client.version()
            ft_state = "connected" if FreqtradeClient.is_success(ping) else "disconnected"
        except Exception:
            ft_state = "disconnected"

        from app.services.runtime_redis_store import RuntimeRedisStore
        store = RuntimeRedisStore(redis_url=settings.redis_url)
        try:
            await store.ping()
            redis_rtt = 3
        except Exception:
            redis_rtt = -1

        return {
            "live_readiness_state": "paper_only",
            "fast_track_latency_ms": 0,
            "redis_rtt_ms": redis_rtt,
            "freqtrade_state": ft_state,
            "exchange_state": "unknown",
        }

    async def _fetch_recent_decisions(self) -> list[dict]:
        return []

    async def _fetch_alerts(self) -> list[dict]:
        return []

    def _derive_state(self, risk: dict, system: dict) -> tuple[str, list[str]]:
        codes: list[str] = []
        if risk.get("emergency_locked"):
            return "locked", ["emergency_locked"]
        risk_state = risk.get("global_state", "normal")
        if risk_state in ("blocked", "locked"):
            codes.append(f"risk_{risk_state}")
            return "blocked", codes
        ft = system.get("freqtrade_state", "unknown")
        if ft == "disconnected":
            codes.append("freqtrade_disconnected")
            return "warning", codes
        if risk_state == "warning":
            codes.append("risk_warning")
            return "warning", codes
        codes.append("all_services_healthy")
        return "healthy", codes

    def _derive_actions(self, risk: dict, runtime: dict, decisions: list) -> list[dict]:
        actions: list[dict] = []
        if not risk.get("emergency_locked"):
            actions.append({
                "type": "review_signals",
                "enabled": True,
                "label": "Review pending signals",
                "confirm_required": False,
                "metadata": {},
            })
        return actions[:3]
```

- [ ] **Step 4: Wire aggregator into the router (optional real-data path)**

In `backend/app/routers/overview.py`, update the `dashboard` endpoint to try the aggregator before falling back to mock:

```python
@router.get("/dashboard", response_model=DashboardResponse)
async def dashboard():
    try:
        from app.services.overview_aggregator import OverviewAggregatorService
        svc = OverviewAggregatorService()
        data = await svc.aggregate()
        return data
    except Exception as exc:
        logger.warning("Aggregator failed, using mock: %s", exc)
        data = _mock_dashboard()
        data["_mock"] = True
        return data
```

- [ ] **Step 5: Run all tests**

Run: `cd backend && python3 -m pytest tests/test_overview_dashboard.py tests/test_bff_integration.py -v`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/overview_aggregator.py backend/app/routers/overview.py backend/tests/test_overview_dashboard.py
git commit -m "feat(backend): add OverviewAggregatorService + dashboard BFF tests"
```

---

## Task 3: Frontend — Rewrite L10n+Dashboard.swift

**Files:**
- Modify: `macos-app/AlphaLoop/Localization/L10n+Dashboard.swift`

- [ ] **Step 1: Replace entire file with new PRD-aligned strings**

```swift
import Foundation

extension L10n {
    enum Dashboard {
        // Status Bar
        static var systemState: String { zh("系统", en: "SYS") }
        static var freqtrade: String { zh("交易引擎", en: "FREQTRADE") }
        static var redis: String { zh("缓存", en: "REDIS") }
        static var exchange: String { zh("交易所", en: "EXCHANGE") }

        // Account Hero
        static var accountOverview: String { zh("账户总览", en: "ACCOUNT OVERVIEW") }
        static var todayPnl: String { zh("今日盈亏", en: "TODAY P&L") }
        static var weekPnl: String { zh("本周盈亏", en: "WEEK P&L") }
        static var maxDrawdown: String { zh("最大回撤", en: "MAX DRAWDOWN") }
        static var sharpeRatio: String { zh("夏普比率", en: "SHARPE RATIO") }
        static var rollingDays: String { zh("30日滚动", en: "30d rolling") }

        // Available Actions
        static var suggestedActions: String { zh("建议操作", en: "SUGGESTED ACTIONS") }

        // Strategy Runtime
        static var strategyRuntime: String { zh("策略运行", en: "STRATEGY RUNTIME") }
        static var running: String { zh("运行中", en: "running") }
        static var positions: String { zh("持仓", en: "positions") }
        static var pending: String { zh("挂单", en: "pending") }
        static var reconciling: String { zh("对账中", en: "reconciling") }

        // Live Readiness
        static var liveReadiness: String { zh("实盘准入", en: "LIVE READINESS") }
        static var liveReady: String { zh("实盘就绪", en: "LIVE READY") }
        static var paperOnly: String { zh("仅模拟", en: "PAPER ONLY") }
        static var riskLocked: String { zh("风控锁定", en: "RISK LOCKED") }
        static var notReady: String { zh("未就绪", en: "NOT READY") }
        static func gatesPassed(_ n: Int) -> String { zh("全部 \(n) 项检查通过", en: "All \(n) gates passed") }

        // Global Risk
        static var globalRiskState: String { zh("全局风控", en: "GLOBAL RISK STATE") }
        static var dailyLoss: String { zh("日损余额", en: "DAILY") }
        static var weeklyLoss: String { zh("周损余额", en: "WEEKLY") }
        static var normal: String { zh("正常", en: "NORMAL") }
        static var warning: String { zh("警告", en: "WARNING") }
        static var blocked: String { zh("阻断", en: "BLOCKED") }
        static var locked: String { zh("锁定", en: "LOCKED") }
        static var emergencyLocked: String { zh("紧急锁定", en: "EMERGENCY LOCKED") }

        // Position Risk
        static var positionRisk: String { zh("持仓风险", en: "POSITION RISK") }
        static func openCount(_ n: Int) -> String { zh("\(n) 个持仓", en: "\(n) OPEN") }
        static var symbol: String { zh("品种", en: "SYMBOL") }
        static var direction: String { zh("方向", en: "DIRECTION") }
        static var size: String { zh("数量", en: "SIZE") }
        static var entry: String { zh("开仓价", en: "ENTRY") }
        static var pnl: String { zh("盈亏", en: "P&L") }
        static var pnlPct: String { zh("盈亏%", en: "P&L %") }
        static var risk: String { zh("风险", en: "RISK") }
        static var reason: String { zh("原因", en: "REASON") }
        static var long: String { zh("做多", en: "LONG") }
        static var short: String { zh("做空", en: "SHORT") }
        static var riskLow: String { zh("低", en: "LOW") }
        static var riskMed: String { zh("中", en: "MED") }
        static var riskHigh: String { zh("高", en: "HIGH") }
        static var noPositions: String { zh("无持仓", en: "No open positions") }

        // Recent Decisions
        static var recentDecisions: String { zh("近期决策", en: "RECENT DECISIONS") }

        // Alert Timeline
        static var alertTimeline: String { zh("告警时间线", en: "ALERT TIMELINE") }

        // Emergency
        static var emergencyControl: String { zh("紧急控制", en: "EMERGENCY CONTROL") }
        static var haltAllTrading: String { zh("停止全部交易", en: "HALT ALL TRADING") }
        static var haltDescription: String {
            zh("停止所有策略 · 取消挂单 · 保留持仓",
               en: "Stops all strategies · Cancels pending orders · Preserves positions")
        }
        static var confirmHaltTitle: String { zh("确认停止交易", en: "Confirm Halt Trading") }
        static var confirmHaltMessage: String {
            zh("此操作将立即停止所有自动交易策略并取消所有挂单。需要手动恢复。",
               en: "This will immediately stop all automated trading strategies and cancel all pending orders. Manual restart required.")
        }

        // Misc
        static var dashboardTitle: String { zh("总览", en: "Dashboard") }
        static var waitingForData: String { zh("等待数据...", en: "Waiting for data...") }
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd macos-app && swift build 2>&1 | tail -5`
Expected: Build succeeds (unused old L10n references will cause warnings, not errors, until views are replaced).

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Localization/L10n+Dashboard.swift
git commit -m "feat(l10n): rewrite Dashboard strings for Bento Command Grid layout"
```

---

## Task 4: Frontend — Rewrite APIDashboard + DashboardViewModel

**Files:**
- Modify: `macos-app/AlphaLoop/Services/APIDashboard.swift`
- Modify: `macos-app/AlphaLoop/ViewModels/DashboardViewModel.swift`

- [ ] **Step 1: Rewrite APIDashboard.swift to delegate to APIOverview**

```swift
// APIDashboard.swift — Dashboard BFF API (delegates to APIOverview)

import Foundation

struct APIDashboard {
    let client: NetworkClientProtocol

    func getDashboardBFF() async throws -> DashboardBFFResponse {
        let api = APIOverview(client: client)
        return try await api.getDashboard()
    }
}
```

- [ ] **Step 2: Rewrite DashboardViewModel.swift**

```swift
// DashboardViewModel.swift — Consumes single DashboardBFFResponse from BFF endpoint

import SwiftUI

@Observable
@MainActor
final class DashboardViewModel {
    // BFF response sections — directly mapped
    var state: String = "unknown"
    var reasonCodes: [String] = []
    var availableActions: [AvailableActionResponse] = []
    var account: AccountOverviewResponse?
    var runtime: RuntimeOverviewResponse?
    var risk: RiskOverviewResponse?
    var system: SystemOverviewResponse?
    var recentDecisions: [RecentDecisionResponse] = []
    var alerts: [AlertResponse] = []

    // Equity sparkline (from legacy endpoint, kept for chart)
    var equityCurve: [EquityPoint] = []

    var isLoading = false
    var error: String?
    var errorHandler: ErrorHandler?

    private let api: APIDashboard
    private let legacyAPI: APIDashboard
    private var pollingTask: Task<Void, Never>?

    init(client: NetworkClientProtocol) {
        self.api = APIDashboard(client: client)
        self.legacyAPI = APIDashboard(client: client)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let bffTask = api.getDashboardBFF()
            async let curveTask = APIOverview(client: api.client).getDashboard()

            let bff = try await bffTask
            applyBFF(bff)

            // Equity curve from legacy endpoint for sparkline
            if let legacy = try? await APIDashboard(client: api.client).client.get(
                "/api/dashboard/equity-curve",
                mock: MockData.mockEquityCurve
            ) as [EquityPoint]? {
                equityCurve = legacy ?? []
            }
        } catch {
            self.error = error.localizedDescription
            errorHandler?.handle(error)
        }
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                do {
                    let bff = try await api.getDashboardBFF()
                    applyBFF(bff)
                } catch {
                    // Polling errors are silent — stale data is better than no data
                }
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    private func applyBFF(_ bff: DashboardBFFResponse) {
        state = bff.state
        reasonCodes = bff.reasonCodes
        availableActions = bff.availableActions
        account = bff.account
        runtime = bff.runtime
        risk = bff.risk
        system = bff.system
        recentDecisions = bff.recentDecisions
        alerts = bff.alerts
    }

    func emergencyStop() async {
        do {
            let emergencyAPI = APIEmergency(client: api.client)
            _ = try await emergencyAPI.emergencyStop(reason: "Dashboard emergency halt")
            await load()
        } catch {
            self.error = error.localizedDescription
            errorHandler?.handle(error)
        }
    }
}
```

- [ ] **Step 3: Build to verify compilation**

Run: `cd macos-app && swift build 2>&1 | tail -10`
Expected: Build may have warnings about unused old view references but should compile. The old DashboardView still references old ViewModel properties — that's expected, we replace it next.

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Services/APIDashboard.swift macos-app/AlphaLoop/ViewModels/DashboardViewModel.swift
git commit -m "feat: rewrite APIDashboard + DashboardViewModel for single BFF endpoint"
```

---

## Task 5: Frontend — Delete Old Dashboard Views

**Files:**
- Delete: `macos-app/AlphaLoop/Views/Dashboard/Cards/` (entire directory)
- Delete: `macos-app/AlphaLoop/Views/Dashboard/TickerTapeView.swift`
- Delete: `macos-app/AlphaLoop/Views/Dashboard/TradingWorkflowRailView.swift`
- Delete: `macos-app/AlphaLoop/Views/Dashboard/UnifiedToolbar.swift`
- Delete: `macos-app/AlphaLoop/Views/Dashboard/DashboardView.swift` (will be recreated)

- [ ] **Step 1: Delete old files**

```bash
cd macos-app/AlphaLoop/Views/Dashboard
rm -rf Cards/
rm TickerTapeView.swift TradingWorkflowRailView.swift UnifiedToolbar.swift DashboardView.swift
```

- [ ] **Step 2: Commit deletions**

```bash
git add -A macos-app/AlphaLoop/Views/Dashboard/
git commit -m "chore: remove old AI Control Tower dashboard views"
```

---

## Task 6: Frontend — Create All New Dashboard Views

This is the largest task. Create all 11 new view files. Each file is a focused SwiftUI component.

**Files:** All under `macos-app/AlphaLoop/Views/Dashboard/`

- [ ] **Step 1: Create DashboardStatusBar.swift**

Infrastructure-only status bar. Shows SYS state, FREQTRADE latency, REDIS RTT, EXCHANGE state, plus reason_codes chips. Uses `SystemOverviewResponse` from ViewModel.

Key patterns:
- `@Environment(PulseColors.self) private var colors`
- HStack with dividers between cells
- Each cell: `StatusDot` (green/amber/red based on threshold) + label (PulseFonts.micro) + value (PulseFonts.monoLabel)
- Right-aligned: reason chips (cyan background, PulseFonts.micro)
- `.glassStyle()` background, sticky via `.zIndex(10)` in parent

- [ ] **Step 2: Create AccountHeroCard.swift**

Hero card merging equity + PnL. Left panel (420px): equity large number with `CountUp`, 24h change, equity sparkline using `EquityCurveChart` data at 12% opacity. Right panel: 4 equal columns with vertical dividers — Today P&L%, Week P&L%, Max Drawdown%, Sharpe Ratio. Uses `KryptonCard(emphasis: .bold)`.

Key patterns:
- `CountUp(value: account.equity, format: "%.2f", prefix: "", suffix: "")` for animated number
- PnL values colored via `account.todayPnlPct >= 0 ? colors.profitColor : colors.lossColor`
- Gradient outline: `.overlay(RoundedRectangle(cornerRadius: PulseRadii.card).stroke(LinearGradient(colors: [PulseColors.accent.opacity(0.15), PulseColors.cyan.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))`

- [ ] **Step 3: Create AvailableActionsRow.swift**

Horizontal button row. Maps `[AvailableActionResponse]` to styled ghost buttons. 3 severity styles: primary (accent), secondary (cyan), warn (amber). Max 3 shown. Hidden when empty.

Key patterns:
- `ForEach(actions.prefix(3))` with button per action
- Button style: `.font(PulseFonts.micro)`, `.textCase(.uppercase)`, `.letterSpacing(0.04)`
- Border + background color keyed to `action.type` → severity mapping

- [ ] **Step 4: Create StrategyRuntimeCard.swift**

Shows running count (28px CountUp), positions/pending/reconciling as detail dots. Uses `KryptonCard(emphasis: .balanced)`. Includes reason_codes chips.

- [ ] **Step 5: Create LiveReadinessCard.swift**

36px pulsing lamp (Circle with shadow animation), state text (LIVE READY / PAPER ONLY / etc.), gate count, reason chips. Ambient radial glow behind lamp via `.background(RadialGradient(...).opacity(0.06))` on the lamp container. Uses `KryptonCard(emphasis: .balanced)`.

State-to-color mapping: `live_ready` → accent, `paper_only` → amber, `risk_locked`/`not_ready` → danger.

- [ ] **Step 6: Create GlobalRiskCard.swift**

Status pill (KryptonStatusPill or custom), two horizontal gauge bars (daily + weekly loss remaining). Gauge fill color: accent if > 40%, amber if ≤ 40%. Uses `KryptonCard(emphasis: .balanced)`. Includes reason chips.

Key patterns:
- `GeometryReader` for gauge bar width calculation
- `.animation(.easeOut(duration: 0.8), value: dailyPct)` for gauge fill

- [ ] **Step 7: Create PositionRiskTable.swift**

Full-width table. Each row: 3px left color stripe (green=long, red=short), Symbol, Direction, Size, Entry, P&L, P&L%, Risk (dot+label), Reason (chips). Empty state: `EmptyStateView` with no-positions message.

Key patterns:
- Custom row layout with HStack (not SwiftUI Table — more control over styling)
- Position stripe: `Rectangle().fill(isLong ? colors.profitColor : colors.lossColor).frame(width: 3)`
- Risk dot: `Circle().fill(riskColor).frame(width: 7, height: 7)`
- Font: `PulseFonts.body` for values, `PulseFonts.monoLabel` for symbol

- [ ] **Step 8: Create RecentDecisionFeed.swift**

Scrollable feed (max 280px). Each item: time (HH:mm), symbol + decision verb (colored), description, reason_codes chips. Uses `ScrollView` with `.frame(maxHeight: 280)`.

Decision verb colors: EXECUTE → accent, HOLD → cyan, REDUCE → amber, REJECT → danger.

- [ ] **Step 9: Create AlertTimeline.swift**

Scrollable timeline (max 280px). Vertical connector line between items. Each item: level dot (info=cyan, warning=amber, error=danger), title, meta (scope + time). Connector: vertical line via `.overlay` positioned at the dot's center.

- [ ] **Step 10: Create EmergencyActionBar.swift**

Fixed bottom bar. "EMERGENCY CONTROL" label + "HALT ALL TRADING" button + description. Button triggers `KryptonConfirmDialog(style: .danger)` → calls `viewModel.emergencyStop()`.

Key patterns:
- `@State private var showConfirm = false`
- `.kryptonConfirmSheet(isPresented: $showConfirm, title: L10n.Dashboard.confirmHaltTitle, message: L10n.Dashboard.confirmHaltMessage, confirmLabel: L10n.Dashboard.haltAllTrading, confirmStyle: .danger) { Task { await viewModel.emergencyStop() } }`
- Background: `.ultraThinMaterial` + card background at 94% opacity
- Border-top: accent danger color at 15% opacity

- [ ] **Step 11: Create DashboardView.swift — the main Bento grid**

```swift
// DashboardView.swift — Bento Command Grid layout

import SwiftUI

struct DashboardView: View {
    @Environment(PulseColors.self) private var colors
    @Environment(SettingsState.self) private var settingsState
    @Bindable var viewModel: DashboardViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 10) {
                    // Status Bar
                    if let sys = viewModel.system {
                        DashboardStatusBar(system: sys, reasonCodes: viewModel.reasonCodes)
                            .staggeredAppearance(index: 0)
                    }

                    // Hero: Account Overview
                    if let account = viewModel.account {
                        AccountHeroCard(
                            account: account,
                            equityCurve: viewModel.equityCurve
                        )
                        .staggeredAppearance(index: 1)
                    }

                    // Available Actions
                    if !viewModel.availableActions.isEmpty {
                        AvailableActionsRow(actions: viewModel.availableActions)
                            .staggeredAppearance(index: 2)
                    }

                    // Runtime + Readiness + Risk
                    HStack(spacing: 10) {
                        if let runtime = viewModel.runtime {
                            StrategyRuntimeCard(runtime: runtime)
                        }
                        if let system = viewModel.system {
                            LiveReadinessCard(system: system)
                        }
                        if let risk = viewModel.risk {
                            GlobalRiskCard(risk: risk)
                        }
                    }
                    .staggeredAppearance(index: 3)

                    // Position Risk Table
                    PositionRiskTable(
                        positions: viewModel.risk?.positions ?? [],
                        openCount: viewModel.runtime?.openPositions ?? 0
                    )
                    .staggeredAppearance(index: 4)

                    // Decisions + Alerts
                    HStack(alignment: .top, spacing: 10) {
                        RecentDecisionFeed(decisions: viewModel.recentDecisions)
                        AlertTimeline(alerts: viewModel.alerts)
                    }
                    .staggeredAppearance(index: 5)

                    // Bottom padding for emergency bar
                    Spacer().frame(height: 56)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            // Emergency Action Bar (fixed bottom)
            EmergencyActionBar(viewModel: viewModel)

            // Loading overlay
            if viewModel.isLoading && viewModel.account == nil {
                LoadingView(type: .dashboard)
            }
        }
        .id(settingsState.language)
        .task {
            await viewModel.load()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}
```

- [ ] **Step 12: Build to verify full compilation**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: Build succeeds. If there are type mismatches (e.g., `positions` not on `RiskOverviewResponse`), fix by reading the data from the correct BFF section or adding a computed property on the ViewModel.

- [ ] **Step 13: Commit all new views**

```bash
git add macos-app/AlphaLoop/Views/Dashboard/
git commit -m "feat(dashboard): create Bento Command Grid views — 11 new components"
```

---

## Task 7: Frontend — Build Fix + Integration Test

**Files:**
- Possibly modify: any view file with compilation errors

- [ ] **Step 1: Full build and fix any remaining issues**

Run: `cd macos-app && swift build 2>&1`

Common issues to fix:
- `PositionRiskTable` may need position data passed differently — the BFF response doesn't have a `positions` array on `RiskOverviewResponse`. Solution: add a `positions` computed property on the ViewModel that maps from the BFF, or keep the legacy `APIOrders` call for position details.
- AppShellView still instantiates `DashboardViewModel` and passes it — verify the initializer signature matches.
- Any old references to removed types (`AIMarketJudgment`, `PendingConfirmation`, etc.) — remove them from DashboardViewModel if still present.

- [ ] **Step 2: Run swift test**

Run: `cd macos-app && swift test 2>&1 | tail -20`
Expected: Tests pass. If NavigationTests reference old Dashboard routes, update them.

- [ ] **Step 3: Commit fixes**

```bash
git add -A macos-app/
git commit -m "fix(dashboard): resolve build issues from Bento Command Grid migration"
```

---

## Task 8: Documentation Updates

**Files:**
- Modify: `CLAUDE.md`
- Create: `docs/user-guide/content/zh/pages/overview/dashboard.html`
- Create: `docs/user-guide/content/en/pages/overview/dashboard.html`
- Modify: `docs/user-guide/assets/app.js`

- [ ] **Step 1: Update CLAUDE.md**

In the macOS App architecture section, after the `Views/LiveReadiness/` entry, add or update the Dashboard entry:

```markdown
- **`Views/Dashboard/DashboardView`** — Bento Command Grid layout: `DashboardStatusBar` (infrastructure status) → `AccountHeroCard` (equity + PnL + sparkline) → `AvailableActionsRow` → 3-column metrics (Runtime + Readiness + Risk) → `PositionRiskTable` → 2-column feeds (Decisions + Alerts) → `EmergencyActionBar` (sticky bottom). Driven by `DashboardViewModel` consuming single `GET /api/overview/dashboard` BFF endpoint.
```

- [ ] **Step 2: Create Chinese user guide chapter**

Create `docs/user-guide/content/zh/pages/overview/dashboard.html` with a chapter explaining the Dashboard's 10 components, what each shows, and how to use the emergency stop.

- [ ] **Step 3: Create English user guide chapter**

Create `docs/user-guide/content/en/pages/overview/dashboard.html` — English translation of the above.

- [ ] **Step 4: Register chapters in app.js NAV**

In `docs/user-guide/assets/app.js`, add to the NAV array under the OVERVIEW section:

```javascript
{ path: 'pages/overview/dashboard', title: '总览仪表盘', titleEn: 'Dashboard' },
```

- [ ] **Step 5: Commit docs**

```bash
git add CLAUDE.md docs/user-guide/
git commit -m "docs: update CLAUDE.md + add Dashboard user guide chapters (zh/en)"
```

---

## Task 9: Final Verification

- [ ] **Step 1: Run backend tests**

Run: `cd backend && python3 -m pytest tests/ -q --tb=short`
Expected: All ~915+ tests pass, coverage ≥ 30%.

- [ ] **Step 2: Run frontend build**

Run: `cd macos-app && swift build`
Expected: Clean build, no errors.

- [ ] **Step 3: Run frontend tests**

Run: `cd macos-app && swift test`
Expected: All tests pass.

- [ ] **Step 4: Visual verification**

Run the app (`cd macos-app && swift run`), navigate to Dashboard, verify:
- StatusBar shows infrastructure metrics
- Hero card shows equity + PnL with sparkline
- Available Actions row appears with buttons
- 3-column metrics row (Runtime + Readiness + Risk)
- Position table with color stripes
- Decision feed + Alert timeline side by side
- Emergency bar at bottom
- Language toggle works (zh ↔ en)
- 30s polling refreshes data

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat(dashboard): complete Bento Command Grid redesign — PRD-aligned trading control tower"
```

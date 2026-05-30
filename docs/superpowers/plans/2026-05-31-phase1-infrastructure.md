# Phase 1: 基础设施层 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the infrastructure layer — dependency detection, token refresh, WebSocket, Settings persistence, error handling, setup wizard, and route expansion — so Phases 2-5 have a solid foundation.

**Architecture:** Backend adds a dependency checker service + WebSocket endpoint + Canvas CRUD. App adds token refresh interceptor, WebSocket manager, DependencyState, ErrorHandler, and SetupWizardView. All new app state objects are injected via SwiftUI Environment.

**Tech Stack:** Python 3.11 / FastAPI / SQLAlchemy (backend), Swift 5.9 / SwiftUI / macOS 26 (app)

---

## File Map

### Backend (Python)

| File | Action | Responsibility |
|------|--------|---------------|
| `backend/app/services/dependency_checker.py` | Create | Detect all dependency statuses |
| `backend/app/routers/system.py` | Modify | Add `GET /api/system/dependencies` endpoint |
| `backend/app/schemas/api.py` | Modify | Add `DependencyStatus` schema |
| `backend/tests/test_dependency_checker.py` | Create | Tests for dependency detection |
| `backend/tests/test_system_dependencies.py` | Create | Tests for the API endpoint |

### macOS App (Swift)

| File | Action | Responsibility |
|------|--------|---------------|
| `macos-app/PulseDesk/Models/Enums.swift` | Modify | Add 4 new AppRoute cases + SidebarSection expansion |
| `macos-app/PulseDesk/Models/Types.swift` | Modify | Add DependencyStatus, WebSocketMessage models |
| `macos-app/PulseDesk/Services/NetworkClient.swift` | Modify | Add 401 interceptor + token refresh |
| `macos-app/PulseDesk/Services/WebSocketManager.swift` | Create | WebSocket connection management |
| `macos-app/PulseDesk/Services/DependencyState.swift` | Create | Dependency status management |
| `macos-app/PulseDesk/Services/ErrorHandler.swift` | Create | Unified error handling |
| `macos-app/PulseDesk/Services/APISettings.swift` | Create | Settings API service |
| `macos-app/PulseDesk/Services/APIDependencies.swift` | Create | Dependencies API service |
| `macos-app/PulseDesk/Views/AppShell/AppShellView.swift` | Modify | Route expansion + inject new state objects |
| `macos-app/PulseDesk/Views/AppShell/SidebarView.swift` | Modify | Add new navigation entries |
| `macos-app/PulseDesk/Views/Backtest/BacktestView.swift` | Modify | Remove hardcoded MockNetworkClient |
| `macos-app/PulseDesk/Views/Setup/SetupWizardView.swift` | Create | First-run guided setup |
| `macos-app/PulseDesk/PulseDeskApp.swift` | Modify | Inject DependencyState, ErrorHandler, WebSocketManager |

---

## Task 1: Expand AppRoute and SidebarSection

**Files:**
- Modify: `macos-app/PulseDesk/Models/Enums.swift`
- Modify: `macos-app/PulseDesk/Views/AppShell/SidebarView.swift`
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift`

- [ ] **Step 1: Add new AppRoute cases**

In `Enums.swift`, replace the `AppRoute` enum:

```swift
enum AppRoute: String, CaseIterable, Identifiable {
    case dashboard, strategies, backtest, trades
    case aiStudio
    case sentiment, attribution, aiProviders, risk
    case settings

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "chart.line.uptrend.xyaxis"
        case .strategies: return "cpu"
        case .backtest: return "clock.arrow.circlepath"
        case .trades: return "list.bullet.rectangle"
        case .aiStudio: return "brain.head.profile"
        case .sentiment: return "waveform.path.ecg"
        case .attribution: return "chart.bar.doc.horizontal"
        case .aiProviders: return "server.rack"
        case .risk: return "shield.checkered"
        case .settings: return "gearshape"
        }
    }

    var label: String {
        switch self {
        case .dashboard: return "仪表盘"
        case .strategies: return "策略管理"
        case .backtest: return "回测中心"
        case .trades: return "交易记录"
        case .aiStudio: return "AI 工作室"
        case .sentiment: return "市场情绪"
        case .attribution: return "归因分析"
        case .aiProviders: return "AI 服务"
        case .risk: return "风险管理"
        case .settings: return "系统设置"
        }
    }

    var section: SidebarSection {
        switch self {
        case .dashboard, .trades, .risk: return .trading
        case .strategies, .backtest: return .strategy
        case .aiStudio, .sentiment, .attribution, .aiProviders: return .ai
        case .settings: return .system
        }
    }
}
```

- [ ] **Step 2: Update SidebarView to show all routes**

In `SidebarView.swift`, the sidebar already iterates `AppRoute.allCases` grouped by `SidebarSection`. Since `AppRoute` now includes the new cases, the sidebar will automatically show them. No code change needed in the iteration logic — just verify the new routes appear.

- [ ] **Step 3: Add route cases to AppShellView content router**

In `AppShellView.swift`, add placeholder cases to the `detailContent` switch:

```swift
case .sentiment:
    Text("市场情绪 — 即将推出")
        .font(PulseFonts.displayHeading)
        .foregroundStyle(colors.textMuted)
case .attribution:
    Text("归因分析 — 即将推出")
        .font(PulseFonts.displayHeading)
        .foregroundStyle(colors.textMuted)
case .aiProviders:
    Text("AI 服务管理 — 即将推出")
        .font(PulseFonts.displayHeading)
        .foregroundStyle(colors.textMuted)
case .risk:
    Text("风险管理 — 即将推出")
        .font(PulseFonts.displayHeading)
        .foregroundStyle(colors.textMuted)
```

- [ ] **Step 4: Verify build**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add macos-app/PulseDesk/Models/Enums.swift macos-app/PulseDesk/Views/AppShell/AppShellView.swift
git commit -m "feat(app): add sentiment/attribution/aiProviders/risk routes with placeholders"
```

---

## Task 2: Fix Hardcoded MockNetworkClient in BacktestView

**Files:**
- Modify: `macos-app/PulseDesk/Views/Backtest/BacktestView.swift`

- [ ] **Step 1: Add environment networkClient and use it**

In `BacktestView.swift`, the `.task` block at line 52 uses `MockNetworkClient()`. Replace it with the environment-injected client.

Add the environment declaration after the existing `@Environment` lines:

```swift
@Environment(\.networkClient) private var networkClient
```

Replace the `.task` block:

```swift
.task {
    do {
        strategies = try await APIStrategies(client: networkClient).list()
    } catch {}
}
```

- [ ] **Step 2: Verify build**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add macos-app/PulseDesk/Views/Backtest/BacktestView.swift
git commit -m "fix(app): use environment networkClient in BacktestView instead of hardcoded mock"
```

---

## Task 3: Fix ConsoleToolbar Hardcoded Metrics

**Files:**
- Modify: `macos-app/PulseDesk/Views/AppShell/AppShellView.swift`

- [ ] **Step 1: Add systemStatus state to ConsoleToolbar**

The `ConsoleToolbar` struct at line 99 has hardcoded metric values. Replace the `systemMetrics` section with dynamic data from `DashboardViewModel`.

Add an environment reference to the DashboardViewModel. Since ViewModels are created in `AppShellView` and not easily passed to `ConsoleToolbar`, use a simpler approach: make ConsoleToolbar accept an optional `SystemStatus?` parameter.

Replace the `ConsoleToolbar` struct:

```swift
struct ConsoleToolbar: View {
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    @Environment(\.networkClient) private var networkClient
    @State private var currentTime = Date()
    @State private var showNotifications = false
    @State private var notificationViewModel: NotificationViewModel?

    var systemStatus: SystemStatus?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            // 面包屑 — 终端风格
            HStack(spacing: PulseSpacing.xxs) {
                Text("//")
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(PulseColors.accent)
                Text(appState.selectedRoute.label)
                    .font(PulseFonts.monoLabel)
                    .foregroundStyle(colors.textMuted)
                    .textCase(.uppercase)
                    .tracking(1.5)
            }

            Spacer()

            // 系统指标 — 从 SystemStatus 读取
            HStack(spacing: PulseSpacing.lg) {
                metricBadge(icon: "clock", value: systemStatus?.uptime ?? "—")
                metricBadge(icon: "cpu", value: "\(systemStatus?.activeStrategies ?? 0) 策略")
                metricBadge(icon: "point.3.connected.trianglepath.connected", value: "\(systemStatus?.openPositions ?? 0) 持仓")
            }

            // 分隔点
            Circle()
                .fill(colors.textMuted)
                .frame(width: 2, height: 2)

            // 时钟
            Text(timeFormatter.string(from: currentTime))
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .onReceive(timer) { time in currentTime = time }

            // 连接状态
            StatusDot(status: systemStatus?.apiStatus == "connected" ? .online : .offline)

            // 搜索
            Button {
                appState.showCommandPalette.toggle()
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(colors.textMuted)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("k", modifiers: .command)

            // 通知
            Button {
                showNotifications.toggle()
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 13))
                        .foregroundStyle(colors.textMuted)

                    if let vm = notificationViewModel, vm.unreadCount > 0 {
                        Text(vm.unreadCount > 99 ? "99+" : "\(vm.unreadCount)")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(PulseColors.danger))
                            .offset(x: 5, y: -5)
                    }
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showNotifications) {
                if let vm = notificationViewModel {
                    NotificationPopover(viewModel: vm)
                }
            }

            // 用户
            Circle()
                .fill(PulseColors.accent.opacity(0.15))
                .frame(width: 22, height: 22)
                .overlay(
                    Text("T")
                        .font(PulseFonts.micro)
                        .foregroundStyle(PulseColors.accent)
                )
        }
        .padding(.horizontal, PulseSpacing.lg)
        .frame(height: 40)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5)
        }
        .onAppear {
            if notificationViewModel == nil {
                notificationViewModel = NotificationViewModel(client: networkClient)
            }
        }
    }

    private func metricBadge(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            Text(value)
                .font(PulseFonts.monoLabel)
        }
        .foregroundStyle(colors.textMuted)
    }
}
```

- [ ] **Step 2: Update AppShellView to pass systemStatus to ConsoleToolbar**

In `AppShellView.swift`, change the `ConsoleToolbar()` call to pass the system status:

```swift
ConsoleToolbar(systemStatus: dashboardVM?.systemStatus)
```

The `DashboardViewModel` already loads `SystemStatus` — check if it stores it. If not, add a `systemStatus: SystemStatus?` property and load it in `loadAll()`.

- [ ] **Step 3: Add systemStatus to DashboardViewModel**

In `DashboardViewModel.swift`, add:

```swift
var systemStatus: SystemStatus?
```

In the `loadAll()` method, add:

```swift
systemStatus = try? await dashboardAPI.getSystemStatus()
```

- [ ] **Step 4: Verify build**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add macos-app/PulseDesk/Views/AppShell/AppShellView.swift macos-app/PulseDesk/ViewModels/DashboardViewModel.swift
git commit -m "fix(app): replace hardcoded system metrics with live SystemStatus data"
```

---

## Task 4: Backend Dependency Checker Service

**Files:**
- Create: `backend/app/services/dependency_checker.py`
- Create: `backend/tests/test_dependency_checker.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_dependency_checker.py
import pytest
from app.services.dependency_checker import check_all_dependencies


def test_check_all_dependencies_returns_required_structure():
    result = check_all_dependencies()
    assert "required" in result
    assert "core_optional" in result
    assert "ml_models" in result
    assert "external_services" in result
    assert "readiness_score" in result
    assert isinstance(result["readiness_score"], float)
    assert 0.0 <= result["readiness_score"] <= 1.0


def test_database_always_ok():
    result = check_all_dependencies()
    assert result["required"]["database"]["status"] == "ok"


def test_core_optional_has_expected_keys():
    result = check_all_dependencies()
    for key in ["ccxt", "lightgbm", "transformers", "torch"]:
        assert key in result["core_optional"]
        assert "status" in result["core_optional"][key]
        assert result["core_optional"][key]["status"] in ("installed", "not_installed")


def test_external_services_has_expected_keys():
    result = check_all_dependencies()
    for key in ["freqtrade_api", "ollama", "openai", "anthropic", "telegram"]:
        assert key in result["external_services"]
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_dependency_checker.py -v`
Expected: FAIL with ModuleNotFoundError

- [ ] **Step 3: Write the implementation**

```python
# backend/app/services/dependency_checker.py
"""Detects availability of all external dependencies and ML models."""

import importlib
import os
from datetime import datetime, timezone


def _check_package(package_name: str) -> dict:
    """Check if a Python package is installed."""
    try:
        mod = importlib.import_module(package_name)
        version = getattr(mod, "__version__", "unknown")
        return {"status": "installed", "version": version}
    except ImportError:
        return {"status": "not_installed", "install_cmd": f"pip install {package_name}"}


def _check_ml_model(module_name: str, class_name: str | None = None) -> dict:
    """Check if an ML model module is available and loadable."""
    try:
        mod = importlib.import_module(module_name)
        if class_name:
            getattr(mod, class_name)
        return {"status": "loaded"}
    except ImportError:
        return {"status": "not_loaded", "fallback": "unavailable"}
    except Exception:
        return {"status": "not_loaded", "fallback": "unavailable"}


def _check_freqtrade_api() -> dict:
    """Check if Freqtrade API is reachable."""
    try:
        from app.config import settings
        import aiohttp
        import asyncio

        async def _ping():
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(
                        f"{settings.freqtrade_url}/api/v1/ping",
                        auth=aiohttp.BasicAuth(settings.freqtrade_username, settings.freqtrade_password),
                        timeout=aiohttp.ClientTimeout(total=3),
                    ) as resp:
                        if resp.status == 200:
                            return {"status": "connected", "url": settings.freqtrade_url}
            except Exception:
                pass
            return {"status": "disconnected", "url": settings.freqtrade_url}

        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop and loop.is_running():
            return {"status": "unknown", "url": settings.freqtrade_url, "detail": "cannot check from async context"}

        return asyncio.run(_ping())
    except Exception:
        return {"status": "disconnected"}


def _check_ollama() -> dict:
    """Check if Ollama is reachable."""
    try:
        from app.config import settings
        import aiohttp
        import asyncio

        ollama_url = os.environ.get("OLLAMA_URL", "http://localhost:11434")

        async def _ping():
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(
                        f"{ollama_url}/api/tags",
                        timeout=aiohttp.ClientTimeout(total=3),
                    ) as resp:
                        if resp.status == 200:
                            data = await resp.json()
                            models = [m.get("name", "") for m in data.get("models", [])]
                            return {"status": "connected", "url": ollama_url, "models": models[:5]}
            except Exception:
                pass
            return {"status": "disconnected", "url": ollama_url}

        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop and loop.is_running():
            return {"status": "unknown", "url": ollama_url}

        return asyncio.run(_ping())
    except Exception:
        return {"status": "disconnected"}


def _check_llm_provider(env_key: str, provider_name: str) -> dict:
    """Check if an LLM provider API key is configured."""
    key = os.environ.get(env_key, "")
    if key:
        return {"status": "configured", "requires": env_key}
    return {"status": "not_configured", "requires": env_key}


def check_all_dependencies() -> dict:
    """Return full dependency status report."""
    # Required
    required = {
        "database": {"status": "ok", "detail": "SQLite (auto-created)"},
    }

    # Core optional packages
    core_optional = {
        "ccxt": _check_package("ccxt"),
        "lightgbm": _check_package("lightgbm"),
        "transformers": _check_package("transformers"),
        "torch": _check_package("torch"),
    }

    # ML models
    ml_models = {
        "finbert": _check_ml_model("transformers", "pipeline"),
        "chronos": _check_ml_model("chronos", "ChronosPipeline"),
        "timesfm": _check_ml_model("timesfm", "TimesFm"),
        "shap": _check_ml_model("shap", "TreeExplainer"),
    }

    # External services
    external_services = {
        "freqtrade_api": _check_freqtrade_api(),
        "freqtrade_db": {
            "status": "available" if os.path.exists(
                os.environ.get("FREQTRADE_DB_PATH", "")
            ) else "not_found",
        },
        "ollama": _check_ollama(),
        "openai": _check_llm_provider("OPENAI_API_KEY", "openai"),
        "anthropic": _check_llm_provider("ANTHROPIC_API_KEY", "anthropic"),
        "deepseek": _check_llm_provider("DEEPSEEK_API_KEY", "deepseek"),
        "qwen": _check_llm_provider("QWEN_API_KEY", "qwen"),
        "zhipu": _check_llm_provider("ZHIPU_API_KEY", "zhipu"),
        "moonshot": _check_llm_provider("MOONSHOT_API_KEY", "moonshot"),
        "mimo": _check_llm_provider("MIMO_API_KEY", "mimo"),
        "gemini": _check_llm_provider("GEMINI_API_KEY", "gemini"),
        "groq": _check_llm_provider("GROQ_API_KEY", "groq"),
        "azure_openai": _check_llm_provider("AZURE_OPENAI_API_KEY", "azure_openai"),
        "telegram": {
            "status": "dry_run",
            "detail": "Configure TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID to enable",
        },
    }

    # Calculate readiness score
    total = 0
    scored = 0
    for group in [required, core_optional, ml_models, external_services]:
        for key, val in group.items():
            total += 1
            if isinstance(val, dict):
                s = val.get("status", "")
                if s in ("ok", "installed", "loaded", "connected", "configured", "available"):
                    scored += 1
                elif s == "dry_run":
                    scored += 0.5

    readiness_score = round(scored / max(total, 1), 2)

    return {
        "required": required,
        "core_optional": core_optional,
        "ml_models": ml_models,
        "external_services": external_services,
        "readiness_score": readiness_score,
        "checked_at": datetime.now(timezone.utc).isoformat(),
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python3 -m pytest tests/test_dependency_checker.py -v`
Expected: All 4 tests PASS

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/dependency_checker.py backend/tests/test_dependency_checker.py
git commit -m "feat(backend): add dependency checker service with full detection"
```

---

## Task 5: Add GET /api/system/dependencies Endpoint

**Files:**
- Modify: `backend/app/routers/system.py`
- Create: `backend/tests/test_system_dependencies.py`

- [ ] **Step 1: Write the failing test**

```python
# backend/tests/test_system_dependencies.py
import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.mark.asyncio
async def test_get_dependencies_returns_200():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/system/dependencies")
    assert resp.status_code == 200
    data = resp.json()
    assert "required" in data
    assert "core_optional" in data
    assert "ml_models" in data
    assert "external_services" in data
    assert "readiness_score" in data


@pytest.mark.asyncio
async def test_readiness_score_is_float():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/system/dependencies")
    data = resp.json()
    assert isinstance(data["readiness_score"], float)
    assert 0.0 <= data["readiness_score"] <= 1.0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && python3 -m pytest tests/test_system_dependencies.py -v`
Expected: FAIL with 404 (endpoint doesn't exist yet)

- [ ] **Step 3: Add the endpoint to system.py**

In `backend/app/routers/system.py`, add after the existing `get_system_status` function:

```python
@router.get("/dependencies")
async def get_dependencies():
    from app.services.dependency_checker import check_all_dependencies
    return check_all_dependencies()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && python3 -m pytest tests/test_system_dependencies.py -v`
Expected: All tests PASS

- [ ] **Step 5: Run all existing tests to check for regressions**

Run: `cd backend && python3 -m pytest tests/ -q`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/system.py backend/tests/test_system_dependencies.py
git commit -m "feat(backend): add GET /api/system/dependencies endpoint"
```

---

## Task 6: Token Refresh in LiveNetworkClient

**Files:**
- Modify: `macos-app/PulseDesk/Services/NetworkClient.swift`

- [ ] **Step 1: Add refreshTokenIfNeeded to LiveNetworkClient**

In `NetworkClient.swift`, add a private method to `LiveNetworkClient`:

```swift
private func refreshTokenIfNeeded() async throws {
    guard let refreshToken = KeychainService.refreshToken else { return }

    let url = baseURL.appendingPathComponent("/auth/refresh")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        // Refresh failed — clear tokens
        KeychainService.accessToken = nil
        KeychainService.refreshToken = nil
        throw APIError.httpError(statusCode: 401, message: "Token refresh failed")
    }

    let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)
    KeychainService.accessToken = tokenResponse.accessToken
    KeychainService.refreshToken = tokenResponse.refreshToken
}
```

- [ ] **Step 2: Add 401 retry logic to performRequest**

Replace the `performRequest` method in `LiveNetworkClient`:

```swift
private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
    var currentRequest = request

    // First attempt
    let (data, response) = try await URLSession.shared.data(for: currentRequest)
    guard let httpResponse = response as? HTTPURLResponse else {
        throw APIError.networkError(URLError(.badServerResponse))
    }

    // If 401, try refreshing token once
    if httpResponse.statusCode == 401, KeychainService.refreshToken != nil {
        try await refreshTokenIfNeeded()

        // Retry with new token
        currentRequest.setValue("Bearer \(KeychainService.accessToken ?? "")", forHTTPHeaderField: "Authorization")
        let (retryData, retryResponse) = try await URLSession.shared.data(for: currentRequest)
        guard let retryHttpResponse = retryResponse as? HTTPURLResponse, retryHttpResponse.statusCode < 400 else {
            let code = (retryResponse as? HTTPURLResponse)?.statusCode ?? 0
            let message = String(data: retryData, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(statusCode: code, message: message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: retryData)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    guard httpResponse.statusCode < 400 else {
        let message = String(data: data, encoding: .utf8) ?? "Unknown error"
        throw APIError.httpError(statusCode: httpResponse.statusCode, message: message)
    }
    do {
        return try JSONDecoder().decode(T.self, from: data)
    } catch {
        throw APIError.decodingError(error)
    }
}
```

- [ ] **Step 3: Verify build**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Services/NetworkClient.swift
git commit -m "feat(app): add 401 interceptor with automatic token refresh"
```

---

## Task 7: ErrorHandler Service

**Files:**
- Create: `macos-app/PulseDesk/Services/ErrorHandler.swift`
- Modify: `macos-app/PulseDesk/PulseDeskApp.swift`

- [ ] **Step 1: Create ErrorHandler**

```swift
// ErrorHandler.swift — 统一错误处理

import Foundation
import SwiftUI

@Observable
final class ErrorHandler {
    var currentError: AppError?
    var showError = false

    func handle(_ error: Error, context: String = "") {
        let appError: AppError
        if let apiError = error as? APIError {
            switch apiError {
            case .httpError(let code, let msg):
                if code == 401 {
                    appError = .auth(msg)
                } else if code >= 500 {
                    appError = .server(msg)
                } else {
                    appError = .business(msg)
                }
            case .networkError:
                appError = .network("网络连接失败，请检查后端服务")
            case .decodingError:
                appError = .server("数据解析错误")
            case .invalidURL:
                appError = .server("请求地址无效")
            }
        } else {
            appError = .business(error.localizedDescription)
        }

        DispatchQueue.main.async {
            self.currentError = appError
            self.showError = true
        }
    }

    func dismiss() {
        currentError = nil
        showError = false
    }
}

enum AppError: Error, LocalizedError {
    case network(String)
    case auth(String)
    case business(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .network(let msg): return msg
        case .auth(let msg): return "认证失败: \(msg)"
        case .business(let msg): return msg
        case .server(let msg): return "服务异常: \(msg)"
        }
    }

    var icon: String {
        switch self {
        case .network: return "wifi.slash"
        case .auth: return "lock.shield"
        case .business: return "exclamationmark.triangle"
        case .server: return "server.rack"
        }
    }

    var color: Color {
        switch self {
        case .network: return PulseColors.warning
        case .auth: return PulseColors.danger
        case .business: return PulseColors.warning
        case .server: return PulseColors.danger
        }
    }
}
```

- [ ] **Step 2: Inject ErrorHandler in PulseDeskApp**

In `PulseDeskApp.swift`, add `@State private var errorHandler = ErrorHandler()` and inject it into the environment:

```swift
.environment(errorHandler)
```

- [ ] **Step 3: Verify build**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Services/ErrorHandler.swift macos-app/PulseDesk/PulseDeskApp.swift
git commit -m "feat(app): add unified ErrorHandler with environment injection"
```

---

## Task 8: WebSocket Manager (Backend Endpoint)

**Files:**
- Create: `backend/app/routers/websocket.py`
- Modify: `backend/app/main.py`

- [ ] **Step 1: Create WebSocket router**

```python
# backend/app/routers/websocket.py
"""WebSocket endpoint for real-time push notifications."""

import asyncio
import json
from typing import Set

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter(tags=["websocket"])


class ConnectionManager:
    """Manages WebSocket connections and channel subscriptions."""

    def __init__(self):
        self._connections: dict[WebSocket, Set[str]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket):
        await ws.accept()
        async with self._lock:
            self._connections[ws] = set()

    async def disconnect(self, ws: WebSocket):
        async with self._lock:
            self._connections.pop(ws, None)

    async def subscribe(self, ws: WebSocket, channels: list[str]):
        async with self._lock:
            if ws in self._connections:
                self._connections[ws].update(channels)

    async def unsubscribe(self, ws: WebSocket, channels: list[str]):
        async with self._lock:
            if ws in self._connections:
                self._connections[ws] -= set(channels)

    async def broadcast(self, channel: str, data: dict):
        message = json.dumps({"channel": channel, "data": data})
        async with self._lock:
            targets = [ws for ws, chs in self._connections.items() if channel in chs]
        for ws in targets:
            try:
                await ws.send_text(message)
            except Exception:
                await self.disconnect(ws)


manager = ConnectionManager()


@router.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await manager.connect(ws)
    try:
        while True:
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue

            action = msg.get("action")
            channels = msg.get("channels", [])

            if action == "subscribe" and isinstance(channels, list):
                await manager.subscribe(ws, channels)
                await ws.send_text(json.dumps({"action": "subscribed", "channels": channels}))
            elif action == "unsubscribe" and isinstance(channels, list):
                await manager.unsubscribe(ws, channels)
                await ws.send_text(json.dumps({"action": "unsubscribed", "channels": channels}))
            elif action == "ping":
                await ws.send_text(json.dumps({"action": "pong"}))
    except WebSocketDisconnect:
        await manager.disconnect(ws)
```

- [ ] **Step 2: Register WebSocket router in main.py**

In `backend/app/main.py`, add to the imports:

```python
from app.routers import websocket
```

Add after the other `app.include_router` calls:

```python
app.include_router(websocket.router)
```

- [ ] **Step 3: Verify backend starts**

Run: `cd backend && timeout 5 python3 -c "from app.main import app; print('OK')"`
Expected: OK

- [ ] **Step 4: Commit**

```bash
git add backend/app/routers/websocket.py backend/app/main.py
git commit -m "feat(backend): add WebSocket endpoint with channel subscription"
```

---

## Task 9: WebSocket Manager (App Side)

**Files:**
- Create: `macos-app/PulseDesk/Services/WebSocketManager.swift`
- Modify: `macos-app/PulseDesk/PulseDeskApp.swift`

- [ ] **Step 1: Create WebSocketManager**

```swift
// WebSocketManager.swift — WebSocket 连接管理
// 自动重连、心跳、频道订阅

import Foundation
import SwiftUI

@Observable
final class WebSocketManager: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isConnected = false
    private var subscribedChannels: Set<String> = []
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private let baseURL: URL

    var onMessage: ((String, Any) -> Void)?
    var connectionState: ConnectionState = .disconnected

    enum ConnectionState {
        case connected, disconnected, reconnecting
    }

    init(baseURL: URL = URL(string: "ws://localhost:8000")!) {
        self.baseURL = baseURL
        super.init()
    }

    func connect() {
        let wsURL = baseURL.appendingPathComponent("/ws")
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        webSocket = session?.webSocketTask(with: wsURL)
        webSocket?.resume()
        connectionState = .reconnecting
        receiveMessage()
    }

    func disconnect() {
        heartbeatTimer?.invalidate()
        reconnectTimer?.invalidate()
        webSocket?.cancel(with: .normalClosure, reason: nil)
        webSocket = nil
        isConnected = false
        connectionState = .disconnected
    }

    func subscribe(_ channels: [String]) {
        subscribedChannels.formUnion(channels)
        let msg = ["action": "subscribe", "channels": channels] as [String: Any]
        send(json: msg)
    }

    func unsubscribe(_ channels: [String]) {
        subscribedChannels.subtract(channels)
        let msg = ["action": "unsubscribe", "channels": channels] as [String: Any]
        send(json: msg)
    }

    private func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let str = String(data: data, encoding: .utf8) else { return }
        webSocket?.send(.string(str)) { _ in }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                switch msg {
                case .string(let text):
                    self.handleMessage(text)
                default:
                    break
                }
                self.receiveMessage()
            case .failure:
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String else { return }

        if action == "pong" { return }

        if let channel = json["channel"] as? String {
            onMessage?(channel, json["data"] as Any)
        }
    }

    private func handleDisconnect() {
        isConnected = false
        connectionState = .disconnected
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.connect()
        }
        connectionState = .reconnecting
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.send(json: ["action": "ping"])
        }
    }

    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        connectionState = .connected
        startHeartbeat()

        // Re-subscribe to channels after reconnect
        if !subscribedChannels.isEmpty {
            subscribe(Array(subscribedChannels))
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        handleDisconnect()
    }
}
```

- [ ] **Step 2: Inject WebSocketManager in PulseDeskApp**

In `PulseDeskApp.swift`, add `@State private var wsManager = WebSocketManager()` and inject:

```swift
.environment(wsManager)
```

- [ ] **Step 3: Verify build**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Services/WebSocketManager.swift macos-app/PulseDesk/PulseDeskApp.swift
git commit -m "feat(app): add WebSocketManager with auto-reconnect and channel subscription"
```

---

## Task 10: DependencyState Service

**Files:**
- Create: `macos-app/PulseDesk/Services/DependencyState.swift`
- Create: `macos-app/PulseDesk/Services/APIDependencies.swift`
- Modify: `macos-app/PulseDesk/PulseDeskApp.swift`

- [ ] **Step 1: Create APIDependencies service**

```swift
// APIDependencies.swift — 依赖检测 API

import Foundation

struct DependencyResponse: Decodable {
    let required: [String: DependencyItem]
    let coreOptional: [String: DependencyItem]
    let mlModels: [String: DependencyItem]
    let externalServices: [String: DependencyItem]
    let readinessScore: Double
    let checkedAt: String?

    enum CodingKeys: String, CodingKey {
        case required
        case coreOptional = "core_optional"
        case mlModels = "ml_models"
        case externalServices = "external_services"
        case readinessScore = "readiness_score"
        case checkedAt = "checked_at"
    }
}

struct DependencyItem: Decodable {
    let status: String
    let version: String?
    let detail: String?
    let installCmd: String?
    let fallback: String?
    let url: String?
    let requires: String?

    enum CodingKeys: String, CodingKey {
        case status, version, detail, fallback, url, requires
        case installCmd = "install_cmd"
    }
}

extension NetworkClientProtocol {
    func fetchDependencies() async throws -> DependencyResponse {
        try await get("/api/system/dependencies", mock: {
            DependencyResponse(
                required: ["database": DependencyItem(status: "ok", version: nil, detail: "SQLite", installCmd: nil, fallback: nil, url: nil, requires: nil)],
                coreOptional: [:],
                mlModels: [:],
                externalServices: [:],
                readinessScore: 1.0,
                checkedAt: nil
            )
        })
    }
}
```

- [ ] **Step 2: Create DependencyState**

```swift
// DependencyState.swift — 依赖状态管理

import Foundation
import SwiftUI

@Observable
final class DependencyState {
    private let client: any NetworkClientProtocol
    private var refreshTimer: Timer?

    var response: DependencyResponse?
    var isLoading = false
    var lastError: String?

    var readinessScore: Double { response?.readinessScore ?? 0 }
    var showSetupWizard: Bool { readinessScore < 0.5 }

    init(client: any NetworkClientProtocol) {
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            response = try await client.fetchDependencies()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func startPeriodicRefresh(interval: TimeInterval = 300) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { await self?.load() }
        }
    }

    func stopRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func isAvailable(_ key: String, in group: String) -> Bool {
        guard let response else { return false }
        let dict: [String: DependencyItem]?
        switch group {
        case "core_optional": dict = response.coreOptional
        case "ml_models": dict = response.mlModels
        case "external_services": dict = response.externalServices
        default: dict = nil
        }
        guard let item = dict?[key] else { return false }
        return ["ok", "installed", "loaded", "connected", "configured", "available"].contains(item.status)
    }

    func status(for key: String, in group: String) -> String {
        guard let response else { return "unknown" }
        let dict: [String: DependencyItem]?
        switch group {
        case "core_optional": dict = response.coreOptional
        case "ml_models": dict = response.mlModels
        case "external_services": dict = response.externalServices
        default: dict = nil
        }
        return dict?[key]?.status ?? "unknown"
    }
}
```

- [ ] **Step 3: Inject DependencyState in PulseDeskApp**

In `PulseDeskApp.swift`, create and inject `DependencyState`. It needs the networkClient, so create it in the body and use `.task` to load:

Add `@State private var dependencyState: DependencyState?` and initialize it when the network client is available. Inject via `.environment(dependencyState)`.

- [ ] **Step 4: Verify build**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add macos-app/PulseDesk/Services/DependencyState.swift macos-app/PulseDesk/Services/APIDependencies.swift macos-app/PulseDesk/PulseDeskApp.swift
git commit -m "feat(app): add DependencyState with periodic refresh and readiness scoring"
```

---

## Task 11: Settings Persistence (App Side)

**Files:**
- Create: `macos-app/PulseDesk/Services/APISettings.swift`
- Modify: `macos-app/PulseDesk/PulseDeskApp.swift` (SettingsState)

- [ ] **Step 1: Create APISettings service**

```swift
// APISettings.swift — Settings API 封装

import Foundation

struct UserSettingsResponse: Decodable {
    let id: Int
    let userId: Int
    let theme: String?
    let language: String?
    let notificationsEnabled: Bool?
    let defaultExchange: String?
    let defaultMarket: String?
    let riskTolerance: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case theme, language
        case notificationsEnabled = "notifications_enabled"
        case defaultExchange = "default_exchange"
        case defaultMarket = "default_market"
        case riskTolerance = "risk_tolerance"
    }
}

struct UserSettingsUpdateBody: Encodable {
    let theme: String?
    let language: String?
    let notificationsEnabled: Bool?
    let defaultExchange: String?
    let defaultMarket: String?
    let riskTolerance: String?

    enum CodingKeys: String, CodingKey {
        case theme, language
        case notificationsEnabled = "notifications_enabled"
        case defaultExchange = "default_exchange"
        case defaultMarket = "default_market"
        case riskTolerance = "risk_tolerance"
    }
}

extension NetworkClientProtocol {
    func fetchSettings() async throws -> UserSettingsResponse {
        try await get("/auth/settings", mock: {
            UserSettingsResponse(id: 1, userId: 1, theme: "dark", language: "zh-CN", notificationsEnabled: true, defaultExchange: "binance", defaultMarket: "crypto", riskTolerance: "medium")
        })
    }

    func updateSettings(_ body: UserSettingsUpdateBody) async throws -> UserSettingsResponse {
        try await put("/auth/settings", body: body, mock: {
            UserSettingsResponse(id: 1, userId: 1, theme: body.theme ?? "dark", language: body.language ?? "zh-CN", notificationsEnabled: body.notificationsEnabled ?? true, defaultExchange: body.defaultExchange ?? "binance", defaultMarket: body.defaultMarket ?? "crypto", riskTolerance: body.riskTolerance ?? "medium")
        })
    }
}
```

- [ ] **Step 2: Modify SettingsState to persist to backend**

The current `SettingsState` is a local-only `@Observable`. Add backend sync. Find the `SettingsState` class (likely in `PulseDeskApp.swift` or a separate file) and add:

```swift
private var client: (any NetworkClientProtocol)?
private var saveTask: Task<Void, Never>?

func configure(client: any NetworkClientProtocol) {
    self.client = client
    Task { await loadFromBackend() }
}

func loadFromBackend() async {
    guard let client else { return }
    do {
        let settings = try await client.fetchSettings()
        DispatchQueue.main.async {
            self.theme = settings.theme ?? "dark"
            self.language = settings.language ?? "zh-CN"
            self.notificationsEnabled = settings.notificationsEnabled ?? true
            self.defaultExchange = settings.defaultExchange ?? "binance"
            self.defaultMarket = settings.defaultMarket ?? "crypto"
            self.riskTolerance = settings.riskTolerance ?? "medium"
        }
    } catch {
        // Use local defaults on failure
    }
}

func scheduleSave() {
    saveTask?.cancel()
    saveTask = Task {
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return }
        await saveToBackend()
    }
}

func saveToBackend() async {
    guard let client else { return }
    let body = UserSettingsUpdateBody(
        theme: theme,
        language: language,
        notificationsEnabled: notificationsEnabled,
        defaultExchange: defaultExchange,
        defaultMarket: defaultMarket,
        riskTolerance: riskTolerance
    )
    _ = try? await client.updateSettings(body)
}
```

- [ ] **Step 3: Verify build**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Services/APISettings.swift macos-app/PulseDesk/PulseDeskApp.swift
git commit -m "feat(app): add Settings persistence with backend sync"
```

---

## Task 12: SetupWizardView

**Files:**
- Create: `macos-app/PulseDesk/Views/Setup/SetupWizardView.swift`
- Modify: `macos-app/PulseDesk/PulseDeskApp.swift`

- [ ] **Step 1: Create SetupWizardView**

```swift
// SetupWizardView.swift — 首次启动引导页

import SwiftUI

struct SetupWizardView: View {
    @Environment(DependencyState.self) private var depState
    @Environment(\.networkClient) private var networkClient
    @Environment(PulseColors.self) private var colors
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep = 0
    @State private var setupCompleted = false

    private let totalSteps = 3

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: PulseSpacing.sm) {
                Text("PulseDesk 配置向导")
                    .font(PulseFonts.displayTitle)
                    .foregroundStyle(colors.textPrimary)

                Text("完成以下步骤以启用全部功能")
                    .font(PulseFonts.body)
                    .foregroundStyle(colors.textMuted)

                // Progress bar
                HStack(spacing: 4) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(i <= currentStep ? PulseColors.accent : colors.textMuted.opacity(0.3))
                            .frame(height: 3)
                    }
                }
                .padding(.top, PulseSpacing.sm)
            }
            .padding(PulseSpacing.xl)

            // Step content
            TabView(selection: $currentStep) {
                step1CoreDeps.tag(0)
                step2AIServices.tag(1)
                step3TradingServices.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: currentStep)

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("上一步") { currentStep -= 1 }
                        .buttonStyle(.plain)
                        .foregroundStyle(colors.textSecondary)
                }

                Spacer()

                Button(currentStep < totalSteps - 1 ? "下一步" : "完成配置") {
                    if currentStep < totalSteps - 1 {
                        currentStep += 1
                    } else {
                        completeSetup()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(PulseColors.accent)
            }
            .padding(PulseSpacing.lg)
        }
        .frame(width: 600, height: 500)
        .background(colors.background)
    }

    // MARK: - Step 1: Core Dependencies
    private var step1CoreDeps: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text("核心依赖")
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

            Text("以下 Python 包影响核心功能。缺失的包会自动降级，但建议安装以获得完整体验。")
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)

            ScrollView {
                VStack(spacing: PulseSpacing.sm) {
                    dependencyRow(name: "ccxt", group: "core_optional", desc: "实时市场数据")
                    dependencyRow(name: "lightgbm", group: "core_optional", desc: "FreqAI 模型训练")
                    dependencyRow(name: "transformers", group: "core_optional", desc: "FinBERT 情绪分析")
                    dependencyRow(name: "torch", group: "core_optional", desc: "ML 推理引擎")
                }
            }

            Spacer()
        }
        .padding(PulseSpacing.xl)
    }

    // MARK: - Step 2: AI Services
    private var step2AIServices: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text("AI 服务")
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

            Text("配置 LLM Provider 以启用 RAG 策略生成、AI 研究等功能。Ollama 本地运行无需 Key。")
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)

            ScrollView {
                VStack(spacing: PulseSpacing.sm) {
                    dependencyRow(name: "ollama", group: "external_services", desc: "本地 LLM (默认启用)")
                    dependencyRow(name: "openai", group: "external_services", desc: "GPT-4o")
                    dependencyRow(name: "deepseek", group: "external_services", desc: "国内主力")
                    dependencyRow(name: "anthropic", group: "external_services", desc: "Claude")
                }
            }

            Spacer()
        }
        .padding(PulseSpacing.xl)
    }

    // MARK: - Step 3: Trading Services
    private var step3TradingServices: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.md) {
            Text("交易服务")
                .font(PulseFonts.displayHeading)
                .foregroundStyle(colors.textPrimary)

            Text("Freqtrade 提供实盘交易数据。Telegram 用于推送通知。两者均为可选。")
                .font(PulseFonts.body)
                .foregroundStyle(colors.textMuted)

            ScrollView {
                VStack(spacing: PulseSpacing.sm) {
                    dependencyRow(name: "freqtrade_api", group: "external_services", desc: "交易引擎")
                    dependencyRow(name: "telegram", group: "external_services", desc: "消息推送")
                }
            }

            Spacer()
        }
        .padding(PulseSpacing.xl)
    }

    // MARK: - Dependency Row
    private func dependencyRow(name: String, group: String, desc: String) -> some View {
        HStack {
            Image(systemName: depState.isAvailable(name, in: group) ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(depState.isAvailable(name, in: group) ? PulseColors.accent : PulseColors.danger)

            VStack(alignment: .leading) {
                Text(name)
                    .font(PulseFonts.bodyMedium)
                    .foregroundStyle(colors.textPrimary)
                Text(desc)
                    .font(PulseFonts.caption)
                    .foregroundStyle(colors.textMuted)
            }

            Spacer()

            Text(depState.status(for: name, in: group))
                .font(PulseFonts.caption)
                .foregroundStyle(depState.isAvailable(name, in: group) ? PulseColors.accent : colors.textMuted)
        }
        .padding(PulseSpacing.sm)
        .background(colors.cardBackground)
        .cornerRadius(PulseRadii.sm)
    }

    private func completeSetup() {
        UserDefaults.standard.set(true, forKey: "setupCompleted")
        dismiss()
    }
}
```

- [ ] **Step 2: Show SetupWizardView on first launch**

In `PulseDeskApp.swift`, in the `ContentView`, after the `AppShellView` is shown, check if setup is needed:

```swift
.sheet(isPresented: .constant(!UserDefaults.standard.bool(forKey: "setupCompleted") && dependencyState?.showSetupWizard == true)) {
    SetupWizardView()
}
```

- [ ] **Step 3: Verify build**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add macos-app/PulseDesk/Views/Setup/SetupWizardView.swift macos-app/PulseDesk/PulseDeskApp.swift
git commit -m "feat(app): add SetupWizardView with 3-step guided setup"
```

---

## Task 13: Run Full Test Suite and Final Commit

- [ ] **Step 1: Run backend tests**

Run: `cd backend && python3 -m pytest tests/ -q --cov=app`
Expected: All tests pass, coverage >= 30%

- [ ] **Step 2: Run macOS build**

Run: `cd macos-app && swift build`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Fix any failures**

If tests fail, fix and re-run. If build fails, fix type errors.

- [ ] **Step 4: Final commit if any fixes needed**

```bash
git add -A
git commit -m "fix: resolve test/build failures from Phase 1 infrastructure changes"
```

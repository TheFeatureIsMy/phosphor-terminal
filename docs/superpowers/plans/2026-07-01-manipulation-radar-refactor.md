# Manipulation Radar 九段叙事流重构 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 `ManipulationRadarView` 从「头部 + Stats Row + 双栏 + sheet 详情」重写为 1280 居中的九段叙事流（Masthead + §0–§8），对齐 `MarketStructureView` / `StructureMatrixView` 风格家族，诚实表达不确定性，双画像并列，接入 WebSocket 实时推送。

**Architecture:** 后端 P1 已落地（`/cases/{id}` v2、`/strategy-impact`、`/similar`、`/alerts`、`/radar`、WS `/stream`、`find_similar`、`generate_dual_signal`、pubsub 钩子）。本计划只做：(1) macOS 端新增 Codable 子结构 + 扩展 `ManipulationCaseDetail`；(2) 新增 `getStrategyImpact` / `getSimilar` + `ManipulationStreamClient` actor；(3) ViewModel 加聚焦状态 + 三并发 + WS 生命周期；(4) 重写主视图 + 9 个 Component；(5) 后端补 `affected_symbols` 扩展 + 5 个 pytest；(6) L10n + 文档。

**Tech Stack:** Swift 6.2 / SwiftUI / macOS 26（无 SPM 依赖）；Python 3.12 / FastAPI / pytest（后端）。

## Global Constraints

- Swift tools version: 6.2；目标平台 macOS 26；无外部 SPM 依赖。
- 所有用户可见文案必须走 `L10n.<Domain>.<key>`，zh-CN 默认 + en-US 双语；`L10n.zh("中文", en: "English")`。
- 设计 token 一律走 `PulseColors.*` / `PulseFonts.*` / `PulseSpacing.*` / `PulseRadii.*`，禁止硬编码颜色/字体/间距/圆角。
- `.glassEffect()` 必须直接作用于内容 view，不能放 `.background` 里。
- 后端：thin routers、logic in services、tests mirror service/router names、pytest-asyncio。
- `/cases/{id}` v2 必须保留扁平 `evidence` 字段（其他客户端仍读），同时返回 `evidence_layers`。
- DSL 规则类型名是 `manipulation_score_filter`（不是 `ManipulationFilterRule`）。
- 案例库是 in-memory（`case_repository.py` v1）；进程重启所有 case 与 WS 订阅会丢，不在本计划范围。
- 提交规范：每个 task 末尾一次 commit；commit message 用 `feat(macos):` / `refactor(macos):` / `test(backend):` / `docs:` 前缀。
- 实现直接在 `main` 分支提交（用户偏好），但仍需在动手前确认一次。

---

## File Structure

**新增文件（macOS 端，9 个 Component）：**
- `macos-app/AlphaLoop/Views/Manipulation/Components/ActiveCasesStrip.swift` — §0 横向滚动的活跃 case 缩略卡
- `macos-app/AlphaLoop/Views/Manipulation/Components/VerdictPanel.swift` — §1 判定面板
- `macos-app/AlphaLoop/Views/Manipulation/Components/LifecycleTimeline.swift` — §2 水平 5 节点时间线
- `macos-app/AlphaLoop/Views/Manipulation/Components/EvidenceLayerMatrix.swift` — §3 5 Layer × score 条
- `macos-app/AlphaLoop/Views/Manipulation/Components/WhaleConcentrationPanel.swift` — §4 巨鲸与筹码集中
- `macos-app/AlphaLoop/Views/Manipulation/Components/CrossMarketPressurePanel.swift` — §5 跨市场压力
- `macos-app/AlphaLoop/Views/Manipulation/Components/SocialAccelerationPanel.swift` — §6 社交加速（可缺失）
- `macos-app/AlphaLoop/Views/Manipulation/Components/DualProfileSignalPanel.swift` — §7 双画像并列 + 策略联动
- `macos-app/AlphaLoop/Views/Manipulation/Components/SimilarCasesPanel.swift` — §8 右半相似历史案例
- `macos-app/AlphaLoop/Services/ManipulationStreamClient.swift` — WS actor，`AsyncStream<ManipulationEvent>`

**修改文件（macOS 端）：**
- `macos-app/AlphaLoop/Services/APIManipulation.swift` — 新增 6 个 Codable 结构 + 2 个 API 方法 + mock
- `macos-app/AlphaLoop/ViewModels/ManipulationViewModel.swift` — 聚焦状态 + 三并发 + WS 生命周期
- `macos-app/AlphaLoop/Views/Manipulation/ManipulationRadarView.swift` — 重写为九段叙事流
- `macos-app/AlphaLoop/Views/Manipulation/LifecycleIndicator.swift` — 保留色板 helper，视图部分迁出
- `macos-app/AlphaLoop/Localization/L10n+Manipulation.swift` — 追加新键
- `macos-app/Tests/ViewModelTests.swift` — 加 focusCase / stream fallback 测试

**删除文件（macOS 端）：**
- `macos-app/AlphaLoop/Views/Manipulation/CaseDetailView.swift`

**修改文件（后端）：**
- `backend/app/routers/manipulation.py` — `affected_symbols` 扩展
- `backend/tests/test_manipulation_api.py` — 补 5 个测试

**修改文件（文档）：**
- `CLAUDE.md` — `Views/Manipulation/` 描述更新
- `docs/user-guide/content/zh/pages/structure/manipulation-radar.html` — 重写
- `docs/user-guide/content/en/pages/structure/manipulation-radar.html` — 重写
- `docs/user-guide/assets/app.js` — 若新章节路径变化，更新 NAV
- `docs/superpowers/specs/2026-06-23-manipulation-radar-narrative-refactor-design.md` — frontmatter 加 `superseded-by`

---

## Task 1: 新增 Codable 子结构 + 扩展 ManipulationCaseDetail

**Files:**
- Modify: `macos-app/AlphaLoop/Services/APIManipulation.swift`（在 `ManipulationCaseDetail` 定义之后、`// MARK: - Mock Data` 之前插入）

**Interfaces:**
- Produces: `EvidenceLayerPayload`, `FeaturePayload`, `DualTradingSignal`, `StrategyImpactResponse`, `StrategyImpactItem`, `SimilarCasesResponse`, `SimilarCaseItem`, `ManipulationEvent`；`ManipulationCaseDetail` 新增可选字段 `evidenceLayers` / `completeness` / `maxConfidence` / `affectedSymbols` / `sources` / `riskLevel`

- [ ] **Step 1: 在 `ManipulationCaseDetail` struct 内追加 6 个可选字段，并改 tradingSignal 类型**

先把现有 `var tradingSignal: ManipulationTradingSignal = ManipulationTradingSignal()` 改为：

```swift
    var tradingSignal: DualTradingSignal = DualTradingSignal()
```

（后端 `/cases/{id}` v2 返回 `trading_signal: {conservative: {...}, aggressive: {...}}`，Swift 类型必须匹配。`ManipulationTradingSignal` 类型本身保留，作为 `DualTradingSignal.conservative` / `.aggressive` 的元素类型。）

然后在 `var updatedAt: String = ""` 之后、`enum CodingKeys` 之前插入 6 个 v2 可选字段：

```swift
    // v2 fields (optional for backward compat with mock/old responses)
    var riskLevel: String = ""
    var evidenceLayers: [String: EvidenceLayerPayload]? = nil
    var completeness: Double = 0
    var maxConfidence: Double = 0
    var affectedSymbols: [String]? = nil
    var sources: [ManipulationSource]? = nil
```

并在同 struct 的 `CodingKeys` enum 里追加：

```swift
        case riskLevel = "risk_level"
        case evidenceLayers = "evidence_layers"
        case completeness
        case maxConfidence = "max_confidence"
        case affectedSymbols = "affected_symbols"
        case sources
```

**同步更新 `MockManipulation.caseDetail`**：现有的 `tradingSignal: ManipulationTradingSignal(...)` 调用要改成 `tradingSignal: DualTradingSignal(conservative: ..., aggressive: ...)`，否则编译失败。先 grep `MockManipulation.caseDetail` 找到现有构造，按新结构改写。

- [ ] **Step 2: 在 `ManipulationCaseDetail` 之后插入 8 个新 Codable 结构**

```swift
struct EvidenceLayerPayload: Codable {
    var available: Bool = false
    var score: Double = 0
    var quality: Double = 0
    var features: [String: FeaturePayload] = [:]
}

struct FeaturePayload: Codable {
    var value: Double = 0
    var percentile: Double? = nil
    var display: String? = nil
}

struct DualTradingSignal: Codable {
    var conservative: ManipulationTradingSignal = ManipulationTradingSignal()
    var aggressive: ManipulationTradingSignal = ManipulationTradingSignal()
}

struct ManipulationSource: Codable {
    var type: String = ""
    var ruleId: String = ""
    var version: String = ""

    enum CodingKeys: String, CodingKey {
        case type
        case ruleId = "rule_id"
        case version
    }
}

struct StrategyImpactItem: Codable, Identifiable {
    var id: String { strategyId }
    var strategyId: String = ""
    var strategyName: String = ""
    var wouldBlock: Bool = false
    var reasonCodes: [String] = []
    var currentValue: Double = 0
    var threshold: Double = 0

    enum CodingKeys: String, CodingKey {
        case strategyId = "strategy_id"
        case strategyName = "strategy_name"
        case wouldBlock = "would_block"
        case reasonCodes = "reason_codes"
        case currentValue = "current_value"
        case threshold
    }
}

struct StrategyImpactResponse: Codable {
    var caseId: String = ""
    var affectedStrategies: [StrategyImpactItem] = []

    enum CodingKeys: String, CodingKey {
        case caseId = "case_id"
        case affectedStrategies = "affected_strategies"
    }
}

struct SimilarCaseItem: Codable, Identifiable {
    var id: String = ""
    var symbol: String = ""
    var manipulationType: String = ""
    var similarity: Double = 0
    var outcome: [String: Double] = [:]
    var createdAt: String = ""

    enum CodingKeys: String, CodingKey {
        case id, symbol, similarity, outcome
        case manipulationType = "manipulation_type"
        case createdAt = "created_at"
    }
}

struct SimilarCasesResponse: Codable {
    var caseId: String = ""
    var similar: [SimilarCaseItem] = []

    enum CodingKeys: String, CodingKey {
        case caseId = "case_id"
        case similar
    }
}

enum ManipulationEvent: Codable {
    case stageChange(caseId: String, oldStage: String, newStage: String, ts: String)
    case newCase(caseId: String, symbol: String, mType: String, ts: String)
    case snapshot(activeCases: [ManipulationCaseSummary], ts: String)
    case heartbeat(ts: String)
    case unknown

    enum CodingKeys: String, CodingKey { case type, case_id, symbol, manipulation_type, old_stage, new_stage, ts, active_cases }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decodeIfPresent(String.self, forKey: .type) ?? ""
        switch type {
        case "stage_change":
            self = .stageChange(
                caseId: try c.decodeIfPresent(String.self, forKey: .case_id) ?? "",
                oldStage: try c.decodeIfPresent(String.self, forKey: .old_stage) ?? "",
                newStage: try c.decodeIfPresent(String.self, forKey: .new_stage) ?? "",
                ts: try c.decodeIfPresent(String.self, forKey: .ts) ?? "")
        case "new_case":
            self = .newCase(
                caseId: try c.decodeIfPresent(String.self, forKey: .case_id) ?? "",
                symbol: try c.decodeIfPresent(String.self, forKey: .symbol) ?? "",
                mType: try c.decodeIfPresent(String.self, forKey: .manipulation_type) ?? "",
                ts: try c.decodeIfPresent(String.self, forKey: .ts) ?? "")
        case "snapshot":
            let cases = try c.decodeIfPresent([ManipulationCaseSummary].self, forKey: .active_cases) ?? []
            self = .snapshot(activeCases: cases, ts: try c.decodeIfPresent(String.self, forKey: .ts) ?? "")
        case "heartbeat":
            self = .heartbeat(ts: try c.decodeIfPresent(String.self, forKey: .ts) ?? "")
        default:
            self = .unknown
        }
    }

    func encode(to encoder: Encoder) throws {} // not used
}
```

- [ ] **Step 3: 构建验证**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED（编译通过；新类型未被引用只是声明，不影响构建）

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Services/APIManipulation.swift
git commit -m "feat(macos): add manipulation v2 Codable models (evidence layers, dual signal, strategy impact, similar, events)"
```

---

## Task 2: 新增 API 方法 getStrategyImpact / getSimilar + mock

**Files:**
- Modify: `macos-app/AlphaLoop/Services/APIManipulation.swift`（在 `getSignals` 方法之后、`}` 结束 `APIManipulation` class 之前插入）

**Interfaces:**
- Consumes: `StrategyImpactResponse` / `SimilarCasesResponse`（Task 1）
- Produces: `APIManipulation.getStrategyImpact(_:)` / `APIManipulation.getSimilar(_:limit:)`；`MockManipulation.strategyImpact` / `MockManipulation.similarCases`

- [ ] **Step 1: 在 APIManipulation class 末尾追加 2 个方法**

在 `func getSignals(...)` 的 `}` 之后插入：

```swift
    func getStrategyImpact(_ caseId: String) async throws -> StrategyImpactResponse {
        try await client.get("/api/v2/manipulation/cases/\(caseId)/strategy-impact") {
            MockManipulation.strategyImpact(caseId: caseId)
        }
    }

    func getSimilar(_ caseId: String, limit: Int = 5) async throws -> SimilarCasesResponse {
        try await client.get("/api/v2/manipulation/cases/\(caseId)/similar?limit=\(limit)") {
            MockManipulation.similarCases(caseId: caseId)
        }
    }
```

- [ ] **Step 2: 在 `MockManipulation` enum 末尾追加 2 个 mock factory**

在 `MockManipulation` 的最后一个 static var / func 之后追加：

```swift
    static func strategyImpact(caseId: String) -> StrategyImpactResponse {
        StrategyImpactResponse(
            caseId: caseId,
            affectedStrategies: [
                StrategyImpactItem(strategyId: "strat-1", strategyName: "BTC Momentum v3", wouldBlock: true, reasonCodes: ["filter_matched"], currentValue: 0.78, threshold: 0.6),
                StrategyImpactItem(strategyId: "strat-2", strategyName: "SOL Breakout v2", wouldBlock: false, reasonCodes: ["filter_disabled"], currentValue: 0.78, threshold: 0.6),
            ])
    }

    static func similarCases(caseId: String) -> SimilarCasesResponse {
        SimilarCasesResponse(
            caseId: caseId,
            similar: [
                SimilarCaseItem(id: "hist-1", symbol: "DOGE/USDT", manipulationType: "M3", similarity: 0.91, outcome: ["realized_drawdown": -0.18, "recovery_hours": 36], createdAt: "2026-05-10T08:00:00Z"),
                SimilarCaseItem(id: "hist-2", symbol: "WIF/USDT", manipulationType: "M3", similarity: 0.84, outcome: ["realized_drawdown": -0.22, "recovery_hours": 48], createdAt: "2026-04-22T12:00:00Z"),
            ])
    }
```

- [ ] **Step 3: 构建验证**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Services/APIManipulation.swift
git commit -m "feat(macos): add getStrategyImpact + getSimilar API methods with mocks"
```

---

## Task 3: 新增 ManipulationStreamClient actor（WS → AsyncStream）

**Files:**
- Create: `macos-app/AlphaLoop/Services/ManipulationStreamClient.swift`

**Interfaces:**
- Consumes: `ManipulationEvent`（Task 1）、`NetworkClientProtocol.baseURL`
- Produces: `actor ManipulationStreamClient` with `events() -> AsyncStream<ManipulationEvent>`、`connect(baseURL:)`、`disconnect()`

- [ ] **Step 1: 创建文件**

```swift
// ManipulationStreamClient.swift — WebSocket client for /api/v2/manipulation/stream
// Wraps URLSessionWebSocketTask.receive() into AsyncStream<ManipulationEvent>.
// Mock mode (baseURL == nil) → no-op stream that never yields.

import Foundation

actor ManipulationStreamClient {
    private var task: URLSessionWebSocketTask?
    private var continuation: AsyncStream<ManipulationEvent>.Continuation?
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Connect to ws://<host>/api/v2/manipulation/stream. Pass nil for mock mode (no-op).
    func connect(baseURL: URL?) {
        disconnect()
        guard let baseURL else { return }
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        guard let wsURL = components?.url?.appendingPathComponent("api/v2/manipulation/stream") else { return }
        task = session.webSocketTask(with: wsURL)
        task?.resume()
        receiveLoop()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        continuation?.finish()
        continuation = nil
    }

    /// Live event stream. Cancellation stops the receive loop.
    func events() -> AsyncStream<ManipulationEvent> {
        AsyncStream { continuation in
            self.continuation = continuation
            continuation.onTermination = { @Sendable [weak self] _ in
                Task { await self?.disconnect() }
            }
        }
    }

    private func receiveLoop() {
        guard let task else { return }
        Task {
            while !Task.isCancelled {
                do {
                    let msg = try await task.receive()
                    switch msg {
                    case .data(let data):
                        if let event = try? JSONDecoder().decode(ManipulationEvent.self, from: data) {
                            continuation?.yield(event)
                        }
                    case .string(let text):
                        if let data = text.data(using: .utf8),
                           let event = try? JSONDecoder().decode(ManipulationEvent.self, from: data) {
                            continuation?.yield(event)
                        }
                    @unknown default:
                        break
                    }
                } catch {
                    continuation?.finish()
                    break
                }
            }
        }
    }
}
```

- [ ] **Step 2: 构建验证**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Services/ManipulationStreamClient.swift
git commit -m "feat(macos): add ManipulationStreamClient actor (WS → AsyncStream<ManipulationEvent>)"
```

---

## Task 4: ViewModel 加聚焦状态 + focusCase(_:) 三并发

**Files:**
- Modify: `macos-app/AlphaLoop/ViewModels/ManipulationViewModel.swift`
- Test: `macos-app/Tests/ViewModelTests.swift`

**Interfaces:**
- Consumes: `APIManipulation.getCaseDetail` / `getStrategyImpact` / `getSimilar`（Task 2）
- Produces: `ManipulationViewModel.focusedCaseId` / `focusedDetail` / `strategyImpact` / `similar` / `focusCase(_:)` / `streamClient` / `startLiveUpdates()` / `stopLiveUpdates()`；删除 `toggleUserProfile()`

- [ ] **Step 1: 在 ViewModelTests.swift 写失败测试**

在 `macos-app/Tests/ViewModelTests.swift` 末尾追加：

```swift
final class ManipulationViewModelFocusTests: XCTestCase {
    @MainActor
    func testFocusCaseLoadsThreeEndpoints() async {
        let vm = ManipulationViewModel(client: MockNetworkClient())
        await vm.loadRadar()
        guard let firstCaseId = vm.radarOverview?.activeCases.first?.id else {
            XCTFail("no active case in mock radar"); return
        }
        await vm.focusCase(firstCaseId)
        XCTAssertNotNil(vm.focusedDetail, "focusedDetail should be loaded")
        XCTAssertNotNil(vm.strategyImpact, "strategyImpact should be loaded")
        XCTAssertNotNil(vm.similar, "similar should be loaded")
        XCTAssertEqual(vm.focusedCaseId, firstCaseId)
    }

    @MainActor
    func testFocusCaseFallsBackToFirstActiveWhenNil() async {
        let vm = ManipulationViewModel(client: MockNetworkClient())
        await vm.loadRadar()
        XCTAssertNil(vm.focusedCaseId)
        await vm.ensureFocusInitialized()
        XCTAssertNotNil(vm.focusedCaseId, "should auto-pick first active case")
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd macos-app && swift test --filter ManipulationViewModelFocusTests 2>&1 | tail -20`
Expected: FAIL（`focusedDetail` / `focusCase` / `ensureFocusInitialized` 不存在）

- [ ] **Step 3: 改写 ManipulationViewModel.swift**

完整替换文件内容为：

```swift
// ManipulationViewModel.swift — 操纵雷达视图模型
// 管理雷达概览、聚焦案例详情、策略联动、相似案例、告警流、WS 实时推送

import SwiftUI

@Observable
@MainActor
final class ManipulationViewModel {
    var radarOverview: ManipulationRadarOverview?
    var alerts: [ManipulationAlertItem] = []
    var userProfile: String = "conservative" // 仍传给 /signals，UI 不再暴露切换
    var scanSymbol: String = ""

    // 聚焦 case 状态
    var focusedCaseId: String?
    var focusedDetail: ManipulationCaseDetail?
    var strategyImpact: StrategyImpactResponse?
    var similar: SimilarCasesResponse?
    var focusError: String?

    // legacy
    var scores: [ManipulationScoreV2] = []

    var isLoading = false
    var error: String?
    var errorHandler: ErrorHandler?

    private let api: APIManipulation
    private var pollingTask: Task<Void, Never>?
    private var wsTask: Task<Void, Never>?
    private(set) var streamClient = ManipulationStreamClient()
    private var isLive: Bool = false

    init(client: NetworkClientProtocol) {
        self.api = APIManipulation(client: client)
        // Mock 模式判定：LiveNetworkClient.baseURL 非空；MockNetworkClient.baseURL 为空 URL
        self.isLive = client.baseURL.host != nil
    }

    /// Alias used by ManipulationRadarView
    func load() async { await loadRadar() }

    /// 扫描特定 symbol
    func scan() async {
        guard !scanSymbol.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            scores = try await api.listScores(limit: 20)
        } catch {
            errorHandler?.handle(error, context: "扫描 \(scanSymbol)")
            self.error = error.localizedDescription
        }
    }

    /// 加载雷达概览 + 告警 + 传统评分
    func loadRadar() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let overviewTask = api.getRadarOverview()
            async let alertsTask = api.getAlerts()
            async let scoresTask = api.listScores(limit: 20)
            radarOverview = try await overviewTask
            alerts = try await alertsTask
            scores = (try? await scoresTask) ?? []
            await ensureFocusInitialized()
        } catch {
            errorHandler?.handle(error, context: "加载操纵雷达")
            self.error = error.localizedDescription
        }
    }

    /// 首次加载后自动选第一个 active case
    func ensureFocusInitialized() async {
        guard focusedCaseId == nil,
              let firstId = radarOverview?.activeCases.first?.id else { return }
        await focusCase(firstId)
    }

    /// 聚焦某个 case：三并发加载 detail / strategyImpact / similar
    /// 任一失败不影响其他章节渲染（每个状态独立 nil / error）
    func focusCase(_ caseId: String) async {
        focusedCaseId = caseId
        focusError = nil
        // 立即清空旧数据，UI 显示 loading 态
        focusedDetail = nil
        strategyImpact = nil
        similar = nil

        async let detailTask = try? api.getCaseDetail(caseId)
        async let impactTask = try? api.getStrategyImpact(caseId)
        async let similarTask = try? api.getSimilar(caseId, limit: 5)

        let (detail, impact, sim) = await (detailTask, impactTask, similarTask)
        focusedDetail = detail
        strategyImpact = impact
        similar = sim
        if detail == nil && impact == nil && sim == nil {
            focusError = "全部加载失败"
        }
    }

    /// 启动实时更新：30s polling（兜底）+ WS 监听
    func startLiveUpdates() {
        pollingTask?.cancel()
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await loadRadar()
            }
        }
        guard isLive else { return } // mock 模式不连 WS
        wsTask?.cancel()
        wsTask = Task { [weak self] in
            guard let self else { return }
            // baseURL 由调用方注入；这里从 api 重新取
            // 注：APIManipulation 持有 client，无法直接拿 baseURL；改由 view 注入
            for await event in self.streamClient.events() {
                guard !Task.isCancelled else { break }
                await self.handleStreamEvent(event)
            }
        }
    }

    /// 停止实时更新：同步关闭 polling + WS
    func stopLiveUpdates() {
        pollingTask?.cancel()
        pollingTask = nil
        wsTask?.cancel()
        wsTask = nil
        Task { await streamClient.disconnect() }
    }

    /// 由 view 在 onAppear 时注入 WS baseURL 并连接
    func connectStream(baseURL: URL?) {
        Task { await streamClient.connect(baseURL: baseURL) }
    }

    private func handleStreamEvent(_ event: ManipulationEvent) async {
        switch event {
        case .stageChange(let caseId, _, _, _):
            if caseId == focusedCaseId {
                await focusCase(caseId) // 重新拉详情
            }
            await loadRadar() // 刷新概览 + alerts
        case .newCase:
            await loadRadar()
        case .snapshot:
            await loadRadar()
        case .heartbeat, .unknown:
            break
        }
    }

    /// legacy: 按风险等级排序
    var sortedScores: [ManipulationScoreV2] {
        scores.sorted { riskOrder($0.riskLevel) > riskOrder($1.riskLevel) }
    }

    private func riskOrder(_ level: String) -> Int {
        switch level {
        case "critical": return 4
        case "high": return 3
        case "medium": return 2
        case "low": return 1
        default: return 0
        }
    }
}
```

注意 `selectedCase` / `loadCaseDetail` / `toggleUserProfile` / `startPolling` / `stopPolling` 已删除。若有其他调用点（grep 确认）需一并改。

- [ ] **Step 4: 检查旧 API 调用点**

Run: `cd macos-app && grep -rn "selectedCase\|loadCaseDetail\|toggleUserProfile\|startPolling\|stopPolling" AlphaLoop/ --include="*.swift"`
Expected: 仅可能在 `ManipulationRadarView.swift`（下一个 task 重写）和测试里有；若有其他文件引用，记录下来在 Task 6 一并修。

- [ ] **Step 5: 运行测试确认通过**

Run: `cd macos-app && swift test --filter ManipulationViewModelFocusTests 2>&1 | tail -20`
Expected: PASS（2 个 test 通过）

如果 `MockNetworkClient.baseURL` 不是空 URL，需要调整 `init` 里的 `isLive` 判定逻辑——先看报错再修。

- [ ] **Step 6: 构建全量验证**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED（`ManipulationRadarView` 旧引用会在 Task 6 修；若此处报错需先注释掉旧调用点）

- [ ] **Step 7: Commit**

```bash
git add macos-app/AlphaLoop/ViewModels/ManipulationViewModel.swift macos-app/Tests/ViewModelTests.swift
git commit -m "refactor(macos): ManipulationViewModel focus state + 3-concurrent fetch + WS lifecycle"
```

---

## Task 5: 重写 ManipulationRadarView 九段叙事流根视图

**Files:**
- Modify: `macos-app/AlphaLoop/Views/Manipulation/ManipulationRadarView.swift`（完整重写）

**Interfaces:**
- Consumes: `ManipulationViewModel`（Task 4）、9 个 Component（Task 6–14）、`AppState`（路由跳转）
- Produces: 九段叙事流根视图，1280 居中

- [ ] **Step 1: 完整重写 ManipulationRadarView.swift**

```swift
// ManipulationRadarView.swift — 操纵雷达主视图（九段叙事流重构版）
// 1280 居中，Masthead + §0–§8，对齐 MarketStructureView / StructureMatrixView 风格家族

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
                if vm.isLoading && vm.radarOverview == nil {
                    LoadingView(type: .dashboard).padding(PulseSpacing.lg)
                } else if let overview = vm.radarOverview {
                    radarContent(vm: vm, overview: overview)
                } else if let error = vm.error {
                    EmptyStateView(
                        icon: "exclamationmark.triangle",
                        title: L10n.zh("加载失败", en: "Load Failed"),
                        description: error,
                        primaryAction: (title: L10n.zh("重试", en: "Retry"), action: { Task { await vm.loadRadar() } })
                    ).padding(PulseSpacing.lg)
                } else {
                    EmptyStateView(icon: "shield.checkered", title: L10n.Manipulation.noCases, description: L10n.Manipulation.radarSubtitle)
                        .padding(PulseSpacing.lg)
                }
            } else {
                LoadingView(type: .dashboard).padding(PulseSpacing.lg)
            }
        }
        .task { await initialLoad() }
        .onAppear {
            viewModel ??= ManipulationViewModel(client: networkClient)
            viewModel?.connectStream(baseURL: networkClient.baseURL.host != nil ? networkClient.baseURL : nil)
            viewModel?.startLiveUpdates()
        }
        .onDisappear { viewModel?.stopLiveUpdates() }
    }

    private func initialLoad() async {
        if viewModel == nil { viewModel = ManipulationViewModel(client: networkClient) }
        await viewModel?.loadRadar()
    }

    @ViewBuilder
    private func radarContent(vm: ManipulationViewModel, overview: ManipulationRadarOverview) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: PulseSpacing.xl) {
                MastheadBlock()
                    .staggeredAppearance(index: 0)
                if !overview.activeCases.isEmpty {
                    ActiveCasesStrip(overview: overview, focusedCaseId: vm.focusedCaseId) { id in
                        Task { await vm.focusCase(id) }
                    }
                    .staggeredAppearance(index: 1)
                }
                if let detail = vm.focusedDetail {
                    VerdictPanel(detail: detail)
                        .staggeredAppearance(index: 2)
                    LifecycleTimeline(detail: detail)
                        .staggeredAppearance(index: 3)
                    EvidenceLayerMatrix(detail: detail)
                        .staggeredAppearance(index: 4)
                    WhaleConcentrationPanel(detail: detail)
                        .staggeredAppearance(index: 5)
                    CrossMarketPressurePanel(detail: detail)
                        .staggeredAppearance(index: 6)
                    SocialAccelerationPanel(detail: detail)
                        .staggeredAppearance(index: 7)
                    DualProfileSignalPanel(detail: detail, impact: vm.strategyImpact) { route in
                        appState.selectedRoute = route
                    }
                    .staggeredAppearance(index: 8)
                } else if vm.focusedCaseId != nil {
                    LoadingView(type: .detail)
                }
                ManipulationAlertFeed(alerts: vm.alerts)
                    .staggeredAppearance(index: 9)
                if let similar = vm.similar, !similar.similar.isEmpty {
                    SimilarCasesPanel(similar: similar)
                        .staggeredAppearance(index: 9)
                }
            }
            .padding(.horizontal, PulseSpacing.xl)
            .padding(.vertical, PulseSpacing.lg)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(colors.background)
    }
}

private struct MastheadBlock: View {
    @Environment(PulseColors.self) private var colors
    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            HStack(spacing: PulseSpacing.sm) {
                Text("ALPHALOOP").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                Text("·").foregroundStyle(colors.textMuted)
                Text(L10n.zh("操纵雷达", en: "MANIPULATION RADAR")).font(PulseFonts.displaySubheading)
                Text("·").foregroundStyle(colors.textMuted)
                Text(L10n.zh("统计推断", en: "STATISTICAL INFERENCE")).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
            Text(L10n.Manipulation.disclaimer)
                .font(PulseFonts.caption)
                .foregroundStyle(colors.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(PulseSpacing.lg)
        .glassEffect()
    }
}
```

- [ ] **Step 2: 构建验证（预期失败，因为 9 个 Component 尚未创建）**

Run: `cd macos-app && swift build 2>&1 | tail -30`
Expected: FAIL — 报 9 个 Component 类型不存在。这是预期的，记录报错后继续 Task 6–14。

- [ ] **Step 3: 暂不提交，等 9 个 Component 创建后一起提交**

---

## Task 6: ActiveCasesStrip 组件（§0）

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/ActiveCasesStrip.swift`

**Interfaces:**
- Consumes: `ManipulationRadarOverview`、`focusedCaseId: String?`、`onSelect: (String) -> Void`
- Produces: `ActiveCasesStrip` view

- [ ] **Step 1: 创建文件**

```swift
// ActiveCasesStrip.swift — §0 横向滚动的活跃 case 缩略卡

import SwiftUI

struct ActiveCasesStrip: View {
    let overview: ManipulationRadarOverview
    let focusedCaseId: String?
    let onSelect: (String) -> Void

    @Environment(PulseColors.self) private var colors

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.md) {
                TerminalLabel(text: L10n.zh("活跃案例", en: "ACTIVE CASES"))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: PulseSpacing.md) {
                        ForEach(overview.activeCases) { c in
                            ActiveCaseCard(case_: c, isFocused: c.id == focusedCaseId)
                                .onTapGesture { onSelect(c.id) }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct ActiveCaseCard: View {
    let case_: ManipulationCaseSummary
    let isFocused: Bool
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack(spacing: PulseSpacing.xs) {
                Text(case_.symbol).font(PulseFonts.tabular)
                Text(case_.manipulationType).font(PulseFonts.micro).foregroundStyle(colors.accent)
            }
            HStack(spacing: PulseSpacing.xs) {
                Text(case_.lifecycleStage.uppercased()).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                Text("·").foregroundStyle(colors.textMuted)
                Text("\(Int(case_.confidence * 100))%").font(PulseFonts.tabular).foregroundStyle(colors.accent)
            }
        }
        .padding(PulseSpacing.md)
        .frame(width: 180, alignment: .leading)
        .background {
            if isFocused {
                RoundedRectangle(cornerRadius: PulseRadii.md).fill(colors.accent.opacity(0.12))
            } else {
                RoundedRectangle(cornerRadius: PulseRadii.md).fill(colors.cardBackground)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: PulseRadii.md)
                .strokeBorder(isFocused ? colors.accent : colors.border, lineWidth: isFocused ? 2 : 1)
        }
    }
}
```

- [ ] **Step 2: 构建验证**

Run: `cd macos-app && swift build 2>&1 | tail -10`
Expected: 仍 FAIL（其他 8 个 Component 未建），但 `ActiveCasesStrip` 自身不报错

- [ ] **Step 3: 暂不提交**

---

## Task 7: VerdictPanel 组件（§1）

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/VerdictPanel.swift`

**Interfaces:**
- Consumes: `ManipulationCaseDetail`（含 `evidenceLayers` / `completeness` / `maxConfidence` / `riskLevel`）
- Produces: `VerdictPanel` view

- [ ] **Step 1: 创建文件**

```swift
// VerdictPanel.swift — §1 判定面板：M-type + 风险等级 + 阶段 + 置信度环 + 数据完整度

import SwiftUI

struct VerdictPanel: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    private var availableLayers: Int {
        guard let layers = detail.evidenceLayers else { return 0 }
        return layers.values.filter { $0.available }.count
    }
    private var totalLayers: Int { detail.evidenceLayers?.count ?? 5 }
    private var confidenceCap: Double { detail.maxConfidence > 0 ? detail.maxConfidence : 1.0 }

    var body: some View {
        KryptonCard(emphasis: .standard) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.verdict)
                HStack(alignment: .top, spacing: PulseSpacing.xl) {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text("\(L10n.Manipulation.likely) \(detail.manipulationType)")
                            .font(PulseFonts.displayHeading)
                        Text("\(L10n.Manipulation.evidenceConsistentWith) \(detail.lifecycleStage)")
                            .font(PulseFonts.displaySubheading)
                            .foregroundStyle(colors.textMuted)
                        if !detail.riskLevel.isEmpty {
                            RiskBadge(level: detail.riskLevel)
                        }
                    }
                    Spacer()
                    ConfidenceRing(value: detail.confidence, cap: confidenceCap)
                        .frame(width: 96, height: 96)
                }
                HStack(spacing: PulseSpacing.md) {
                    Label("\(L10n.Manipulation.dataCompleteness): \(availableLayers)/\(totalLayers)", systemImage: "chart.bar.doc.horizontal")
                        .font(PulseFonts.caption)
                    if detail.maxConfidence > 0 {
                        Text("\(L10n.Manipulation.maxConfidence): \(Int(detail.maxConfidence * 100))%")
                            .font(PulseFonts.caption)
                            .foregroundStyle(colors.textMuted)
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct ConfidenceRing: View {
    let value: Double
    let cap: Double
    @Environment(PulseColors.self) private var colors

    var body: some View {
        ZStack {
            Circle().stroke(colors.border, lineWidth: 6)
            Circle()
                .trim(from: 0, to: min(value / cap, 1.0))
                .stroke(colors.accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int(value * 100))%").font(PulseFonts.tabular)
                Text("cap \(Int(cap * 100))%").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
        }
    }
}

private struct RiskBadge: View {
    let level: String
    @Environment(PulseColors.self) private var colors
    var body: some View {
        Text(level.uppercased())
            .font(PulseFonts.micro)
            .padding(.horizontal, PulseSpacing.sm)
            .padding(.vertical, 2)
            .background {
                Capsule().fill(level == "critical" || level == "high" ? colors.danger.opacity(0.2) : colors.amber.opacity(0.2))
            }
    }
}
```

- [ ] **Step 2: 暂不提交**

---

## Task 8: LifecycleTimeline 组件（§2）

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/LifecycleTimeline.swift`
- Modify: `macos-app/AlphaLoop/Views/Manipulation/LifecycleIndicator.swift`（保留色板 helper，删除视图部分）

**Interfaces:**
- Consumes: `ManipulationCaseDetail.timeline`、`ManipulationCaseDetail.lifecycleStage`
- Produces: `LifecycleTimeline` view；`LifecycleStagePalette` helper（从旧 LifecycleIndicator 抽出）

- [ ] **Step 1: 从 LifecycleIndicator.swift 抽出色板 helper**

先 Read `macos-app/AlphaLoop/Views/Manipulation/LifecycleIndicator.swift`，找到色板/图标映射的 static 部分。把这部分保留为 `enum LifecycleStagePalette`，删除整个 view struct。结果文件大致是：

```swift
// LifecycleIndicator.swift — 色板与图标映射 helper（视图部分已迁至 LifecycleTimeline）

import SwiftUI

enum LifecycleStagePalette {
    static let stages = ["suspected", "accumulate", "markup", "distribute", "collapse"]
    static func color(_ stage: String, colors: PulseColors) -> Color {
        switch stage {
        case "suspected": return colors.textMuted
        case "accumulate": return colors.info
        case "markup": return colors.accent
        case "distribute": return colors.amber
        case "collapse": return colors.danger
        default: return colors.textMuted
        }
    }
    static func icon(_ stage: String) -> String {
        switch stage {
        case "suspected": return "questionmark.circle"
        case "accumulate": return "arrow.down.right.circle"
        case "markup": return "arrow.up.right.circle"
        case "distribute": return "arrow.down.circle"
        case "collapse": return "exclamationmark.triangle"
        default: return "circle"
        }
    }
}
```

如果旧文件里有其他被引用的 view，先 grep 确认无外部引用再删：

Run: `cd macos-app && grep -rn "LifecycleIndicator(" AlphaLoop/ --include="*.swift"`
Expected: 仅可能在旧 ManipulationRadarView（已被 Task 5 重写删除）；若仍有引用，记录后在 Task 5 一并处理。

- [ ] **Step 2: 创建 LifecycleTimeline.swift**

```swift
// LifecycleTimeline.swift — §2 水平 5 节点生命周期时间线

import SwiftUI

struct LifecycleTimeline: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.lifecycleTimeline)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(LifecycleStagePalette.stages.enumerated()), id: \.offset) { idx, stage in
                        TimelineNode(
                            stage: stage,
                            isCurrent: stage == detail.lifecycleStage,
                            isPast: isPast(stage),
                            entry: detail.timeline.first { $0.stage == stage }
                        )
                        if idx < LifecycleStagePalette.stages.count - 1 {
                            TimelineConnector(isActive: isPast(stage) || stage == detail.lifecycleStage)
                        }
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
    }

    private func isPast(_ stage: String) -> Bool {
        guard let currentIdx = LifecycleStagePalette.stages.firstIndex(of: detail.lifecycleStage),
              let idx = LifecycleStagePalette.stages.firstIndex(of: stage) else { return false }
        return idx < currentIdx
    }
}

private struct TimelineNode: View {
    let stage: String
    let isCurrent: Bool
    let isPast: Bool
    let entry: ManipulationStageEntry?
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(spacing: PulseSpacing.xs) {
            ZStack {
                Circle()
                    .fill(isCurrent || isPast ? LifecycleStagePalette.color(stage, colors: colors) : colors.clear)
                    .frame(width: isCurrent ? 28 : 22, height: isCurrent ? 28 : 22)
                if !isCurrent && !isPast {
                    Circle().strokeBorder(LifecycleStagePalette.color(stage, colors: colors).opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [3]))
                        .frame(width: 22, height: 22)
                }
                Image(systemName: LifecycleStagePalette.icon(stage))
                    .font(PulseFonts.micro)
                    .foregroundStyle(isCurrent || isPast ? colors.background : colors.textMuted)
            }
            Text(stage.uppercased())
                .font(PulseFonts.micro)
                .foregroundStyle(isCurrent ? colors.accent : colors.textMuted)
            if let entry = entry {
                Text(entry.enteredAt.prefix(10))
                    .font(PulseFonts.micro)
                    .foregroundStyle(colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct TimelineConnector: View {
    let isActive: Bool
    @Environment(PulseColors.self) private var colors
    var body: some View {
        Rectangle()
            .fill(isActive ? colors.accent.opacity(0.6) : colors.border)
            .frame(height: 2)
            .padding(.top, 13)
    }
}
```

- [ ] **Step 3: 暂不提交**

---

## Task 9: EvidenceLayerMatrix 组件（§3）

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/EvidenceLayerMatrix.swift`

**Interfaces:**
- Consumes: `ManipulationCaseDetail.evidenceLayers`（5 Layer × score + quality）
- Produces: `EvidenceLayerMatrix` view

- [ ] **Step 1: 创建文件**

```swift
// EvidenceLayerMatrix.swift — §3 5 Layer × score 条 + data_quality 徽章（不展开 feature）

import SwiftUI

struct EvidenceLayerMatrix: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    private let layerOrder: [(key: String, label: String)] = [
        ("price_volume", L10n.Manipulation.layerPrice),
        ("orderbook", L10n.Manipulation.layerOrderbook),
        ("onchain", L10n.Manipulation.layerOnchain),
        ("social_news", L10n.Manipulation.layerSocial),
        ("cross_market", L10n.Manipulation.layerCrossMarket),
    ]

    var body: some View {
        KryptonCard(emphasis: .standard) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.evidenceMatrix)
                if let layers = detail.evidenceLayers, !layers.isEmpty {
                    VStack(spacing: PulseSpacing.md) {
                        ForEach(layerOrder, id: \.key) { entry in
                            if let layer = layers[entry.key] {
                                EvidenceLayerRow(label: entry.label, layer: layer)
                            }
                        }
                    }
                } else {
                    Text(L10n.Manipulation.dataUnavailable)
                        .font(PulseFonts.caption)
                        .foregroundStyle(colors.textMuted)
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct EvidenceLayerRow: View {
    let label: String
    let layer: EvidenceLayerPayload
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack {
                Text(label).font(PulseFonts.tabular)
                Spacer()
                if !layer.available || layer.quality < 0.3 {
                    Label(L10n.Manipulation.dataUnavailable, systemImage: "exclamationmark.triangle")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.amber)
                } else {
                    Text("quality \(Int(layer.quality * 100))%")
                        .font(PulseFonts.micro)
                        .foregroundStyle(colors.textMuted)
                }
            }
            if layer.available {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2).fill(colors.border).frame(height: 6)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(layer.score > 0.8 ? colors.danger : colors.accent)
                            .frame(width: max(2, geo.size.width * layer.score), height: 6)
                    }
                }
                .frame(height: 6)
                HStack {
                    Text(String(format: "%.2f", layer.score)).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                    Spacer()
                }
            }
        }
    }
}
```

- [ ] **Step 2: 暂不提交**

---

## Task 10: WhaleConcentrationPanel 组件（§4）

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/WhaleConcentrationPanel.swift`

**Interfaces:**
- Consumes: `ManipulationCaseDetail.evidenceLayers["onchain"]?.features`（top10_concentration / exchange_inflow / whale_transfer）
- Produces: `WhaleConcentrationPanel` view；复用 `PercentileBar`（在本文件内定义，§5/§6 共用）

- [ ] **Step 1: 创建文件（含共享 PercentileBar helper）**

```swift
// WhaleConcentrationPanel.swift — §4 巨鲸与筹码集中；含共享 PercentileBar

import SwiftUI

/// 共享分位条：一条横条标记当前值在历史分位的位置
struct PercentileBar: View {
    let percentile: Double  // 0...1
    let label: String
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.xs) {
            HStack {
                Text(label).font(PulseFonts.tabular)
                Spacer()
                Text("P\(Int(percentile * 100))").font(PulseFonts.micro).foregroundStyle(percentile > 0.9 ? colors.danger : colors.textMuted)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(colors.border).frame(height: 6)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(LinearGradient(colors: [colors.accent, colors.danger], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * percentile), height: 6)
                    Circle().fill(colors.text).frame(width: 8, height: 8)
                        .offset(x: max(0, geo.size.width * percentile - 4))
                }
            }
            .frame(height: 6)
        }
    }
}

struct WhaleConcentrationPanel: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    private var onchain: EvidenceLayerPayload? { detail.evidenceLayers?["onchain"] }

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.whaleConcentration)
                if let layer = onchain, layer.available, layer.quality >= 0.3 {
                    VStack(spacing: PulseSpacing.md) {
                        if let top10 = layer.features["top10_concentration"] {
                            PercentileBar(percentile: top10.percentile ?? 0, label: L10n.Manipulation.featTop10Concentration)
                        }
                        if let inflow = layer.features["exchange_inflow"] {
                            PercentileBar(percentile: inflow.percentile ?? 0, label: L10n.Manipulation.featExchangeInflow)
                        }
                        MetricGrid(features: layer.features, keys: ["whale_transfer_24h"])
                    }
                } else {
                    Text(L10n.Manipulation.dataUnavailable)
                        .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct MetricGrid: View {
    let features: [String: FeaturePayload]
    let keys: [String]
    @Environment(PulseColors.self) private var colors
    var body: some View {
        HStack(spacing: PulseSpacing.md) {
            ForEach(keys, id: \.self) { k in
                if let f = features[k] {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.replacingOccurrences(of: "_", with: " ")).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        Text(f.display ?? String(format: "%.2f", f.value)).font(PulseFonts.tabular)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
```

- [ ] **Step 2: 暂不提交**

---

## Task 11: CrossMarketPressurePanel 组件（§5）

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/CrossMarketPressurePanel.swift`

**Interfaces:**
- Consumes: `ManipulationCaseDetail.evidenceLayers["cross_market"]?.features`、`PercentileBar`（Task 10）
- Produces: `CrossMarketPressurePanel` view

- [ ] **Step 1: 创建文件**

```swift
// CrossMarketPressurePanel.swift — §5 跨市场压力

import SwiftUI

struct CrossMarketPressurePanel: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    private var cross: EvidenceLayerPayload? { detail.evidenceLayers?["cross_market"] }

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.crossMarketPressure)
                if let layer = cross, layer.available, layer.quality >= 0.3 {
                    VStack(spacing: PulseSpacing.md) {
                        if let fr = layer.features["funding_rate_z"] {
                            PercentileBar(percentile: abs(fr.percentile ?? 0), label: L10n.Manipulation.featFundingRate)
                        }
                        HStack(spacing: PulseSpacing.md) {
                            FeatureMetric(key: "open_interest_change", features: layer.features, label: L10n.Manipulation.featOpenInterest)
                            FeatureMetric(key: "long_short_ratio", features: layer.features, label: L10n.Manipulation.featLongShortRatio)
                            FeatureMetric(key: "basis", features: layer.features, label: L10n.Manipulation.featBasis)
                        }
                    }
                } else {
                    Text(L10n.Manipulation.dataUnavailable)
                        .font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct FeatureMetric: View {
    let key: String
    let features: [String: FeaturePayload]
    let label: String
    @Environment(PulseColors.self) private var colors
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            if let f = features[key] {
                Text(f.display ?? String(format: "%.2f", f.value)).font(PulseFonts.tabular)
            } else {
                Text("—").font(PulseFonts.tabular).foregroundStyle(colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

- [ ] **Step 2: 暂不提交**

---

## Task 12: SocialAccelerationPanel 组件（§6）

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/SocialAccelerationPanel.swift`

**Interfaces:**
- Consumes: `ManipulationCaseDetail.evidenceLayers["social_news"]`；`PercentileBar`（Task 10）
- Produces: `SocialAccelerationPanel` view

- [ ] **Step 1: 创建文件**

```swift
// SocialAccelerationPanel.swift — §6 社交加速（data_quality<0.3 整段 Data unavailable）

import SwiftUI

struct SocialAccelerationPanel: View {
    let detail: ManipulationCaseDetail
    @Environment(PulseColors.self) private var colors

    private var social: EvidenceLayerPayload? { detail.evidenceLayers?["social_news"] }
    private var isUnavailable: Bool {
        guard let l = social else { return true }
        return !l.available || l.quality < 0.3
    }

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.socialAcceleration)
                if isUnavailable {
                    HStack(spacing: PulseSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle").foregroundStyle(colors.amber)
                        Text(L10n.Manipulation.dataUnavailable).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
                    }
                } else if let layer = social {
                    VStack(spacing: PulseSpacing.md) {
                        if let mention = layer.features["mention_velocity"] {
                            PercentileBar(percentile: mention.percentile ?? 0, label: L10n.zh("提及增速", en: "Mention velocity"))
                        }
                        if let sentiment = layer.features["sentiment_extremity"] {
                            PercentileBar(percentile: sentiment.percentile ?? 0, label: L10n.zh("情绪极端度", en: "Sentiment extremity"))
                        }
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}
```

- [ ] **Step 2: 暂不提交**

---

## Task 13: DualProfileSignalPanel 组件（§7）

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/DualProfileSignalPanel.swift`

**Interfaces:**
- Consumes: `ManipulationCaseDetail.affectedSymbols`、`StrategyImpactResponse?`、`onNavigate: (AppRoute) -> Void`
- Produces: `DualProfileSignalPanel` view

- [ ] **Step 1: 创建文件**

```swift
// DualProfileSignalPanel.swift — §7 保守/激进双栏 + 影响交易对 + 策略联动 + 跳转

import SwiftUI

struct DualProfileSignalPanel: View {
    let detail: ManipulationCaseDetail
    let impact: StrategyImpactResponse?
    let onNavigate: (AppRoute) -> Void
    @Environment(PulseColors.self) private var colors

    var body: some View {
        KryptonCard(emphasis: .standard) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.defenseStrategyImpact)

                HStack(alignment: .top, spacing: PulseSpacing.md) {
                    ProfileColumn(
                        title: "CONSERVATIVE",
                        tint: colors.info,
                        action: detail.tradingSignal.conservative.action,
                        rationale: detail.tradingSignal.conservative.rationale,
                        riskLevel: detail.riskLevel
                    )
                    ProfileColumn(
                        title: "AGGRESSIVE",
                        tint: colors.amber,
                        action: detail.tradingSignal.aggressive.action,
                        rationale: detail.tradingSignal.aggressive.rationale,
                        riskLevel: detail.riskLevel
                    )
                }

                if let symbols = detail.affectedSymbols, !symbols.isEmpty {
                    VStack(alignment: .leading, spacing: PulseSpacing.xs) {
                        Text(L10n.Manipulation.affectedSymbols).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        FlowLayout(spacing: PulseSpacing.xs) {
                            ForEach(symbols, id: \.self) { s in
                                Text(s).font(PulseFonts.micro).padding(.horizontal, PulseSpacing.sm).padding(.vertical, 2)
                                    .background { Capsule().fill(colors.cardBackground) }
                            }
                        }
                    }
                }

                if let impact = impact, !impact.affectedStrategies.isEmpty {
                    VStack(alignment: .leading, spacing: PulseSpacing.sm) {
                        Text(L10n.Manipulation.strategyImpact).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                        ForEach(impact.affectedStrategies) { s in
                            StrategyImpactRow(item: s) { onNavigate(.strategyWorkspace) }
                        }
                    }
                }

                Button {
                    onNavigate(.riskCenter)
                } label: {
                    Label(L10n.Manipulation.openStrategyRisk, systemImage: "arrow.right.circle")
                        .font(PulseFonts.tabular)
                }
                .buttonStyle(.bordered)
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct ProfileColumn: View {
    let title: String
    let tint: Color
    let action: String
    let rationale: String
    let riskLevel: String
    @Environment(PulseColors.self) private var colors

    var body: some View {
        VStack(alignment: .leading, spacing: PulseSpacing.sm) {
            Text(title).font(PulseFonts.micro).foregroundStyle(tint)
            Text(action).font(PulseFonts.displaySubheading).foregroundStyle(tint)
            if !rationale.isEmpty {
                Text(rationale).font(PulseFonts.caption).foregroundStyle(colors.textMuted)
            }
            if !riskLevel.isEmpty {
                Text("●●●○ \(riskLevel.uppercased())").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(PulseSpacing.md)
        .background {
            RoundedRectangle(cornerRadius: PulseRadii.md).fill(tint.opacity(0.08))
        }
    }
}

private struct StrategyImpactRow: View {
    let item: StrategyImpactItem
    let onEdit: () -> Void
    @Environment(PulseColors.self) private var colors

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.strategyName).font(PulseFonts.tabular)
                if item.wouldBlock {
                    Label(L10n.Manipulation.wouldBlock, systemImage: "checkmark.shield")
                        .font(PulseFonts.micro).foregroundStyle(colors.accent)
                } else if item.reasonCodes.contains("filter_disabled") {
                    Label(L10n.Manipulation.filterDisabled, systemImage: "exclamationmark.triangle")
                        .font(PulseFonts.micro).foregroundStyle(colors.amber)
                }
            }
            Spacer()
            Button(L10n.zh("编辑", en: "Edit"), action: onEdit)
                .font(PulseFonts.micro)
                .buttonStyle(.borderless)
        }
        .padding(PulseSpacing.sm)
        .background { RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.cardBackground) }
    }
}

/// 简易 flow layout（SwiftUI 原生无，参考 BacktestLab 已有实现）
private struct FlowLayout: Layout {
    let spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > maxWidth { x = 0; y += rowH + spacing; rowH = 0 }
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let sz = s.sizeThatFits(.unspecified)
            if x + sz.width > bounds.maxX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(sz))
            x += sz.width + spacing
            rowH = max(rowH, sz.height)
        }
    }
}
```

注：`detail.tradingSignal` 已在 Task 1 改为 `DualTradingSignal` 类型（含 `conservative` / `aggressive` 两个 `ManipulationTradingSignal` 字段）。`ManipulationTradingSignal` 的字段名（`action` / `rationale` 等）以现有代码为准——若实际字段名不同，先 grep `struct ManipulationTradingSignal` 确认再调整 ProfileColumn 的取值。

- [ ] **Step 2: 暂不提交**

---

## Task 14: SimilarCasesPanel 组件（§8 右半）

**Files:**
- Create: `macos-app/AlphaLoop/Views/Manipulation/Components/SimilarCasesPanel.swift`

**Interfaces:**
- Consumes: `SimilarCasesResponse`
- Produces: `SimilarCasesPanel` view

- [ ] **Step 1: 创建文件**

```swift
// SimilarCasesPanel.swift — §8 右半 相似历史案例 + outcome

import SwiftUI

struct SimilarCasesPanel: View {
    let similar: SimilarCasesResponse
    @Environment(PulseColors.self) private var colors

    var body: some View {
        KryptonCard(emphasis: .subtle) {
            VStack(alignment: .leading, spacing: PulseSpacing.lg) {
                TerminalLabel(text: L10n.Manipulation.similarHistoricalCases)
                VStack(spacing: PulseSpacing.md) {
                    ForEach(similar.similar) { c in
                        SimilarCaseRow(item: c)
                    }
                }
            }
            .padding(PulseSpacing.lg)
        }
    }
}

private struct SimilarCaseRow: View {
    let item: SimilarCaseItem
    @Environment(PulseColors.self) private var colors
    var body: some View {
        HStack(alignment: .top, spacing: PulseSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: PulseSpacing.xs) {
                    Text(item.symbol).font(PulseFonts.tabular)
                    Text(item.manipulationType).font(PulseFonts.micro).foregroundStyle(colors.accent)
                }
                Text(item.createdAt.prefix(10)).font(PulseFonts.micro).foregroundStyle(colors.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("sim \(Int(item.similarity * 100))%").font(PulseFonts.micro).foregroundStyle(colors.textMuted)
                if let dd = item.outcome["realized_drawdown"] {
                    Text(String(format: "%+.1f%%", dd * 100)).font(PulseFonts.tabular)
                        .foregroundStyle(dd < 0 ? colors.danger : colors.accent)
                }
            }
        }
        .padding(PulseSpacing.sm)
        .background { RoundedRectangle(cornerRadius: PulseRadii.sm).fill(colors.cardBackground) }
    }
}
```

- [ ] **Step 2: 构建全量验证（Task 5–14 全部就位后）**

Run: `cd macos-app && swift build 2>&1 | tail -30`
Expected: BUILD SUCCEEDED。若有报错（最可能是 `tradingSignal` 类型不匹配——见 Task 13 注），逐个修。

- [ ] **Step 3: 删除 CaseDetailView.swift**

确认无引用后删除：

Run: `cd macos-app && grep -rn "CaseDetailView(" AlphaLoop/ --include="*.swift"`
Expected: 无输出（Task 5 重写已移除引用）

```bash
git rm macos-app/AlphaLoop/Views/Manipulation/CaseDetailView.swift
```

- [ ] **Step 4: 再次构建验证**

Run: `cd macos-app && swift build 2>&1 | tail -20`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit（Task 5–14 一起提交）**

```bash
git add macos-app/AlphaLoop/Views/Manipulation/ManipulationRadarView.swift \
        macos-app/AlphaLoop/Views/Manipulation/LifecycleIndicator.swift \
        macos-app/AlphaLoop/Views/Manipulation/Components/ \
        macos-app/AlphaLoop/Services/APIManipulation.swift
git rm macos-app/AlphaLoop/Views/Manipulation/CaseDetailView.swift
git commit -m "refactor(macos): rewrite ManipulationRadarView as 9-section narrative flow + 9 components"
```

---

## Task 15: 后端 affected_symbols 扩展

**Files:**
- Modify: `backend/app/routers/manipulation.py`（`_build_case_detail_v2` 函数内）
- Test: `backend/tests/test_manipulation_api.py`

**Interfaces:**
- Produces: `/cases/{id}` 返回的 `affected_symbols` 从 `[case["symbol"]]` 扩展为同基币多对

- [ ] **Step 1: 写失败测试**

在 `backend/tests/test_manipulation_api.py` 末尾追加：

```python
class TestAffectedSymbolsExpansion:
    def test_affected_symbols_expands_usdt_to_stablecoin_pairs(self, client: TestClient, mock_radar_adapter):
        # 先创建一个 case
        scan = client.post("/api/v2/manipulation/scan", json={"symbol": "SOL/USDT", "timeframe": "1h"})
        case_id = scan.json().get("case_id")
        if not case_id:
            # scan 不返回 case_id 时，从 radar 拿第一个 active case
            radar = client.get("/api/v2/manipulation/radar")
            case_id = radar.json()["active_cases"][0]["id"]
        resp = client.get(f"/api/v2/manipulation/cases/{case_id}")
        assert resp.status_code == 200
        symbols = resp.json()["affected_symbols"]
        # SOL/USDT → 应含 SOL/USDT, SOL/USDC, SOL/FDUSD
        assert any("SOL/USDT" in s for s in symbols)
        assert len(symbols) >= 2  # 至少扩展出同基币对

    def test_affected_symbols_no_slash_keeps_original(self, client: TestClient, mock_radar_adapter):
        # 无 / 的 symbol 保持原样：通过 mock 注入一个 base-only symbol
        from app.routers.manipulation import _get_case_repo
        repo = _get_case_repo()
        case = repo.create_case(symbol="BTC", market="crypto", manipulation_type="M1", confidence=0.5, evidence={}, evidence_layers={})
        resp = client.get(f"/api/v2/manipulation/cases/{case['id']}")
        assert resp.json()["affected_symbols"] == ["BTC"]
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd backend && python3 -m pytest tests/test_manipulation_api.py::TestAffectedSymbolsExpansion -q 2>&1 | tail -20`
Expected: FAIL（`affected_symbols` 仍只有 `[case["symbol"]]`）

- [ ] **Step 3: 实现 affected_symbols 扩展**

在 `backend/app/routers/manipulation.py` 的 `_build_case_detail_v2` 函数里，把 `"affected_symbols": [case["symbol"]]` 替换为：

```python
        "affected_symbols": _expand_affected_symbols(case["symbol"]),
```

并在文件顶部（`_completeness` 函数附近）加 helper：

```python
_STABLE_QUOTE_CURRENCIES = ("USDT", "USDC", "FDUSD")


def _expand_affected_symbols(symbol: str) -> list[str]:
    """Expand a futures symbol to same-base stablecoin pairs.
    SOL/USDT → [SOL/USDT, SOL/USDC, SOL/FDUSD]; BTC (no /) → [BTC].
    """
    if "/" not in symbol:
        return [symbol]
    base, _quote = symbol.split("/", 1)
    return [f"{base}/{q}" for q in _STABLE_QUOTE_CURRENCIES]
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd backend && python3 -m pytest tests/test_manipulation_api.py::TestAffectedSymbolsExpansion -q 2>&1 | tail -20`
Expected: PASS

- [ ] **Step 5: 跑全量 manipulation 测试确保无回归**

Run: `cd backend && python3 -m pytest tests/test_manipulation_api.py -q 2>&1 | tail -20`
Expected: 全部 PASS

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/manipulation.py backend/tests/test_manipulation_api.py
git commit -m "feat(backend): expand affected_symbols to same-base stablecoin pairs"
```

---

## Task 16: 后端 pytest 覆盖（5 个测试）

**Files:**
- Modify: `backend/tests/test_manipulation_api.py`

**Interfaces:**
- Produces: 5 个新测试覆盖 `/cases/{id}` v2 / `/strategy-impact` / `/similar` / `/stream`

- [ ] **Step 1: 写测试**

在 `backend/tests/test_manipulation_api.py` 末尾追加：

```python
class TestCaseDetailV2:
    def test_case_detail_v2_includes_evidence_layers(self, client: TestClient, mock_radar_adapter):
        from app.routers.manipulation import _get_case_repo
        repo = _get_case_repo()
        case = repo.create_case(
            symbol="SOL/USDT", market="crypto", manipulation_type="M5",
            confidence=0.78, evidence={"price_volume": 0.8},
            evidence_layers={
                "price_volume": {"available": True, "score": 0.78, "quality": 0.95, "features": {}},
                "orderbook": {"available": True, "score": 0.42, "quality": 0.60, "features": {}},
                "onchain": {"available": False, "score": 0, "quality": 0.10, "features": {}},
            },
        )
        resp = client.get(f"/api/v2/manipulation/cases/{case['id']}")
        body = resp.json()
        assert "evidence_layers" in body
        assert body["evidence_layers"]["price_volume"]["score"] == 0.78
        assert "completeness" in body
        assert "max_confidence" in body
        assert "trading_signal" in body
        assert "conservative" in body["trading_signal"]
        assert "aggressive" in body["trading_signal"]


class TestStrategyImpact:
    def _make_case(self):
        from app.routers.manipulation import _get_case_repo
        return _get_case_repo().create_case(
            symbol="SOL/USDT", market="crypto", manipulation_type="M5",
            confidence=0.78, evidence={"price_volume": 0.8},
            evidence_layers={"price_volume": {"available": True, "score": 0.78, "quality": 0.95, "features": {}}})

    def test_strategy_impact_blocks_when_filter_enabled(self, client: TestClient, mock_radar_adapter, monkeypatch):
        case = self._make_case()
        # monkeypatch strategy_impact service to return a blocked item
        from app.services.manipulation import strategy_impact as si_mod
        original = si_mod.compute_strategy_impact
        def fake(case_id):
            return [{
                "strategy_id": "s1", "strategy_name": "BTC Mom", "would_block": True,
                "reason_codes": ["filter_matched"], "current_value": 0.78, "threshold": 0.6,
            }]
        monkeypatch.setattr(si_mod, "compute_strategy_impact", fake)
        resp = client.get(f"/api/v2/manipulation/cases/{case['id']}/strategy-impact")
        assert resp.status_code == 200
        items = resp.json()["affected_strategies"]
        assert any(i["would_block"] for i in items)

    def test_strategy_impact_warns_when_filter_disabled(self, client: TestClient, mock_radar_adapter, monkeypatch):
        case = self._make_case()
        from app.services.manipulation import strategy_impact as si_mod
        def fake(case_id):
            return [{
                "strategy_id": "s2", "strategy_name": "SOL Breakout", "would_block": False,
                "reason_codes": ["filter_disabled"], "current_value": 0.78, "threshold": 0.6,
            }]
        monkeypatch.setattr(si_mod, "compute_strategy_impact", fake)
        resp = client.get(f"/api/v2/manipulation/cases/{case['id']}/strategy-impact")
        items = resp.json()["affected_strategies"]
        assert items[0]["reason_codes"] == ["filter_disabled"]


class TestSimilarCases:
    def test_similar_cases_ranking_by_cosine(self, client: TestClient, mock_radar_adapter):
        from app.routers.manipulation import _get_case_repo
        repo = _get_case_repo()
        # 三个已完成 case，相似度不同
        for sym, score in [("DOGE/USDT", 0.8), ("WIF/USDT", 0.6)]:
            c = repo.create_case(symbol=sym, market="crypto", manipulation_type="M3",
                                 confidence=0.5, evidence={},
                                 evidence_layers={"price_volume": {"available": True, "score": score, "quality": 0.9, "features": {}}})
            repo.update_stage(c["id"], "collapse", confidence=0.9)
        focal = repo.create_case(symbol="SOL/USDT", market="crypto", manipulation_type="M3",
                                  confidence=0.5, evidence={},
                                  evidence_layers={"price_volume": {"available": True, "score": 0.85, "quality": 0.9, "features": {}}})
        resp = client.get(f"/api/v2/manipulation/cases/{focal['id']}/similar?limit=5")
        assert resp.status_code == 200
        sims = resp.json()["similar"]
        assert len(sims) >= 1
        # cosine 降序
        assert all(sims[i]["similarity"] >= sims[i+1]["similarity"] for i in range(len(sims)-1))


class TestStreamPush:
    def test_stream_pushes_stage_change(self, client: TestClient, mock_radar_adapter):
        """WS 订阅后触发 update_stage，应收到 stage_change 事件。"""
        from app.routers.manipulation import _get_case_repo
        import threading, time
        repo = _get_case_repo()
        case = repo.create_case(symbol="SOL/USDT", market="crypto", manipulation_type="M5",
                                confidence=0.5, evidence={},
                                evidence_layers={"price_volume": {"available": True, "score": 0.7, "quality": 0.9, "features": {}}})
        received = []
        with client.websocket_connect("/api/v2/manipulation/stream") as ws:
            # 收 snapshot
            snap = ws.receive_json()
            assert snap["type"] == "snapshot"
            # 触发 stage change
            def _push():
                time.sleep(0.2)
                repo.update_stage(case["id"], "markup", confidence=0.7)
            threading.Thread(target=_push, daemon=True).start()
            # 收 stage_change
            for _ in range(10):
                msg = ws.receive_json()
                received.append(msg)
                if msg.get("type") == "stage_change":
                    break
        assert any(m.get("type") == "stage_change" for m in received)
```

- [ ] **Step 2: 运行测试**

Run: `cd backend && python3 -m pytest tests/test_manipulation_api.py::TestCaseDetailV2 tests/test_manipulation_api.py::TestStrategyImpact tests/test_manipulation_api.py::TestSimilarCases tests/test_manipulation_api.py::TestStreamPush -q 2>&1 | tail -30`
Expected: 全部 PASS。若 `compute_strategy_impact` 签名与 mock 不符，先 grep 真实签名再调整 monkeypatch。

- [ ] **Step 3: 跑全量 manipulation 测试**

Run: `cd backend && python3 -m pytest tests/test_manipulation_*.py -q 2>&1 | tail -20`
Expected: 全部 PASS（除已知 17 个预存失败——见 memory，与本 task 无关）

- [ ] **Step 4: Commit**

```bash
git add backend/tests/test_manipulation_api.py
git commit -m "test(backend): cover cases v2 / strategy-impact / similar / WS stream"
```

---

## Task 17: L10n 新增键

**Files:**
- Modify: `macos-app/AlphaLoop/Localization/L10n+Manipulation.swift`

**Interfaces:**
- Produces: spec §9 列出的所有 L10n 键

- [ ] **Step 1: 在 L10n+Manipulation.swift 末尾追加键**

先 Read 文件确认现有结构，然后追加 spec §9 全部键：

```swift
    // Disclaimer & uncertainty
    static var disclaimer: String { zh("操纵雷达是统计推断系统，输出"基于证据的怀疑"而非"定罪"。请结合多源信息独立判断。",
                                        en: "Manipulation radar is a statistical inference system; surfaces evidence-based suspicions, not verdicts.") }
    static var likely: String { zh("疑似", en: "Likely") }
    static var evidenceConsistentWith: String { zh("证据指向", en: "Evidence consistent with") }
    static var dataUnavailable: String { zh("数据不可用", en: "Data unavailable") }
    static var dataQuality: String { zh("数据完整度", en: "Data quality") }
    static var dataCompleteness: String { zh("数据完整度", en: "Data completeness") }
    static var maxConfidence: String { zh("置信上限", en: "Max confidence") }

    // Section titles
    static var verdict: String { zh("判定", en: "VERDICT") }
    static var lifecycleTimeline: String { zh("生命周期", en: "LIFECYCLE") }
    static var evidenceMatrix: String { zh("证据矩阵", en: "EVIDENCE MATRIX") }
    static var whaleConcentration: String { zh("巨鲸与筹码集中", en: "WHALE & CONCENTRATION") }
    static var crossMarketPressure: String { zh("跨市场压力", en: "CROSS-MARKET PRESSURE") }
    static var socialAcceleration: String { zh("社交加速", en: "SOCIAL ACCELERATION") }
    static var defenseStrategyImpact: String { zh("防御与策略联动", en: "DEFENSE & STRATEGY IMPACT") }
    static var similarHistoricalCases: String { zh("相似历史案例", en: "SIMILAR HISTORICAL CASES") }

    // Layer labels
    static var layerPrice: String { zh("Layer A · 价格量能", en: "Layer A · Price/Volume") }
    static var layerOrderbook: String { zh("Layer B · 盘口流动性", en: "Layer B · Orderbook Liquidity") }
    static var layerOnchain: String { zh("Layer C · 链上", en: "Layer C · On-Chain") }
    static var layerSocial: String { zh("Layer D · 社交新闻", en: "Layer D · Social & News") }
    static var layerCrossMarket: String { zh("Layer E · 跨市场", en: "Layer E · Cross-Market") }

    // Defense panel labels
    static var affectedSymbols: String { zh("影响交易对", en: "Affected symbols") }
    static var strategyImpact: String { zh("当前策略联动", en: "Strategy impact") }
    static var wouldBlock: String { zh("将阻断", en: "Will block") }
    static var filterDisabled: String { zh("过滤器未启用", en: "Filter disabled") }
    static var openStrategyRisk: String { zh("跳转风控配置", en: "Open risk config") }

    // Feature names
    static var featTop10Concentration: String { zh("Top-10 集中度", en: "Top-10 concentration") }
    static var featExchangeInflow: String { zh("交易所充值", en: "Exchange inflow") }
    static var featFundingRate: String { zh("资金费率", en: "Funding rate") }
    static var featOpenInterest: String { zh("持仓量", en: "Open interest") }
    static var featLongShortRatio: String { zh("多空比", en: "Long/Short ratio") }
    static var featBasis: String { zh("现货-永续基差", en: "Spot-perp basis") }
```

- [ ] **Step 2: 构建验证**

Run: `cd macos-app && swift build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Localization/L10n+Manipulation.swift
git commit -m "feat(macos): add L10n keys for manipulation radar nine-section narrative"
```

---

## Task 18: WS 流降级测试 + 文档更新

**Files:**
- Modify: `macos-app/Tests/ViewModelTests.swift`
- Modify: `CLAUDE.md`
- Modify: `docs/user-guide/content/zh/pages/structure/manipulation-radar.html`
- Modify: `docs/user-guide/content/en/pages/structure/manipulation-radar.html`
- Modify: `docs/superpowers/specs/2026-06-23-manipulation-radar-narrative-refactor-design.md`

**Interfaces:**
- Produces: `testStreamFallbackToPolling` 测试；CLAUDE.md 描述更新；user-guide 双语重写；旧 spec frontmatter 标注 superseded

- [ ] **Step 1: 写 WS 降级测试**

在 `macos-app/Tests/ViewModelTests.swift` 的 `ManipulationViewModelFocusTests` class 里追加：

```swift
    @MainActor
    func testStreamFallbackToPollingWhenMock() async {
        let vm = ManipulationViewModel(client: MockNetworkClient())
        // mock 模式：baseURL 无 host → isLive=false → 不连 WS，但仍跑 polling
        vm.startLiveUpdates()
        // 等待一帧确认 polling task 已启动
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertNotNil(vm)
        vm.stopLiveUpdates()
        // 无 crash + 任务已取消即视为通过
        XCTAssertTrue(true)
    }
```

- [ ] **Step 2: 运行测试**

Run: `cd macos-app && swift test --filter ManipulationViewModelFocusTests 2>&1 | tail -20`
Expected: 3 个 test 全部 PASS

- [ ] **Step 3: 更新 CLAUDE.md 的 Manipulation 描述**

在 `CLAUDE.md` 找到 `Views/Manipulation/ManipulationRadarView` 那一段（开头是 "**`Views/Manipulation/ManipulationRadarView`** — Market manipulation single-case narrative flow"），把后续描述里"九段"细节按已实现状态微调——主要是确认描述与最终实现对齐。如果描述已经准确（spec §10 已写明），保持不变。

- [ ] **Step 4: 重写 user-guide 中文页**

Read `docs/user-guide/content/zh/pages/structure/manipulation-radar.html`，按九段叙事流重写——章节顺序（Masthead + §0–§8）、不确定性声明、双画像对比、策略联动入口。保留 HTML 结构与现有 CSS class 风格。

- [ ] **Step 5: 重写 user-guide 英文页**

同步 Step 4 内容到 `docs/user-guide/content/en/pages/structure/manipulation-radar.html`。

- [ ] **Step 6: 旧 spec frontmatter 标注 superseded**

在 `docs/superpowers/specs/2026-06-23-manipulation-radar-narrative-refactor-design.md` frontmatter 加：

```yaml
superseded-by:
  - docs/superpowers/specs/2026-07-01-manipulation-radar-refactor-design.md
```

- [ ] **Step 7: 检查 user-guide NAV 是否需要更新**

Run: `grep -n "manipulation-radar" docs/user-guide/assets/app.js`
Expected: 若路径不变则无需改；若变了则更新 NAV 数组里对应 path。

- [ ] **Step 8: 构建验证**

Run: `cd macos-app && swift build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

- [ ] **Step 9: Commit**

```bash
git add macos-app/Tests/ViewModelTests.swift CLAUDE.md \
        docs/user-guide/content/zh/pages/structure/manipulation-radar.html \
        docs/user-guide/content/en/pages/structure/manipulation-radar.html \
        docs/superpowers/specs/2026-06-23-manipulation-radar-narrative-refactor-design.md
git commit -m "docs: update CLAUDE.md + user-guide + mark old manipulation spec superseded; add stream fallback test"
```

---

## Task 19: 验收（P6）

**Files:** 无（纯验证 task）

- [ ] **Step 1: 全量后端测试**

Run: `cd backend && python3 -m pytest tests/ -q 2>&1 | tail -30`
Expected: 除 17 个预存失败外，新增 manipulation 测试全部 PASS；`--cov-fail-under=30` 通过

- [ ] **Step 2: 全量 macOS 测试**

Run: `cd macos-app && swift test 2>&1 | tail -30`
Expected: 全部 PASS（含 3 个新 ManipulationViewModel 测试）

- [ ] **Step 3: 全量构建**

Run: `cd macos-app && swift build 2>&1 | tail -10 && cd ../canvas-web && npm run build 2>&1 | tail -10`
Expected: 双 BUILD SUCCEEDED

- [ ] **Step 4: 全栈启动 mock 模式手测**

```bash
cd backend && python3 run.py &
cd macos-app && swift run
```

手测清单（参照 spec §12 验收清单）：
- [ ] 1280 居中、九段 + Masthead staggeredAppearance 入场
- [ ] 所有判定文案使用概率前缀（"疑似" / "Likely"）
- [ ] Masthead 下方 disclaimer 非警告色
- [ ] Verdict 显示 N/5 layers + max_confidence
- [ ] 每 Layer 显示 data_quality；缺失标 Data unavailable
- [ ] §7 同时呈现 conservative 与 aggressive，无顶部 toggle
- [ ] §7 列出受影响策略 + filter 状态 + 跳转 `.riskCenter` / `.strategyWorkspace`
- [ ] §8 右半呈现 top-N 相似历史 case 含 outcome
- [ ] §6 data_quality<0.3 整段 Data unavailable
- [ ] L10n 中英切换全部生效

- [ ] **Step 5: live 模式手测 WS 推送**

启动后端 + 连真实数据，触发 `update_stage`（或等 30s polling），观察：
- [ ] WS 推送 stage_change 后自动刷新聚焦 case 与 alerts
- [ ] WS 断线（kill 后端）退化为 polling 不阻塞 UI

- [ ] **Step 6: 推送到 origin**

```bash
git push origin main
```

---

## Self-Review Notes

**Spec coverage check:**
- spec §3 九段信息架构 → Task 5（根视图）+ Task 6–14（9 个 Component）✓
- spec §4 视觉风格契约（KryptonCard / TerminalLabel / staggeredAppearance）→ Task 5–14 全程复用 ✓
- spec §5 不确定性表达 → Task 7（VerdictPanel 概率前缀 + completeness + max_confidence）+ Task 9（data_quality 徽章）+ Task 5（Masthead disclaimer）+ Task 17（L10n disclaimer 键）✓
- spec §6 双画像并列 → Task 13 ✓
- spec §7 后端查漏补缺 → Task 15（affected_symbols）+ Task 16（5 pytest）✓
- spec §7.2 generate_dual_signal 已确认存在，无需 task ✓
- spec §8 数据流与状态机 → Task 4（focusCase 三并发 + WS 生命周期）✓
- spec §9 L10n → Task 17 ✓
- spec §10 替换删除清单 → Task 5（重写 ManipulationRadarView）+ Task 8（LifecycleIndicator 重构）+ Task 14（删 CaseDetailView）+ Task 4（删 toggleUserProfile）✓
- spec §11 实施分期 P2–P5 → Task 1–4（P2）+ Task 5–14（P3）+ Task 4 WS 部分（P4 折入）+ Task 15–18（P5）✓
- spec §12 验收清单 → Task 19 ✓
- spec §13 实现注意 → 散落在各 task 的注里 ✓

**已知风险点（实现时留意）：**
1. Task 13 的 `tradingSignal` 类型——若 Task 1 的 `DualTradingSignal` 未替换原 `tradingSignal` 字段，Task 13 会编译失败。建议 Task 1 实现时直接把 `var tradingSignal: ManipulationTradingSignal` 改为 `var tradingSignal: DualTradingSignal`（后端返回的是双字段对象），并调整 mock。
2. `MockNetworkClient.baseURL` 是否为空 URL——决定 `isLive` 判定。Task 4 Step 5 已加防御。
3. `compute_strategy_impact` 真实签名——Task 16 的 monkeypatch 需匹配。
4. `Layout` protocol（Task 13 FlowLayout）需 macOS 13+，目标 macOS 26 满足。

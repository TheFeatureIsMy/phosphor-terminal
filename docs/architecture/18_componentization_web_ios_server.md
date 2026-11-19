# 18. 组件化与结构分析（Web + iOS + Server）

> 日期：2026-11-15 · 状态：Proposed
> 适用范围：`backend/`、`web/`、`macos-app/`（作为 iOS 复用来源）、`canvas-web/`（待归档）
> 关联：[Web/iOS 优先架构](../superpowers/specs/2026-11-15-web-ios-first-architecture-design.md)

## 1. 现状盘点

| 模块 | 规模 | 结构 | 主要问题 |
|---|---:|---|---|
| backend | 45k 行 / 54 router / 95 service | routers → services → domain/models | router 内含 ORM 与聚合逻辑；两个 overview aggregator；风控词表三套；超大 service |
| web | 16k 行 / 96 ts(x) | pages + components + lib + canvas | 无 feature 边界；类型手写；画布与 `canvas-web` 分叉；无测试 |
| macos-app | 45k 行 / 272 swift | Views / ViewModels / Services / Models / DesignSystem / L10n | 单 executable target，无法直接给 iOS 复用；AppKit 耦合 |
| canvas-web | 2.7k 行 | 独立 Vite app | 只为 macOS WebView 服务；与 web 画布重复 |

结论：**后端是"分层但未分域"，Web 是"按页面堆"，iOS 复用被 target 结构挡住**。组件化不是重写，而是先把边界切出来。

## 2. 目标结构

### 2.1 Backend：按限界上下文分包

```text
app/
├── api/                 # 仅 HTTP：路由、鉴权依赖、序列化
│   ├── deps.py
│   └── v1/ v2/ ...
├── domain/              # 纯类型：DSL、订单、风控、命令、租户
├── contracts/           # Pydantic 请求/响应 + 导出的 OpenAPI
├── services/
│   ├── trading/         # 策略、回测、dry-run、live_small
│   ├── execution/       # command bus、ledger、reconcile、materializer
│   ├── risk/            # pre-trade、runtime firewall、circuit breaker
│   ├── marketdata/      # OHLCV、ticker、structure
│   ├── research/        # AI research、factor、manipulation
│   ├── providers/       # 八类适配器（已有）
│   └── platform/        # auth、tenant、settings、audit
├── workers/             # 命令处理器（只依赖 services/domain）
└── infra/               # db、redis、crypto、logging、http clients
```

依赖方向（只允许向下）：

```text
api → services → domain
api → contracts
workers → services → domain
infra ← services（通过 Protocol 注入）
```

禁止：

- `api/` 直接 `select()` / `db.query()`（现状 214 处，逐步清零）；
- `domain/` import `services/` 或 `infra/`；
- 跨域直接 import 对方内部模块（走 `services/<domain>/public.py`）。

验收指标：

- 单 router 文件 ≤ 250 行；单 endpoint ≤ 40 行；
- 单 service 文件 ≤ 400 行（`live_readiness`/`factor_research`/`backtest_runner` 优先拆）；
- `grep -r "db.query\|select(" app/api` 归零（迁移期允许白名单）。

### 2.2 Web：按 feature 切，共用一套 UI/契约

```text
web/src/
├── app/                 # 入口、路由、Providers、ErrorBoundary
├── features/
│   ├── auth/
│   ├── dashboard/
│   ├── strategies/
│   ├── backtest/
│   ├── execution/
│   ├── risk/
│   ├── research/
│   ├── settings/
│   └── canvas/          # DAG 编辑器（唯一来源）
├── shared/
│   ├── api/             # OpenAPI 生成的 client + 查询 hooks
│   ├── ui/              # 设计系统（token + 基础组件）
│   ├── lib/             # 工具、格式化、错误
│   └── types/           # 生成的领域类型
└── styles/
```

每个 feature 固定四件套：

```text
features/<name>/
├── api.ts        # 端点调用（薄）
├── queries.ts    # TanStack Query hooks
├── components/   # 该域组件
└── pages/        # 路由页面
```

规则：

- 页面不直接 `fetch`，只调用 `queries.ts`；
- 跨 feature 只能 import `shared/` 或对方 `index.ts` 公开出口；
- 设计 token 只在 `shared/ui`；
- 画布只保留 `features/canvas`，`canvas-web/` 归档。

### 2.3 iOS：从 macOS 抽出共享 Core

现状 `Package.swift` 只有一个 executable target，iOS 不能复用。目标：

```text
AlphaLoopCore/            # SwiftPM library，平台无关
├── Models/               # Types、Enums、Codable
├── Services/             # NetworkClient、API*.swift
├── ViewModels/           # @Observable，@MainActor
├── DesignSystem/         # 颜色/字体/间距（无 AppKit）
├── Localization/         # L10n
└── Realtime/             # WebSocketManager

AlphaLoopiOS/             # iOS app target
├── App/
├── Views/                # iOS 专属导航/布局
└── Resources/

AlphaLoopMac/             # 冻结；只保留壳与 macOS 专属视图
```

当前落地方式（2026-11-15）：先让 iOS Xcode target 直接编译共享源码（`project.yml`），
避免一次性给 400+ 个声明加 `public/package`。下一步再抽 SwiftPM Core 并收敛访问级别。

规则：

- `AlphaLoopCore` 禁止 `import AppKit`；平台差异用 `#if os(iOS)` / `#if os(macOS)`；
- `AlphaLoopCore` 不依赖 SwiftUI 的 macOS-only API；
- iOS 首版复用 Dashboard / Strategy / Backtest / Risk 的 ViewModel 与 API 层，重写导航与布局；
- 画布用 `WKWebView` 加载同一份 React 构建产物，JS bridge 与 macOS 一致。

验收：

- `swift build --triple arm64-apple-ios` 能编译 Core（CI 用 `xcodebuild -destination 'generic/platform=iOS'`）；
- iOS target 不直接 `LiveNetworkClient()`，沿用环境注入。

### 2.4 契约：一份 OpenAPI，两端生成

```text
backend/contracts/openapi.json
        │
        ├── web: openapi-typescript + orval/react-query
        └── ios: swift-openapi-generator（或 CreateAPI）
```

规则：

- 手写 Response 类型只保留在生成器不可用的过渡期；
- DSL 的 JSON Schema 单独导出，画布与后端共用同一份校验定义；
- 契约变更必须走 spec + 版本号，不允许客户端猜字段。

## 3. 迁移顺序（低风险优先）

| 步骤 | 内容 | 风险 | 验收 |
|---|---|---|---|
| 1 | 后端加 `api/`/`contracts/` 目录，不动逻辑；新路由只进新目录 | 低 | 旧测试全绿 |
| 2 | 拆 `overview_aggregator` 重复实现；BFF 聚合下沉 service | 中 | `/api/overview/*` 契约不变 |
| 3 | 抽 `AlphaLoopCore`，macOS target 改为依赖 Core | 中 | macOS build 仍过 |
| 4 | Web 按 feature 迁移（已完成全部产品页；Landing/Previews 保留） | 中 | `tsc -b` 通过 |
| 5 | 画布合并到 `web/src/features/canvas`，归档 `canvas-web` | 中 | 同一份 bundle 被 iOS/macOS 加载 |
| 6 | OpenAPI 生成 TS/Swift client，删手写类型 | 高 | 两端编译 + 契约测试 |
| 7 | 多租户：`tenant_id` + RLS + JWT | 高 | 隔离测试（见多租户 spec） |

## 4. 前端组件化细节

- **设计系统**：token（颜色/字号/间距/圆角）→ primitives（Button/Input/Card/Table）→ patterns（PageHeader/EmptyState/DataTable）。页面不允许直接写 hex 或 `text-[13px]` 之外的一次性值。
- **数据表格**：统一 `DataTable`（排序/分页/空态/错误态/行操作），订单、持仓、回测列表复用。
- **图表**：统一 `ChartFrame`（加载/空态/时间范围/降采样），K 线、权益曲线、回撤共用。
- **状态**：服务端状态走 TanStack Query；UI 状态留在组件；全局只保留 auth/theme。
- **错误**：`ApiError` 统一映射到 `ErrorState`，展示 `reason_codes`，不吞异常。

## 5. iOS 组件化细节

- **导航**：Tab（总览/策略/执行/风控/我的）+ NavigationStack；桌面端另做 Sidebar。
- **列表/详情**：`ListScreen` + `DetailScreen` + `EmptyState` 统一组件。
- **图表**：Swift Charts（权益/回撤）+ WKWebView（K 线与画布）。
- **网络**：Core 的 `NetworkClient` 注入；iOS 用 Keychain 存 token；401 自动 refresh。
- **推送**：APNs → 后端 notification service；点击深链到对应 run/alert。
- **离线**：最近快照只读，下单按钮禁用并标注 `as_of`。

## 6. 明确不做

- 不在组件化过程中改 DSL 语义或交易逻辑；
- 不为了"看起来整齐"重写通过的模块；
- 不在 iOS 首版做画布编辑（只读）；
- 不保留 `canvas-web` 与 `web/src/canvas` 两份实现。

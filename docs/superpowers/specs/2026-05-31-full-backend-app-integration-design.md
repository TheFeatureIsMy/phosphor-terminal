# PulseDesk 全量后端-App 集成设计

> 目标: 将后端 18 个 router、66 个端点与 macOS app 全面对接，使 app 达到生产可用状态。

## 总览

采用混合方案（方案 C）: 基础设施先行 → 核心交易链路 → AI 功能域 → Risk + Canvas → 全局打磨。

### 依赖管理层

后端统一检测所有依赖状态，通过 API 下发给 App。App 根据状态智能展示引导页和功能降级。

---

## Phase 1: 基础设施层

### 1.1 修复硬编码 MockNetworkClient

| 位置 | 问题 | 修复 |
|------|------|------|
| `ToolbarView.swift:12` | `NotificationViewModel(client: MockNetworkClient())` | 改为 `@Environment(\.networkClient)` 注入 |
| `BacktestView.swift:52` | `APIStrategies(client: MockNetworkClient()).list()` | 改为使用环境注入的 client |
| `AppShellView.swift` ConsoleToolbar | 硬编码 "23%", "512MB", "12ms" | 读取 `DashboardViewModel.systemStatus` |
| `ForecastSectionView.swift:192-208` | 空数据时生成本地 mock | 显示 "暂无数据" 空状态 |

### 1.2 Token Refresh 机制

1. `KeychainService` 升级为 macOS Keychain 存储（`Security.framework`）
2. `LiveNetworkClient` 添加 401 拦截器: 收到 401 → 自动调用 `POST /auth/refresh` → 成功则重试原请求
3. Refresh token 过期 → 清除 token → 跳转登录页

### 1.3 WebSocket 实时推送

**后端新增**: `/ws` WebSocket 端点，支持订阅频道:

| 频道 | 推送内容 | 触发时机 |
|------|----------|----------|
| `dashboard` | KPIs 更新 | 交易执行/持仓变化 |
| `positions` | 持仓变化 | 开仓/平仓 |
| `notifications` | 新通知 | 风险事件/系统告警 |
| `orders` | 新订单 | 订单状态变化 |
| `risk` | 风险事件 | 风险规则触发 |

**App 新增**: `WebSocketManager` (`@Observable`)
- 连接管理: 自动重连、心跳检测
- 频道订阅: View 按需订阅
- 与现有轮询并存: WebSocket 断开时降级为 30s 轮询

### 1.4 Settings 持久化

1. 新增 `APISettings` service: `GET /auth/settings` + `PUT /auth/settings`
2. `SettingsState` 改为: 先从后端加载 → 本地修改 → 防抖 2s 自动保存到后端
3. Settings 字段与后端 `UserSettingsResponse` 对齐
4. 新增字段: `freqtrade_url`, `telegram_bot_token`, `telegram_chat_id`（从 env 迁移到用户设置）

### 1.5 依赖检测系统

**后端新增**: `GET /api/system/dependencies`

返回所有依赖状态:
```json
{
  "required": {
    "database": { "status": "ok", "detail": "SQLite at data/pulsedesk.db" }
  },
  "core_optional": {
    "ccxt": { "status": "installed", "version": "4.4.0" },
    "lightgbm": { "status": "not_installed", "install_cmd": "pip install lightgbm" },
    "transformers": { "status": "installed", "version": "4.50.3" },
    "torch": { "status": "installed", "version": "2.6.0" }
  },
  "ml_models": {
    "finbert": { "status": "loaded", "fallback": "keyword_sentiment" },
    "chronos": { "status": "not_loaded", "fallback": "unavailable" },
    "timesfm": { "status": "not_loaded", "fallback": "unavailable" },
    "shap": { "status": "loaded" }
  },
  "external_services": {
    "freqtrade_api": { "status": "connected", "url": "http://localhost:8080" },
    "freqtrade_db": { "status": "available" },
    "ollama": { "status": "connected", "url": "http://localhost:11434", "model": "qwen2.5:7b" },
    "openai": { "status": "not_configured", "requires": "OPENAI_API_KEY" },
    "anthropic": { "status": "not_configured", "requires": "ANTHROPIC_API_KEY" },
    "deepseek": { "status": "not_configured", "requires": "DEEPSEEK_API_KEY" },
    "qwen": { "status": "not_configured", "requires": "QWEN_API_KEY" },
    "zhipu": { "status": "not_configured", "requires": "ZHIPU_API_KEY" },
    "moonshot": { "status": "not_configured", "requires": "MOONSHOT_API_KEY" },
    "mimo": { "status": "not_configured", "requires": "MIMO_API_KEY" },
    "gemini": { "status": "not_configured", "requires": "GEMINI_API_KEY" },
    "groq": { "status": "not_configured", "requires": "GROQ_API_KEY" },
    "azure_openai": { "status": "not_configured", "requires": "AZURE_OPENAI_API_KEY" },
    "telegram": { "status": "dry_run" }
  },
  "readiness_score": 0.65
}
```

状态枚举: `ok` / `installed` / `not_installed` / `connected` / `not_configured` / `dry_run` / `error`

### 1.6 引导页 (SetupWizardView)

触发条件:
- 首次启动（`UserDefaults` 无 `setupCompleted` 标记）
- 后端 `readiness_score < 0.5` 时自动弹出

3 步引导:

| 步骤 | 内容 | 用户操作 |
|------|------|----------|
| 1. 核心依赖 | CCXT/Torch/LightGBM 安装状态 | 显示 `pip install` 命令，一键复制 |
| 2. AI 服务 | 12 个 LLM Provider 配置 | 输入 API Key 或确认 Ollama |
| 3. 交易服务 | Freqtrade + Telegram 配置 | 输入连接信息或跳过 |

### 1.7 AI Provider 列表

| Provider | 接口标准 | 需要 Key | 备注 |
|----------|----------|----------|------|
| Ollama | Ollama API | 否 | 本地运行，默认启用 |
| OpenAI | OpenAI 兼容 | 是 | GPT-4o / GPT-4.1 |
| Anthropic | Anthropic API | 是 | Claude Sonnet/Opus |
| DeepSeek | OpenAI 兼容 | 是 | 国内主力 |
| 通义千问 (Qwen) | OpenAI 兼容 | 是 | 阿里 |
| 智谱 (GLM/Zhipu) | OpenAI 兼容 | 是 | 国内主流 |
| Moonshot (Kimi) | OpenAI 兼容 | 是 | 国内主流 |
| 小米 MiMo | OpenAI 兼容 | 是 | 小米 AI |
| Google Gemini | Gemini API | 是 | 国际主流 |
| Groq | OpenAI 兼容 | 是 | 超快推理 |
| Azure OpenAI | OpenAI 兼容 | 是 | 企业级 |
| 自定义 (vLLM/LM Studio) | OpenAI 兼容 | 可选 | 用户填 Base URL |

OpenAI 兼容的 7 个复用 `OpenAIProvider`，配置不同 `base_url` + `api_key`。Gemini 需单独 provider class。

### 1.8 DependencyState 管理

**App 新增**: `DependencyState` (`@Observable`)
- 启动时调用 `GET /api/system/dependencies`
- 缓存结果，每 5 分钟刷新
- 提供 `isAvailable(_ dependency: Dependency)` 查询方法
- 提供 `readinessScore` 用于引导页

功能降级策略:

| 依赖缺失 | UI 表现 |
|----------|---------|
| Freqtrade | Dashboard 显示 "模拟数据" 徽章，Trades 显示空状态引导 |
| LLM Provider | AI Studio RAG/Research 标签显示 "需要 LLM 配置" 卡片 |
| ML 模型 | Forecast/Sentiment 标签显示 "模型未加载" + 预加载按钮 |
| Telegram | 通知设置显示 "干跑模式" 提示 |
| CCXT | 市场数据显示缓存数据 + "最后更新时间" |

---

## Phase 2: 核心交易链路

### 2.1 Dashboard 对接

| 改动 | 详情 |
|------|------|
| Toolbar 系统指标 | 从 `SystemStatus` 读取真实 uptime/apiStatus，移除硬编码 |
| Correlation 热力图 | Dashboard 新增 `CorrelationHeatmapView`，展示资产相关性矩阵 |
| 数据源徽章 | 每个 KPI 卡片显示 `DataSourceBadge`（真实/模拟） |
| WebSocket 接入 | KPIs + Positions + Orders 订阅 `dashboard` 频道 |
| 风险事件详情 | `ActivityFeedView` 点击展开详情，支持标记已处理 |

新增视图: `CorrelationHeatmapView`
- 5x5 矩阵，颜色映射相关性 (-1 ~ 1)
- 数据源: `GET /api/portfolio/correlation`

### 2.2 Strategies 对接

| 改动 | 详情 |
|------|------|
| 策略编辑 | Overview tab 添加"编辑"按钮，弹出 `StrategyEditSheet` |
| PUT 端点 | App 新增 `APIStrategies.update()` → `PUT /api/strategies/{id}` |
| 部署状态轮询 | Deploy 后 5s 轮询状态直到 active/error |
| 策略搜索 | Sidebar 搜索框连接 `GET /search?q=` 端点 |

### 2.3 Backtest 对接

| 改动 | 详情 |
|------|------|
| 策略选择器 | 使用环境注入的 client，移除 mock 硬编码 |
| 回测历史 | 新增历史列表 tab，调用 `GET /api/backtest` |
| 回测详情 | 点击历史记录调用 `GET /api/backtest/{id}` |
| 符号列表 | 从 `GET /api/markets` 获取真实交易对 |

### 2.4 Trades 对接

| 改动 | 详情 |
|------|------|
| 实时更新 | 订阅 `orders` + `positions` WebSocket 频道 |
| 筛选搜索 | 添加 symbol 筛选、side 筛选、时间范围选择 |
| 订单详情 | 点击行展开详情（fee, slippage, 策略来源） |
| 空状态 | Freqtrade 未连接时显示引导配置卡片 |

### 2.5 通知系统对接

| 改动 | 详情 |
|------|------|
| 修复注入 | `NotificationViewModel` 使用环境 client |
| WebSocket | 订阅 `notifications` 频道，实时推送新通知 |
| 通知操作 | 点击通知跳转对应路由（`actionRoute`） |
| Badge 动画 | 未读数变化时 pulse 动画 |

---

## Phase 3: AI 功能域

### 3.1 AI Studio 现有 6 Tab 完善

| Tab | 改动 |
|-----|------|
| RAG Lab | 文档上传连接 `POST /rag/upload`，知识库列表连接 `GET /rag/knowledge`，生成代码后添加"部署为策略"按钮 |
| Forecast | 空数据时显示"模型未加载" + 预加载按钮，移除本地 mock 生成 |
| Factor Research | 结果增加 IC 时序图、因子收益柱状图，连接 `GET /api/factors/list` |
| FreqAI | 训练进度实时展示（轮询 status），模型列表连接 runs 端点 |
| AI Research | 研究报告详情页（调用 `GET /api/ai-research/runs/{id}`） |
| Signals | 信号评分可视化（雷达图），Agent profile 详情 |

### 3.2 新增: Sentiment 视图

路由: `AppRoute.sentiment`，归入 Sidebar "AI" 分组。

3 个区块:

| 区块 | 内容 | API |
|------|------|-----|
| Fear & Greed 仪表盘 | 圆形仪表盘，0-100 刻度，颜色渐变 | `GET /sentiment/summary` |
| 市场情绪趋势 | 折线图，7/14/30 天切换 | `GET /sentiment/market/{symbol}` |
| 文本情绪分析 | 输入框 + 分析按钮，展示概率条 | `POST /sentiment/analyze` |

新增文件:
- `Views/Sentiment/SentimentView.swift`
- `Views/Sentiment/FearGreedGauge.swift`
- `Views/Sentiment/SentimentTrendChart.swift`
- `Views/Sentiment/TextSentimentAnalyzer.swift`
- `Services/APISentiment.swift`

### 3.3 新增: Attribution 视图

路由: `AppRoute.attribution`，归入 Sidebar "AI" 分组。

4 个 tab:

| Tab | 内容 | API |
|-----|------|-----|
| 特征重要性 | 水平柱状图，SHAP 值排序 | `POST /attribution/feature-importance` |
| 决策路径 | 树状图，展示模型决策路径 | `POST /attribution/decision-path` |
| 滑点分析 | 散点图 + 分布直方图 | `GET /attribution/slippage` |
| 归因报告 | 策略选择器 + 生成报告 + 历史列表 | `POST/GET /attribution/reports` |

新增文件:
- `Views/Attribution/AttributionView.swift`
- `Views/Attribution/FeatureImportanceChart.swift`
- `Views/Attribution/DecisionPathView.swift`
- `Views/Attribution/SlippageAnalysisView.swift`
- `Services/APIAttribution.swift`

### 3.4 新增: AI Provider 管理视图

路由: `AppRoute.aiProviders`，归入 Sidebar "AI" 分组。

2 个区块:

| 区块 | 内容 | API |
|------|------|-----|
| Provider 列表 | 12 个 provider 卡片网格，状态+Key 输入+测试按钮 | `GET /api/ai/providers` |
| 模型状态 | ML 模型加载状态 + 预加载按钮 | `GET /api/ai/models/status` |

每个 Provider 卡片:
- 左侧: 图标 + 名称 + 接口标准标签
- 中间: API Key 输入框 + Base URL（可展开）
- 右侧: 状态指示灯 + "测试连接" 按钮
- 底部: 可用模型列表（测试后展示）

新增文件:
- `Views/AIProviders/AIProvidersView.swift`
- `Views/AIProviders/ProviderCardView.swift`
- `Views/AIProviders/ModelStatusView.swift`
- `Services/APIAIProviders.swift`

### 3.5 依赖降级联动

| 依赖缺失 | 降级表现 |
|----------|----------|
| 无 LLM Provider | RAG Lab / AI Research 显示 "请先配置 LLM" 卡片 |
| FinBERT 未加载 | Sentiment 文本分析降级为关键词模式 |
| Chronos/TimesFM 未加载 | Forecast 显示 "模型未加载" + 预加载按钮 |
| SHAP 未加载 | Attribution 特征重要性降级为启发式 |
| CCXT 未安装 | Factor Research / Forecast 显示 "无市场数据" 空状态 |

---

## Phase 4: Risk 详情 + Canvas 持久化

### 4.1 Risk 详情扩展

路由: `AppRoute.risk`，归入 Sidebar "Trading" 分组。

4 个 tab:

| Tab | 内容 | API |
|-----|------|-----|
| 风险概览 | 风险等级仪表盘 + 关键指标卡片 | `GET /api/risk/events` + KPIs |
| 风险事件 | 事件列表，severity 筛选 + 时间范围 + 详情展开 | `GET /api/risk/events` |
| 相关性矩阵 | 交互式热力图，窗口天数切换 | `GET /api/portfolio/correlation` |
| 压力测试 | 历史列表 + 新建测试表单 | `POST/GET /api/portfolio/stress-tests` |

新增文件:
- `Views/Risk/RiskView.swift`
- `Views/Risk/RiskOverviewTab.swift`
- `Views/Risk/RiskEventsTab.swift`
- `Views/Risk/CorrelationMatrixTab.swift`
- `Views/Risk/StressTestTab.swift`
- `Views/Risk/RiskGaugeView.swift`

### 4.2 Canvas 持久化 + 一键部署

#### 4.2.1 后端: Canvas CRUD

新增端点:

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/strategies/{id}/canvas` | 保存 workflow graph JSON |
| GET | `/api/strategies/{id}/canvas` | 加载 workflow graph |
| PUT | `/api/strategies/{id}/canvas` | 更新 workflow graph |

数据模型: `canvas_workflows` 表
- `id` (TEXT PK), `strategy_id` (TEXT FK), `graph_json` (TEXT), `code_snapshot` (TEXT), `created_at`, `updated_at`

#### 4.2.2 App: 自动保存

`CanvasViewModel` 改造:
- 图变更时防抖 3s 自动保存到后端
- 打开策略详情时自动加载已保存的 canvas
- 离线时本地保存，上线后同步

#### 4.2.3 App: 一键部署

`StrategyCanvasTab` 工具栏新增 "生成并部署" 按钮:

```
CodeGenerator.generateCode(graph) → Python 代码
    ↓
显示代码预览弹窗（可编辑）
    ↓
POST /api/strategies/{id}/canvas (保存代码快照 + graph JSON)
    ↓
POST /api/strategies/{id}/deploy (部署当前策略)
    ↓
轮询状态直到 active/error
```

注: Canvas 始终绑定到已有策略（通过 StrategyDetailView 进入）。部署操作更新该策略的 Freqtrade 策略文件并启动 bot，不创建新策略。

新增文件:
- `Services/APICanvas.swift`
- `Views/Canvas/CodePreviewSheet.swift`
- `Views/Canvas/DeployProgressView.swift`

---

## Phase 5: 全局打磨

### 5.1 统一错误处理

新增 `ErrorHandler` (`@Observable`)，注入 Environment。

错误分类: 网络错误 / 认证错误 / 业务错误 / 服务器错误。

所有 ViewModel 统一模式:
```swift
func loadData() {
    isLoading = true
    error = nil
    do {
        data = try await client.get(endpoint: ..., mock: { ... })
    } catch {
        errorHandler.handle(error, context: "加载策略列表")
    }
    isLoading = false
}
```

### 5.2 Loading 状态标准化

| 级别 | 场景 | 表现 |
|------|------|------|
| 骨架屏 | 首次加载页面 | `ShimmerModifier` 骨架占位 |
| 内联加载 | 操作触发 | 按钮 spinner + 文字变化 |
| 全局加载 | 长时间操作 | 半透明遮罩 + 进度提示 + 取消按钮 |

### 5.3 空状态标准化

统一 `EmptyStateView` 扩展:

| 场景 | 图标 | 标题 | 操作按钮 |
|------|------|------|----------|
| 无策略 | plus.circle | "创建你的第一个策略" | 跳转创建 |
| 无交易记录 | arrow.left.arrow.right | "暂无交易记录" | 配置 Freqtrade |
| 无通知 | bell.slash | "暂无通知" | — |
| 无风险事件 | checkmark.shield | "一切正常" | — |
| 依赖未就绪 | gear.badge.xmark | "需要配置 {依赖名}" | 跳转设置 |
| 网络离线 | wifi.slash | "无法连接服务器" | 重试 |

### 5.4 Toast 通知系统

在 `AppShellView` 根层叠加 `ToastOverlayView`。

| 类型 | 颜色 | 时长 | 场景 |
|------|------|------|------|
| success | 绿色 | 3s | 操作成功 |
| error | 红色 | 5s | 操作失败 |
| warning | 黄色 | 4s | 依赖缺失 |
| info | 蓝色 | 3s | 信息提示 |

样式: 左侧图标 + 文字 + 右侧关闭，glass 背景，从顶部滑入。

### 5.5 全局搜索增强

`CommandPaletteView` 连接后端 `GET /search?q=` 端点:

| 类型 | 来源 | 点击行为 |
|------|------|----------|
| 页面 | 本地 AppRoute | 跳转页面 |
| 策略 | `GET /search?q=` | 跳转策略详情 |
| 操作 | 本地 action 列表 | 执行操作 |

### 5.6 响应式布局

- 窗口 < 1000px: 侧边栏折叠为图标模式
- 窗口 < 800px: 隐藏侧边栏，顶部 tab 导航
- 表格列自适应: 窄窗口隐藏次要列
- 卡片网格: 根据宽度 1/2/3/4 列

### 5.7 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd+K` | 全局搜索 |
| `Cmd+N` | 新建策略 |
| `Cmd+R` | 刷新当前页面 |
| `Cmd+,` | 打开设置 |
| `Cmd+1~9` | 切换侧边栏页面（按顺序） |
| `Esc` | 关闭弹窗 |

### 5.8 Sidebar 导航重组

```
Trading
  ├── Dashboard
  ├── Trades (Orders + Positions)
  └── Risk (新)

Strategy
  ├── Strategies
  └── Backtest

AI
  ├── AI Studio (RAG/Forecast/Factor/FreqAI/Research/Signals)
  ├── Sentiment (新)
  ├── Attribution (新)
  └── AI Providers (新)

System
  ├── Settings
  └── Notifications
```

`AppRoute` 新增: `.sentiment`, `.attribution`, `.risk`, `.aiProviders`

---

## 文件变更清单

### 后端新增/修改

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `routers/system.py` | 修改 | 新增 `GET /api/system/dependencies` 端点 |
| `routers/strategies.py` | 修改 | 新增 Canvas CRUD 3 个端点 |
| `routers/ai_providers.py` | 修改 | 新增 Gemini provider 支持 |
| `services/llm_service.py` | 修改 | 新增 GeminiProvider、完善 OpenAI 兼容 provider 列表 |
| `models/canvas.py` | 新增 | CanvasWorkflow 数据模型 |
| `schemas/canvas.py` | 新增 | Canvas 请求/响应 schema |
| `services/dependency_checker.py` | 新增 | 依赖检测逻辑 |

### macOS App 新增/修改

| 文件 | 变更类型 | 说明 |
|------|----------|------|
| `Models/Enums.swift` | 修改 | AppRoute 新增 4 个路由 |
| `Models/Types.swift` | 修改 | 新增 CanvasWorkflow、DependencyStatus 模型 |
| `Services/NetworkClient.swift` | 修改 | 401 拦截 + token refresh |
| `Services/WebSocketManager.swift` | 新增 | WebSocket 连接管理 |
| `Services/DependencyState.swift` | 新增 | 依赖状态管理 |
| `Services/ErrorHandler.swift` | 新增 | 统一错误处理 |
| `Services/APISettings.swift` | 新增 | Settings API 封装 |
| `Services/APISentiment.swift` | 新增 | Sentiment API 封装 |
| `Services/APIAttribution.swift` | 新增 | Attribution API 封装 |
| `Services/APIAIProviders.swift` | 新增 | AI Providers API 封装 |
| `Services/APICanvas.swift` | 新增 | Canvas CRUD API 封装 |
| `Services/APIRisk.swift` | 新增 | Risk 详情 API 封装 |
| `Views/AppShell/ToolbarView.swift` | 修改 | 移除硬编码 mock，使用环境 client |
| `Views/AppShell/AppShellView.swift` | 修改 | 路由扩展 + 错误处理 + Toast 叠加 |
| `Views/AppShell/SidebarView.swift` | 修改 | 导航重组 + 新增 4 个路由入口 |
| `Views/Dashboard/DashboardView.swift` | 修改 | 增加 Correlation 热力图 + 数据源徽章 |
| `Views/Dashboard/CorrelationHeatmapView.swift` | 新增 | 相关性热力图 |
| `Views/Backtest/BacktestView.swift` | 修改 | 移除 mock 硬编码 + 回测历史 |
| `Views/Trades/TradesView.swift` | 修改 | WebSocket + 筛选 + 详情展开 |
| `Views/Sentiment/SentimentView.swift` | 新增 | Sentiment 主视图 |
| `Views/Sentiment/FearGreedGauge.swift` | 新增 | Fear & Greed 仪表盘 |
| `Views/Sentiment/SentimentTrendChart.swift` | 新增 | 情绪趋势图 |
| `Views/Sentiment/TextSentimentAnalyzer.swift` | 新增 | 文本情绪分析 |
| `Views/Attribution/AttributionView.swift` | 新增 | Attribution 主视图 |
| `Views/Attribution/FeatureImportanceChart.swift` | 新增 | SHAP 特征重要性图 |
| `Views/Attribution/DecisionPathView.swift` | 新增 | 决策路径树 |
| `Views/Attribution/SlippageAnalysisView.swift` | 新增 | 滑点分析图 |
| `Views/AIProviders/AIProvidersView.swift` | 新增 | AI Provider 管理 |
| `Views/AIProviders/ProviderCardView.swift` | 新增 | Provider 卡片 |
| `Views/AIProviders/ModelStatusView.swift` | 新增 | 模型状态面板 |
| `Views/Risk/RiskView.swift` | 新增 | Risk 主视图 |
| `Views/Risk/RiskOverviewTab.swift` | 新增 | 风险概览 |
| `Views/Risk/RiskEventsTab.swift` | 新增 | 风险事件列表 |
| `Views/Risk/CorrelationMatrixTab.swift` | 新增 | 相关性矩阵 |
| `Views/Risk/StressTestTab.swift` | 新增 | 压力测试 |
| `Views/Risk/RiskGaugeView.swift` | 新增 | 风险仪表盘组件 |
| `Views/Canvas/CodePreviewSheet.swift` | 新增 | 代码预览弹窗 |
| `Views/Canvas/DeployProgressView.swift` | 新增 | 部署进度指示器 |
| `Views/Setup/SetupWizardView.swift` | 新增 | 引导页 |
| `ViewModels/DashboardViewModel.swift` | 修改 | WebSocket + Correlation |
| `ViewModels/StrategiesViewModel.swift` | 修改 | 新增 update 方法 |
| `ViewModels/BacktestViewModel.swift` | 修改 | 回测历史 + 移除 mock |
| `ViewModels/CanvasViewModel.swift` | 修改 | 自动保存 + 加载 |
| `ViewModels/NotificationViewModel.swift` | 修改 | WebSocket + 修复注入 |
| `DesignSystem/ViewModifiers.swift` | 修改 | 新增 Toast 样式 |

---

## 实施顺序

1. **Phase 1** (基础设施): ~5 天
   - 修 mock → token refresh → WebSocket 骨架 → Settings 持久化 → 依赖检测 → 引导页

2. **Phase 2** (核心交易): ~4 天
   - Dashboard → Strategies → Backtest → Trades → Notifications

3. **Phase 3** (AI 功能): ~5 天
   - AI Studio 完善 → Sentiment → Attribution → AI Providers

4. **Phase 4** (Risk + Canvas): ~4 天
   - Risk 详情 → Canvas 持久化 → 一键部署

5. **Phase 5** (全局打磨): ~3 天
   - 错误处理 → Loading/空状态 → Toast → 搜索 → 响应式 → 快捷键

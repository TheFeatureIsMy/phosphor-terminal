# PulseDesk (PulseDesk) — 项目知识档案

## §1 身份卡

| 字段 | 值 |
|------|-----|
| 产品名 | PulseDesk / PulseDesk |
| 一句话描述 | AI驱动的加密货币量化交易仪表盘 |
| 版本 | v0.3.0 |
| 技术栈 | React 19 + Vite 8 + Tailwind CSS v4 + TypeScript 6 (前端) \| FastAPI + SQLAlchemy + SQLite (后端) \| Freqtrade (交易引擎) |
| 当前 Phase | Phase 4 完成, Phase 5 待开始 |

## §2 当前状态

**已完成:**
- 13个前端页面: Landing, Login, Register, ForgotPassword, Dashboard, Strategies, StrategyDetail, StrategyCanvas, Backtest, Trades, Settings, Profile, StrategyLab
- 14个后端路由模块: strategies, orders, dashboard, backtest, risk, system, auth, search, notifications, attribution, sentiment, rag, ai_phase3, markets
- 后端服务: risk_rules, slippage, forecasting, market_registry, telegram_notifier, code_safety, strategy_registry, sentiment, shap, freqtrade_client, freqtrade_db, rag
- 数据模型: 11 个 SQLAlchemy 模型 (含 AttributionReport, SlippageAttribution, SentimentData, PortfolioStressTest, AI 相关)
- 前端组件: 24 个 UI 组件 + 品牌/Canvas/布局/通知/搜索/情绪/归因
- JWT认证系统: 注册/登录/Token刷新/路由守卫 + 完整 mock 回退
- Settings/Profile持久化: 后端API同步 + Zustand localStorage 持久化
- 全局搜索: 策略搜索 + 快捷键⌘K
- 通知中心: 实时轮询 + 已读管理
- SHAP归因分析: 特征重要性 + 决策路径可视化
- FinBERT情绪分析: 恐惧贪婪指数 + 情绪趋势图
- RAG策略实验室: PDF上传 + 知识库管理 + AI策略生成
- AI Phase 3: 预测引擎 (TimesFM/Chronos), 因子研究, FreqAI 增量学习
- 多市场插件: 加密货币 Binance 实现, 预留 Alpaca/JoinQuant 适配器
- 风控系统: 止损/最大回撤/相关性限制规则引擎
- 滑点归因: 执行滑点/价差成本/市场冲击/延迟成本分析
- Freqtrade双通道集成 (REST API + SQLite直读)
- Tauri v2 桌面壳: macOS vibrancy, 系统指标, 菜单栏
- 设计系统: Phosphor Terminal 风格, 深色主题, CSS变量体系 (bg/border/text/profit/loss)
- 全端点 mock 回退: 后端不可用时自动返回模拟数据

## §3 架构决策记录 (ADR)

| # | 决策 | 理由 |
|---|------|------|
| 1 | 双模式API客户端 (mock/real) | 前端可独立开发, 不依赖后端 |
| 2 | Freqtrade SQLite直读 + REST API双通道 | 直读性能好, REST API支持控制操作 |
| 3 | TanStack Query管理服务端状态 | 自动缓存/轮询/失效, 减少boilerplate |
| 4 | Zustand管理客户端UI状态 | 轻量, 适合sidebar collapse等简单状态 |
| 5 | CSS @theme + Tailwind v4 | 统一设计token, 减少内联样式 |

## §4 文件索引

```
src/
├── api/                    # API层 (client + 领域模块)
│   ├── auth.ts             # 认证API (直接fetch, 不走client.ts)
│   ├── client.ts           # 双模式API客户端 (超时+ApiError)
│   ├── dashboard.ts        # Dashboard/KPI/回测API
│   ├── orders.ts           # 交易/持仓API
│   ├── strategies.ts       # 策略CRUD API (分页适配, 内存数组mock)
│   └── mock-data.ts        # Mock数据生成器
├── components/
│   ├── attribution/        # SHAP归因可视化
│   ├── auth/               # ProtectedRoute 路由守卫
│   ├── brand/              # PulseDeskLogo 品牌组件
│   ├── canvas/             # 6种ReactFlow节点组件
│   ├── layout/             # AppShell + Sidebar + TopBar
│   ├── notifications/      # 通知中心
│   ├── search/             # 全局搜索弹窗
│   ├── sentiment/          # 情绪仪表盘
│   ├── shared/             # BacktestResults, TradesTable
│   └── ui/                 # 24个基础UI组件 (含动画组件)
├── hooks/                  # TanStack Query hooks + 工具hooks
│   ├── use-dashboard.ts    # Dashboard查询hooks (轮询10-30s)
│   ├── use-strategies.ts   # 策略CRUD mutations
│   ├── use-settings-sync.ts
│   ├── use-tauri-metrics.ts
│   ├── use-keyboard-shortcuts.ts
│   └── use-debounce.ts
├── lib/                    # 工具函数 + 数据结构
│   ├── utils.ts            # cn(), formatCurrency等
│   └── ... (bloom-filter, trie, heap, linked-list等)
├── pages/                  # 13个页面组件
├── stores/                 # 3个Zustand stores
│   ├── app-store.ts        # UI状态 (无persist)
│   ├── auth-store.ts       # 认证状态 (persist: pulsedesk-auth)
│   └── settings-store.ts   # 设置 (persist: pulsedesk-settings)
└── types/index.ts          # 领域类型定义
backend/
├── app/
│   ├── main.py             # FastAPI入口 (14 routers)
│   ├── config.py           # 配置 (pydantic-settings)
│   ├── database.py         # SQLAlchemy引擎
│   ├── models/             # 11个ORM模型
│   ├── schemas/            # Pydantic请求/响应模式
│   ├── routers/            # 14个路由模块
│   ├── services/           # 业务逻辑层
│   └── middleware/         # 错误处理/限流/日志
├── tests/                  # pytest测试套件
└── requirements.txt
src-tauri/                  # Tauri v2桌面壳 (Rust)
├── src/main.rs             # macOS vibrancy, 系统指标
├── build.rs
├── Cargo.toml
└── tauri.conf.json
```

## §5 技术栈详情

**前端:** React 19.2, Vite 8, TypeScript 6, Tailwind CSS v4, TanStack Query v5, Zustand v5, React Router v7, Recharts v3, @xyflow/react v12, Framer Motion v12, GSAP v3, OGL, lucide-react

**后端:** Python 3.11, FastAPI 0.115, SQLAlchemy 2.0, Pydantic 2.11, aiohttp 3.11, bcrypt, pyJWT

**桌面壳:** Tauri v2 (Rust), macOS vibrancy, 系统指标 API

**部署:** Docker Compose (FastAPI + Freqtrade双容器)

## §6 启动命令

```bash
# 前端开发
npm install && npm run dev        # http://localhost:5173

# 后端 (Docker)
docker-compose up -d              # http://localhost:8000
docker-compose logs -f api        # 查看日志

# 后端 (本地)
cd backend && pip install -r requirements.txt
uvicorn app.main:app --reload    # http://localhost:8000

# 健康检查
curl http://localhost:8000/health  # {"status":"ok"}

# Tauri 桌面壳 (macOS)
npm run tauri:dev                  # 开发模式
npm run tauri:build                # 生产构建
```

## §7 接手指引

1. 读 `src/types/index.ts` 了解领域模型
2. 读 `src/api/client.ts` 理解双模式API, `src/api/auth.ts` 注意不走共享client
3. 读 `src/index.css` 的 `@theme` 块了解设计token
4. 读 `AGENTS.md` 了解编码规范和陷阱
5. 新页面: 放 `src/pages/`, 在 `App.tsx` 注册路由
6. 新API: mock数据放 `mock-data.ts`, 领域函数放 `api/*.ts`, hook放 `hooks/*.ts`
7. 后端扩展: model放 `models/`, schema放 `schemas/api.py`, router放 `routers/`, 逻辑放 `services/`
8. 当前进度: `progress.md`, 待办: `task_plan.md`, 发现: `findings.md`
9. 开发前端无需启动后端 (`VITE_USE_MOCK=true` 默认)

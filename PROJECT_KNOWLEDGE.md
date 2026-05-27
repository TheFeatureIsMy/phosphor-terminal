# CyberQuant OS (Phosphor Terminal) — 项目知识档案

## §1 身份卡

| 字段 | 值 |
|------|-----|
| 产品名 | CyberQuant OS / Phosphor Terminal |
| 一句话描述 | AI驱动的加密货币量化交易仪表盘 |
| 版本 | v0.3.0 |
| 技术栈 | React 19 + Vite 8 + Tailwind CSS v4 + TypeScript 6 (前端) \| FastAPI + SQLAlchemy + SQLite (后端) \| Freqtrade (交易引擎) |
| 当前 Phase | Phase 4 完成 (全功能产品) |

## §2 当前状态

**已完成:**
- 13个前端页面: Landing, Login, Register, ForgotPassword, Dashboard, Strategies, StrategyDetail, StrategyCanvas, Backtest, Trades, Settings, Profile, StrategyLab
- 11个后端路由模块: strategies, orders, dashboard, backtest, risk, system, auth, search, notifications, attribution, sentiment, rag
- JWT认证系统: 注册/登录/Token刷新/路由守卫
- Settings/Profile持久化: 后端API同步
- 全局搜索: 策略搜索 + 快捷键⌘K
- 通知中心: 实时轮询 + 已读管理
- SHAP归因分析: 特征重要性 + 决策路径可视化
- FinBERT情绪分析: 恐惧贪婪指数 + 情绪趋势图
- RAG策略实验室: PDF上传 + 知识库管理 + AI策略生成
- Freqtrade双通道集成 (REST API + SQLite直读)
- 设计系统: Cyberpunk终端风格, 深色主题, CSS变量体系
- 全端点 mock 回退: Freqtrade 不可用时自动返回模拟数据

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
│   ├── auth.ts             # 认证API (登录/注册/Token)
│   ├── client.ts           # 双模式API客户端 (超时+ApiError)
│   ├── dashboard.ts        # Dashboard/KPI/回测API
│   ├── orders.ts           # 交易/持仓API
│   ├── strategies.ts       # 策略CRUD API (分页适配)
│   └── mock-data.ts        # Mock数据生成器
├── components/
│   ├── attribution/
│   │   └── SHAPChart.tsx   # SHAP归因可视化
│   ├── auth/
│   │   └── ProtectedRoute.tsx  # 路由守卫
│   ├── canvas/
│   │   └── CanvasNodes.tsx # 共享ReactFlow节点组件
│   ├── layout/
│   │   ├── AppShell.tsx    # 布局壳 (TopBar + Outlet)
│   │   ├── Sidebar.tsx     # 侧边导航
│   │   └── TopBar.tsx      # 顶部导航栏 (响应式)
│   ├── notifications/
│   │   └── NotificationCenter.tsx  # 通知中心
│   ├── search/
│   │   └── SearchModal.tsx # 全局搜索弹窗
│   ├── sentiment/
│   │   └── SentimentDashboard.tsx  # 情绪仪表盘
│   ├── shared/
│   │   ├── BacktestResults.tsx  # 共享回测结果展示
│   │   └── TradesTable.tsx      # 共享交易记录表格 (骨架屏)
│   └── ui/
│       ├── ErrorBoundary.tsx    # 全局错误边界
│       ├── FormControls.tsx     # 共享表单组件 (Field/Toggle等)
│       ├── PageHeader.tsx       # 页面标题组件
│       ├── Skeleton.tsx         # 骨架屏组件
│       └── Toast.tsx            # Toast通知系统
├── hooks/                  # TanStack Query hooks
│   └── use-settings-sync.ts    # 设置同步hook
├── lib/utils.ts            # 工具函数 (cn, formatCurrency等)
├── pages/                  # 13个页面组件
│   └── StrategyLabPage.tsx # RAG策略实验室
├── stores/
│   ├── app-store.ts        # Zustand UI状态
│   ├── auth-store.ts       # 认证状态 (JWT持久化)
│   └── settings-store.ts   # 设置状态存储 (后端同步)
└── types/index.ts          # 领域类型定义
```

## §5 技术栈详情

**前端:** React 19.2, Vite 8, TypeScript 6, Tailwind CSS v4, TanStack Query v5, Zustand v5, React Router v7, Recharts v3, @xyflow/react v12, Framer Motion v12, lucide-react

**后端:** Python 3.11, FastAPI 0.115, SQLAlchemy 2.0, Pydantic 2.11, aiohttp 3.11

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
```

## §7 接手指引

1. 读 `src/types/index.ts` 了解领域模型
2. 读 `src/api/client.ts` 理解双模式API
3. 读 `src/index.css` 的 `@theme` 块了解设计token
4. 新页面: 放 `src/pages/`, 在 `App.tsx` 注册路由
5. 新API: mock数据放 `mock-data.ts`, 领域函数放 `api/*.ts`, hook放 `hooks/*.ts`
6. 后端扩展: model放 `models/`, schema放 `schemas/api.py`, router放 `routers/`

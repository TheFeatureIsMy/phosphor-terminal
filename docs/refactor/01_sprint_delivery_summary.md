# 主流程重构 — Sprint 交付物总结

> 日期：2026-06-09
> 状态：Sprint 1-3 完成，Sprint 4 安全验收进行中

---

## Sprint 1: Foundation ✅

### Track A — Daily Trading Loop (Phase 1+2)

**后端新增：**
- `app/domain/workflow.py` — WorkflowState 模型
- `app/domain/enums.py` — +13 枚举 (Workflow/MTF/Shadow)
- `alembic/versions/e5f6a7b8c9d0_*.py` — 7 张新表迁移
- `app/services/bff/workflow_aggregator.py` — 9 步 Workflow 聚合
- `app/routers/workflow.py` — Workflow API (4 端点)
- `signals_v2.py` — +next-actions 端点
- `execution_bff.py` — +trade trace/review/labels

**前端新增：**
- `APIWorkflow.swift` — API 服务 + 类型
- `TradingWorkflowRailView.swift` — Dashboard Workflow Rail
- `StrategyLifecycleRailView.swift` — Strategy Lifecycle Rail
- `TradeSourceTraceView.swift` — Trade Source Trace
- `DashboardViewModel.swift` — +dailyWorkflow 加载
- `DashboardView.swift` — +WorkflowRail 集成

### Track B — MTF Guard Backend (Phase 3)

**后端新增：**
- `app/domain/snapshot.py` — +MTFGuardContext
- `app/domain/mtf_guard.py` — MTFGuardEvent/BacktestStats
- `app/domain/shadow_strategy.py` — ShadowStrategyDraft/UpgradeRequest 等 4 模型
- `app/domain/dsl.py` — +MTFGuardRule/ShadowWindowConfig/ViolationPolicy
- `app/services/mtf_temporal_guard.py` — 8 状态 MTF Guard 状态机
- `app/services/shadow_window.py` — Shadow Window 管理
- `app/services/structure_matrix_service.py` — 真实多 TF 分析
- `app/services/runtime_redis_store.py` — +MTF Guard Redis
- `app/routers/structure_bff.py` — +MTF Guard API

### Track D — DSL v3.0 Canvas Migration

**Canvas-Web 新增/修改：**
- `src/types.ts` — +MTFGuard 类型, v3.0 桥接
- `src/nodes/MTFGuardNode.tsx` — MTF Guard 节点
- `src/edges/MTFGuardEdge.tsx` — 7 状态自定义 Edge
- `src/converters/dslToGraph.ts` — v3.0 双向支持
- `src/converters/graphToDsl.ts` — v3.0 输出
- `src/panels/NodeConfigPanel.tsx` — +3 节点配置面板
- `src/hooks/useCanvasBridge.ts` — +mtfGuardStateUpdate
- `src/App.tsx` — 注册新节点/边类型
- `src/styles/theme.css` — +MTF 动画样式
- 测试：28/28 通过

---

## Sprint 2: MTF Frontend + Growth Foundation ✅

### Track B — MTF Guard 前端 (Phase 4)

- `APIMTFGuard.swift` — MTF Guard API + 类型 + mock
- `MTFGuardSummaryCard.swift` — Guard 状态卡片
- `StrategyDetailView.swift` — +LifecycleRail + MTFGuardSummary
- `StrategyDetailViewModel.swift` — +mtfGuards 加载
- `CanvasWebViewModel.swift` — +sendMTFGuardStateUpdate

### Track B — MTF Guard Replay (Phase 5)

- `app/schemas/mtf_guard_backtest.py` — Replay 响应模型
- `app/services/backtest_runner.py` — +MTFGuardReplayEngine
- `app/workers/backtest_handler.py` — +mtf_guard_replay
- `app/routers/backtest.py` — +include_mtf_guard, replay, stats 端点

### Track C — FeatureSnapshot + Failure Cluster (Phase 6+7)

- `app/domain/feature.py` — +mtf_guard/liquidity/ai/risk context 字段
- `app/services/feature_snapshot_service.py` — FeatureSnapshot CRUD
- `app/services/decision_engine.py` — +feature_snapshot_callback
- `app/services/trade_reviewer.py` — +label 持久化
- `app/services/failure_clustering.py` — +save_clusters/load_clusters
- `app/routers/execution_bff.py` — 真实 trace/labels/review
- `app/routers/failure_clustering_bff.py` — DB 持久化 + save 端点

---

## Sprint 3: Shadow Strategy ✅

### Phase 8 — Shadow Strategy Generator

- `app/services/dsl_patch.py` — DSLPatchService (11 模板, 8 种 Patch 类型)
- `app/services/shadow_strategy_generator.py` — 从 FailureCluster 生成 Draft
- `app/routers/shadow_strategy.py` — 9 个 API 端点

### Phase 9 — Validation & Upgrade

- `app/services/shadow_strategy_validation.py` — DSL 校验 + 增量回测
- `app/services/strategy_upgrade.py` — 升级请求/批准/拒绝/版本创建
- `strategies_v2.py` — +upgrade-requests 端点

### 前端

- `APIShadowStrategy.swift` — Shadow Strategy API + 类型
- `ShadowStrategyDraftView.swift` — Draft 详情（Patch Diff/Validation/Actions）
- `ShadowStrategySuggestionsPanel.swift` — 建议面板
- `StrategyUpgradeRequestView.swift` — 升级审批 UI

---

## 统计

| 指标 | 数量 |
|---|---|
| 新增后端服务 | 9 个 |
| 新增后端 API 端点 | ~25 个 |
| 新增数据库表 | 7 张 |
| 新增 SwiftUI 组件 | 8 个 |
| 新增 React Flow 组件 | 3 个 |
| 修改后端文件 | ~15 个 |
| 修改前端文件 | ~8 个 |
| Canvas 测试 | 28/28 通过 |
| macOS 编译 | ✅ |
| Python 语法 | ✅ 全部通过 |

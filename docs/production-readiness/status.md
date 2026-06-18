# Production Readiness Status

> 最后更新：2026-06-16
> 审计轮次：v2.5 / 第一轮 mock 清除
> 判定：🔴 **NOT production-ready** —— 4 个 P0 根因未修，UI 会静默展示假数据。

---

## 0. 一句话总结

三端审计共发现 **45 处 backend production-blocking mock + 5 个 macos-app 根因**。**canvas-web 无生产路径假数据**。本轮完成 1 处后端 P0 router 修复作为示范；剩余 4 个 P0 根因 + 12 个 P1 router + 8 个 P1 service 列入 [`remaining-blockers.md`](./remaining-blockers.md)。

---

## 1. 真实数据链路状态

### 1.1 端到端数据来源

| 端 | 真实数据源 | 当前是否生效 | 假数据兜底 |
|---|---|:---:|:---:|
| backend `overview/dashboard` | OverviewAggregator → Redis + Freqtrade + DB | ✅ | ❌ → `_mock_dashboard` (已改) |
| backend `overview/live-readiness` | LiveReadinessService | ✅ | ❌ → `_mock_live_readiness` (已改) |
| backend `overview/global-status` | OverviewAggregator | ✅ | ❌ → `_mock_global_status` (已改) |
| backend `execution/center` | FreqtradeClient | ✅ | ❌ → `_mock_center` |
| backend `execution/orders` | FreqtradeClient + freqtrade_db | ✅ | ❌ → `_mock_orders_positions` |
| backend `execution/positions` | FreqtradeClient + freqtrade_db | ✅ | ❌ → `_mock_orders_positions` |
| backend `orders` | freqtrade_db.get_trades | ✅ | ❌ → `_mock_orders` (含 random) |
| backend `positions` | freqtrade_db.get_open_trades | ✅ | ❌ → `_mock_positions` |
| backend `risk/overview` | RiskEngine + Redis | ✅ | ❌ → `_mock_overview` |
| backend `risk/stop-protection` | stop_protection_service | ⚠️ service 自身 mock | ❌ |
| backend `risk/circuit-breakers` | risk_rules | ✅ | ❌ → `_mock_circuit_breakers` |
| backend `structure/matrix` | structure_matrix_service | ✅ | ❌ → `_mock_matrix` |
| backend `structure/mtf-guard-events/{id}` | TODO | ❌ 纯 mock | ❌ |
| backend `structure/market-view` 等 5 个 | market_structure | ✅ | ❌ → 4 个 `_mock_*` |
| backend `data-sources` | providers registry | ✅ | ❌ → `_mock_sources` |
| backend `reconciliation/bus` | command_bus | ✅ | ❌ → `_mock_bus` |
| backend `portfolio/correlation` | freqtrade_db 计算 | ✅ | ❌ → `_mock_correlations` |
| backend `growth/signal-validity` | signal_repository | ⚠️ 占位假值 | ❌ |
| backend `growth/shap-features` | SHAP | ⚠️ 占位假值 | ❌ |
| backend `growth/failure-*` 5 个 | failure_clustering | ✅ | ❌ → 4 个 `_mock_*` |
| backend `manipulation/radar` 等 6 个 | radar_service | ❌ 全程 Mock adapter | ❌ |
| backend `factor-research` | CryptoFactorBackend | ✅ | ❌ → `StubFactorBackend` 静默降级 |
| **macos-app 启动首屏** | `AlphaLoopApp.networkClient` | ❌ 默认 MockNetworkClient | ❌ |
| **macos-app 后端不可达** | `detectBackendAndConfigure` | ❌ 静默 fallback | ❌ |
| **macos-app auto-login** | `authState.mockLogin()` | ❌ 静默登录 | ❌ |
| **macos-app LiveReadiness 初始值** | ViewModel init | ❌ 预填 mock | ❌ |
| **macos-app AIProviders 假延迟/失败率** | `.random(in:)` | ❌ 任意模式 | n/a |

### 1.2 数据库真相源（v2.5 ERD）

数据库 schema 是真实的：signals（分区表）/ strategies / strategy_versions / freqtrade_runs / execution_ledger_events / trade_intents / risk_decisions 等核心表都已建模。Execution Ledger 是不可变事实源（ADR-006）。

**问题不在 schema，在 service / router 层把"无数据"等同于"展示假数据"**。

### 1.3 真实服务依赖

| 依赖 | 配置项 | 缺失时行为 | 是否阻断 |
|---|---|---|:---:|
| PostgreSQL | `DATABASE_URL` | service 抛异常 → router fallback 到 mock | ✅（修复中） |
| Redis | `REDIS_URL` | RuntimeRedisStore 用 in-memory 兜底 | ⚠️ 兜底本身合理，但 router 在 Redis 空时仍走 mock |
| Freqtrade | `FREQTRADE_URL` | FreqtradeClient 抛异常 → router fallback 到 mock | ✅ |
| Binance/OKX/Bybit | exchange API | 未实现真实适配器 | 🔴 Manipulation Radar 全程假数据 |
| AI Provider | OpenAI/Ollama 配置 | 部分用本地模型 | ⚠️ |

---

## 2. 投产就绪度评估

### 2.1 当前等级

| 维度 | 状态 | 说明 |
|---|:---:|---|
| 数据真实链路 | 🟡 | 后端 service / DB 真实存在，但 router 兜底为假数据 |
| 前端真实数据消费 | 🔴 | macos-app 默认走 Mock，无显式切换 |
| 异常/空态 UX | 🔴 | 无后端时静默展示假数据，用户无法识别 |
| 安全 / 风控 | 🟢 | v2.5 三层风控 + RiskEngine 设计完整 |
| 数据库 schema | 🟢 | v2.5 ERD 落地，Execution Ledger 不可变 |
| 测试 | 🟢 | ~78 文件 / ~915 functions，CI ≥30% coverage gate |
| L10n | 🟢 | 全量 zh+en，无 L10n 路径假数据 |

### 2.2 投产前必修

详见 [`remaining-blockers.md`](./remaining-blockers.md)：

- **P0（4 个）**：
  1. `macos-app/Services/NetworkClient.swift:11` `defaultValue = MockNetworkClient()`
  2. `macos-app/AlphaLoopApp.swift:20` `@State var networkClient = MockNetworkClient()`
  3. `macos-app/AlphaLoopApp.swift:92-101` 后端不可达时静默 fallback
  4. `macos-app/AlphaLoopApp.swift:110-112` Mock 模式自动 `mockLogin()`
- **P0（1 个 UI 残留）**：
  5. `macos-app/Views/AIProviders/AIProvidersView.swift:134,136` `.random(in:)` 假延迟 / 失败率
- **P0（1 个 service 根因）**：
  6. `backend/services/stop_protection_service.py:87-107` `_mock_positions()` 恒假持仓
- **P0（1 个 service 根因）**：
  7. `backend/services/manipulation/radar_service.py:24,32-43` 硬编码 Mock adapter

### 2.3 投产前应修

- **P1（12 个 BFF router）**：execution_bff、orders、risk_bff、structure_bff、market_structure_bff、data_source_bff、reconciliation_bff、risk.correlation、growth、failure_clustering_bff、manipulation、factor_research
- **P1（5 个 manipulation adapter）**：移到 `tests/` 或加 `@deprecated(provider-not-configured)`
- **P2（2 个 placeholder）**：`overview_aggregator._fetch_recent_decisions` / `_fetch_alerts`

---

## 3. 本轮已修复

- ✅ `routers/overview.py` 4 个 endpoint 改为异常时返回 `data_source_unavailable` + 空数据 + `reason_codes`，不再以 `_mock: True` 静默返回假数据。
- ✅ 3 份报告：mock-removal-report.md、production-readiness/status.md、remaining-blockers.md。

---

## 4. 投产判断

**当前不能投产**。即便只让产品 owner 本人使用：

1. 启动 App → 默认拿到 MockNetworkClient → 看到的是"正常运行"的假 dashboard / 假订单 / 假持仓 / 假 PnL / 假 AI 判断，**用户**无法识别数据是真是假。
2. 后端任何服务抖动 → router 静默 fallback 到假数据 → 用户看到的是"系统稳定运行"的假象。
3. Manipulation Radar 全程在 `random` 数据上跑 ML 训练和规则检测。
4. Stop Protection 永真返回 2 个假 BTC/ETH 持仓。

**修完 7 个 P0 根因后，可以进入小资金 dry-run 验证**；**P1 全清后才能进入 live_small 试运行**。

## 5. P1 修复后（2026-06-16）

### 5.1 修复汇总

- ✅ **P1-1+3** —— 12 个 BFF router 模板化修复 + factor_research 静默降级（13 个文件）
- ✅ **P1-2** —— macos 前端识别 `data_source_unavailable`（5 个文件，含 2 新文件）
- ✅ **P1-4** —— `overview_aggregator` 空 placeholder 处理（1 个文件）

### 5.2 当前 P0 / P1 状态

| 类别 | 总数 | ✅ 修复 | 剩余 |
|---|:---:|:---:|:---:|
| **P0 根因** | 8 | 8 | 0 |
| **P1 router / frontend / aggregator** | 14+ | 14+ | 0 |
| **P2（投产前可改可不改）** | 5 | 0 | 5 |

### 5.3 投产判断更新

- **P0 + P1 全清** —— 后端不再静默返回假数据；前端能识别 `data_source_unavailable` 并显示空态；overview_aggregator 移除空 placeholder。
- **未连接后端时** —— macos app 显示「后端未连接」错误页（不静默 fallback）
- **后端 service 异常时** —— router 返回 `data_source_unavailable` + 空数据；前端 DashboardView 显示「数据源暂不可用」空态
- **Manipulation Radar** —— adapter 缺失时 `raise ProviderNotConfiguredError`（无静默 mock）；真实数据接入待 Phase 5
- **Stop Protection** —— 读 `FreqtradeDB.get_open_trades()` 真实持仓；止损位标记 `stop_calculation_pending`（StructureEngine 接入待后续）

**下一阶段门槛**：进入小资金 dry-run 验证（需 Freqtrade 真实运行 + 真实交易所 API key）。Phase 5 manipulation 真实数据接入为下一阶段任务。

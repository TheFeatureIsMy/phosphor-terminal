# AlphaLoop 工程审计 · GitHub 技能选型 · 业界差距分析

> 日期：2026-11-15 · 范围：`backend/` `macos-app/` `web/` `canvas-web/` `freqtrade/` `docs/`
> 方法：静态读码（AST/grep）+ 运行时验证（pytest 全量、DSL 契约复现）。所有结论带文件/行号或命令输出。
> **方向修正（2026-11-15 晚）**：产品目标改为 iOS/Android/Windows/macOS 四端 App + 远程多租户服务端，macOS 原生客户端暂停。
> 本文中"砍 web / macOS 为主"的客户端结论作废；后端安全与可靠性结论仍有效。新架构见
> [multi-client-saas-architecture-design.md](../superpowers/specs/2026-11-15-multi-client-saas-architecture-design.md)。
>
> **修复进展（2026-11-15 晚）**：鉴权、密钥 fail-closed、准入看板真实化、2 个红灯测试已修复，见 [P0 修复计划](./2026-11-15-p0-remediation-plan.md)。本文保留审计时点结论。
> 限制：沙箱内 `swift test` 无法编译（SwiftPM manifest 需要访问 `/var/folders` 临时目录，被 sandbox 拒绝），macOS 侧结论为静态取证。

---

## 0. 结论摘要

**产品定位是稀缺的，工程底座是"可运维原型"，不是"可实盘系统"。**

1. **差异化成立**：可视化 DAG → 可回测 DSL、操纵检测进策略原语、八类 Provider 统一治理、五级实盘闸门。业界没有同构产品（Coinrule 是表单，TradingView 是代码，Nautilus/LEAN 是纯代码）。
2. **三道硬伤挡住实盘**：
   - **无鉴权**：305 条路由中仅 3 条校验 token；`/api/trading/start-live-small`、`/api/v2/emergency/stop`、`/api/admin/providers/*` 均可匿名调用。
   - **准入看板门禁是 stub**：`live_readiness_service.py:978-1028` 只判断 `strategy_id` 非空就返回 healthy，任意 ID 即可显示 `ready_for_live`。
   - **凭据默认明文**：`PULSEDESK_ENCRYPTION_KEY` 未在 `.env/.env.example` 中定义 → Fernet passthrough；JWT 用公开默认密钥签名。
3. **当前工作区不是绿的**：pytest `1448 passed / 2 failed / 3 skipped`（154s）。CI 只跑后端 + `swift build`，不跑 `swift test`；web 零测试。
4. **客户端已经分裂**：macOS 114 个端点、web 43 个、交集仅 28 个；画布两份（`canvas-web` 与 `web/src/canvas`）。web 版新增 7 类另类数据节点，但后端 DSL 拒收 → 发布必失败。
5. **优先顺序**：安全基线 → 门禁真源 → DSL 契约 → 测试门禁 → 回测真实性/组合风控 → 客户端收敛。

---

## 1. GitHub 开发技能选型

### 1.1 选型标准

不是"star 多就装"，而是按本项目的三个真实缺口选：**流程纪律**（spec→plan→TDD→review）、**量化验证**（防过拟合/泄漏）、**规范固化**（把本仓库的约定写成可复用 skill）。

### 1.2 推荐清单（截至 2026-11-15）

| 优先级 | 仓库 | 规模 | 许可 | 选它的理由 | 用在哪 |
|---|---|---|---|---|---|
| P0 | [obra/superpowers](https://github.com/obra/superpowers) | 317.9k★，15 个技能 | MIT | 最成熟的"工程流程"技能包：brainstorming、writing-plans、TDD、systematic-debugging、requesting/receiving-code-review、verification-before-completion、subagent-driven-development | 本仓库 `docs/superpowers/specs/` 已经在用它的产物格式，但技能本身没装；装完可直接约束"先 spec 后实现" |
| P0 | [ml4t/skills](https://github.com/ml4t/skills) | 47★，10 大类 | Apache-2.0 | 唯一成体系的"量化 ML 正确性"技能包：`cpcv`、`deflated-sharpe`、`walk-forward-cv`、`purging-embargo`、`triple-barrier`、`feature-store`、`shap-analysis`、`drift-detection` | 直接对应 `factor_research.py`、`shap_service.py`、`label_generator.py`、`feature_snapshot_service.py`；星少但作者是《Machine Learning for Algorithmic Trading》作者 Stefan Jansen，内容权威 |
| P1 | [anthropics/skills](https://github.com/anthropics/skills) | 195.1k★，19 个技能 | 分技能 MIT/Apache | 官方参考实现：`skill-creator`（把项目规范写成 skill）、`mcp-builder`（本仓库已有 `/api/mcp` 与 MCP 路由）、`frontend-design`、`webapp-testing`（Playwright E2E，正好补 web 零测试） | 固化 3 个项目 skill；给 web 补 E2E |
| P2 | [github/spec-kit](https://github.com/github/spec-kit) | 149.9k★ | MIT | GitHub 官方 SDD：constitution → specify → plan → tasks → implement，支持 30+ agent | 可选。与现有 superpowers spec 流程重叠，只有在需要"PRD 条目 ↔ 任务 ↔ 测试"可追溯时才引入 |

**不建议**：
- 各类 `awesome-claude-skills` 聚合清单（`everything-claude-code` 等）：体量大、质量不可控，和现有流程冲突。
- 设计类技能：本仓库已锁定 `design-taste-frontend`（`skills-lock.json`），并自带 `dist-skills/web3-aesthetic-systems`，不缺。

### 1.3 与本仓库的具体结合点

| 技能 | 对应代码 | 预期收益 |
|---|---|---|
| `superpowers:writing-plans` | `docs/superpowers/specs/` 已有 30+ spec | 计划粒度到"文件+验证命令"，减少"一次改 49 个文件不提交"的情况 |
| `superpowers:test-driven-development` | 后端 1453 个测试、macOS 109 个 `@Test` | 修门禁/鉴权这类高风险改动时强制 RED→GREEN |
| `ml4t:deflated-sharpe` + `cpcv` | `factor_research.py`（1151 行，含 IC/多空/Fama-MacBeth/OOS） | 现在的因子评估缺"多重检验校正"和"组合 purged CV"，这是过拟合的主要来源 |
| `ml4t:shap-analysis` | `shap_service.py` | 统一 SHAP 解释口径（beeswarm/waterfall/交互） |
| `ml4t:triple-barrier` | `label_generator.py` | 标签泄漏是量化 ML 第一大坑，技能里有现成检查清单 |
| `anthropics:skill-creator` | `CLAUDE.md`/`AGENTS.md` | 把"thin router / L10n / 设计 token / BFF 三级回退"写成 3 个项目 skill，减少 agent 漂移 |
| `anthropics:webapp-testing` | `web/`（16k 行、0 测试） | 用 Playwright 覆盖登录→总览→回测→风控 4 条主链路 |

### 1.4 落地建议（不自动安装）

1. 先装 P0 两个（流程 + 量化验证），不要一次装全家桶。
2. 用 `skill-creator` 写 3 个项目 skill：`alphaloop-backend-conventions`、`alphaloop-api-dsl-contract`、`alphaloop-safety-gates`，放进所用 agent 的 skills 目录（Claude Code 为 `.claude/skills/`，Qoder 用对应目录）。
3. 注意 `.gitignore` 当前忽略了 `skills/`；如果希望团队共享，新建 `docs/skills/` 或显式放行路径，不要直接依赖被忽略的目录。
4. 若要装到当前 DSH profile，需要把 skill 目录放进 profile/打包成 bundle；确认后我可以代做。

---

## 2. 项目体检

### 2.1 规模

| 模块 | 文件 | 行数 | 说明 |
|---|---:|---:|---|
| `backend/app` | 390 py | 45,289 | 54 个 router、95 个 service、305 条路由 |
| `backend/tests` | 165 py | 21,512 | 1,453 个测试（收集数） |
| `macos-app/AlphaLoop` | 272 swift | 44,845 | 146 个 View、21 个 VM、41 个 API 文件、109 个 `@Test`（21 个 disabled） |
| `web` | 96 ts/tsx | 16,090 | Tauri 2 + React 19，18 个 page 目录，0 测试 |
| `canvas-web` | 25 ts/tsx | 2,703 | 4 个测试文件、619 行测试 |
| `docs` | 99 md | — | 架构 00–17 + specs + user-guide |

**总计约 10.9 万行产品代码 + 2.2 万行测试**；其中 web（1.6 万行）和第二份画布是重复建设的主要部分。

### 2.2 做得好的（保持）

1. **DSL 语义层完整**：`app/domain/dsl.py` 白名单枚举（21 指标 / 10 操作符 / 8 可执行规则）、`dsl_validator` + `dsl_hasher` + `dsl_migrator` + `dsl_patch`；无 `eval/exec`。业界多数 DSL 只有"能存能读"，缺迁移与哈希。
2. **Command Bus 骨架合格**：幂等键唯一约束、优先级 + 部分索引、指数退避（`command_worker.py:169-184`）、`FOR UPDATE SKIP LOCKED`（`:49`）、stale recovery、哈希链账本（`:195-216`）。
3. **状态机是纯函数**：`strategy_transition.py:16-38`，router 侧三重校验（系统专属转移 403、非法转移 409）。
4. **执行账本可追溯**：`event_hash`、`correlation_id/causation_id`、`sequence_no`；对账有 `state_leases` 租约。
5. **Provider 八类适配器**：Protocol + 注册表 + 健康调度，配置落 `provider_configs`，审计端点齐全（`admin/providers.py:34-38`）。
6. **显式降级而非假数据**：BFF 用 `data_source_unavailable` + `reason_codes`，空结构对齐 schema（`overview.py:26-92`），比静默 mock 好。
7. **AI 研究有"不确定性契约"**：`research_v2` 落库 `facts / model_interpretation / uncertainty / risk_warning / strategy_impact / prompt_version`，比多数"AI 喊单"产品严谨。
8. **L10n 纪律好**：1,615 处 `L10n.` 引用，Views 内硬编码中文仅 2 处；24 个域文件、1,310 个 key。
9. **文档密度高**：99 篇 md、逐页验收清单、spec 用 `Supersedes:` 管理。
10. **本地优先架构**：macOS 原生 + 本地后端，数据与密钥不出机器，适合"个人量化工作台"定位。

### 2.3 缺陷与风险（按严重度）

| 级别 | 问题 | 证据 | 后果 |
|---|---|---|---|
| **P0** | **全站几乎无鉴权** | 305 条路由仅 3 条带 `get_current_user`；`middleware/` 只有 error/rate/logger | 匿名即可启动实盘、紧急停止、改风控规则、读写 Provider 凭据 |
| **P0** | **JWT 默认密钥** | `config.py:20` 默认 `pulsedesk-dev-secret-change-in-production`；`.env` 未定义 `SECRET_KEY` | 可伪造任意用户 token |
| **P0** | **凭据默认明文** | `crypto_service.py:17-33` 无 key 即 passthrough；`.env/.env.example` 均无 `PULSEDESK_ENCRYPTION_KEY`；测试日志出现 `running in passthrough mode` | 交易所/LLM 密钥以 JSON 明文落库；解密失败静默返回原值 |
| **P0** | **准入看板门禁是 stub** | `live_readiness_service.py:978-1028`：`_check_validation/_check_backtest/_check_dryrun` 只看 `strategy_id` 是否为空；`dryrun` 直接返回 `"100h"` | 任意策略 ID 即显示 `ready_for_live`；UI 与真实准入脱节 |
| **P0** | **DSL 契约断裂** | `DSLRuleType` 声明 14 种，`DSLRule` union 只有 8 种；实测 `sentiment_filter/funding_filter` 被 Pydantic 拒绝（v2.5 与 v3.0 均失败）；web 画布恰好会产出 7 种被拒规则 | 画布"另类数据节点"打开发布必报 `DSL_V3_VALIDATION_FAILED` |
| **P1** | **测试门禁失效** | 当前 `1448 passed / 2 failed`；CI 无 `swift test`（`.github/workflows/ci.yml:36-44`）；`MockNetworkClient` 对无 mock 的调用 `fatalError`（`NetworkClient.swift:23-25`），`APIServiceTests` 仍走该路径 | 测试红灯被忽略；macOS 测试一旦运行会 trap；web 0 测试 |
| **P1** | **Command Bus 会丢/饿死命令** | 超时直接置 `TIMEOUT` 且不消耗 `max_retries`（`command_worker.py:137-161`）；reconciling 阻塞时 `acquire_next` 返回 `None`（`:51-56`）；单线程执行 `subprocess.run` 可达 600s | worker 崩溃丢命令；回测阻塞所有其他命令；低优先级命令饿死 |
| **P1** | **风控状态不可靠** | `account_risk_firewall.py:13-14` 模块级 bool；`risk_bff.py:485-543` 公开 `PUT /rules` 可写 `kill_switch_active` 且不重算 `policy_hash` | 重启丢"禁新开仓"；多 worker 分叉；审计哈希失真 |
| **P1** | **异步阻塞 + 异常吞噬** | 27 条 async 路由注入同步 `Session`；`app/` 内 254 处 `except Exception`；BFF 异常转 200 + `data_source_unavailable` | 事件循环被阻塞；故障不进 5xx，监控/SLO 失明 |
| **P1** | **重复实现/词表漂移** | `overview_aggregator.py`（378 行）与 `bff/overview_aggregator.py`（122 行）并存；state 词表三套；`risk_rules.py`/`risk_rules_service.py`/`risk_engine.py` 职责重叠 | 同名字段不同语义，客户端只能靠 `unwrapList` 猜形状 |
| **P1** | **回测真实度不足** | `backtest_runner.py:148-155` 把滑点折进 `trading_fee`；`trading_mode` 硬编码 `spot`；无资金费/保证金/爆仓/部分成交；结果解析在找不到本次文件时会取最新文件（`:283-300`） | 回测偏乐观；并发回测可能读到别人的结果 |
| **P1** | **三端重复** | macOS 114 端点 vs web 43，交集 28；`canvas-web` 与 `web/src/canvas` 两份；web 仅 1 次提交 | 每加一个功能要改 2–3 处；旗舰端能力落后于副端 |
| **P2** | **数据层薄** | `market_data.py` 用 SQLite 缓存 + Binance 公共 REST 轮询；无多交易所/无 point-in-time | 数据质量与可复现性不足；断网即降级 |
| **P2** | **文档漂移** | AGENTS 写 3 个代码库（实际 4 个）、46 router（实际 54）、146 测试文件/1285 函数（实际 165/1453）；changelog 顶部仍挂 "UNVERIFIED CODE" | 新人和 agent 被错误信息误导 |
| **P2** | **仓库卫生** | 49 个文件未提交、+1,726/−1,071 行改动；`freqtrade/*.sqlite-wal` 未忽略；无 `pyproject/ruff/mypy/eslint`；无依赖锁文件；覆盖率门槛 30% | 无法复现构建；重构无静态保护 |

### 2.4 关键横切问题

- **"门禁"有两套**：UI 用的 `/api/overview/live-readiness` 是 stub；真正启动用的 `/api/trading/start-live-small` 走 `RunHistoryStatsRepository` + `check_preconditions`（真实 7 项）。所以不是"能绕过实盘检查"，而是**看板撒谎 + 无鉴权 + 确认口令是公开常量**，三者叠加后风险仍然成立。
- **"安全"只有开关，没有身份**：`LIVE_SMALL_ENABLED=False` 是唯一有效防线；一旦打开，任何能访问 8000 端口的人都能发起实盘。
- **"测试多"不等于"测对了"**：`tests/test_live_small.py:474-503` 直接把 4 个 infra 检查替换掉，并断言不存在的 `strategy_id="s1"` 可以 `can_start_live_small=True`，把 stub 行为固化成预期。

---

## 3. 业界对标

### 3.1 能力矩阵（●强 ◐部分 ○缺）

| 对象 | 策略表达 | 可视化 | 回测真实度 | OMS/执行 | 组合风控 | 数据管道 | 可观测 | AI/LLM | 实盘闸门 |
|---|---|---|---|---|---|---|---|---|---|
| **AlphaLoop** | DSL+DAG ● | ● | ◐ 费+滑点合并 | ◐ Freqtrade REST+SQLite | ◐ | ◐ 8 类 provider | ◐ | ● | ● 五级 |
| Freqtrade | 代码 ● | ○ | ◐ 费+滑点 | ◐ | ◐ | ◐ | ● freqUI | ◐ FreqAI | ◐ dry-run |
| NautilusTrader | 代码 ● | ○ | ● L2/L3 + 11 种 fill model | ● NETTING/HEDGING | ● margin | ● Parquet catalog | ● reports | ○ | ◐ |
| QuantConnect LEAN | 代码 ● | ◐ | ● 五类 reality model | ● | ● Portfolio+Risk | ● dataset market | ● reports | ◐ | ◐ |
| Jesse | 代码 ● | ◐ | ◐ | ◐ | ◐ | ◐ | ● | ◐ MCP | ◐ |
| Hummingbot | 脚本 ◐ | ○ | ○ | ● | ◐ | ◐ | ◐ | ○ | ◐ |
| Composer | symphony ◐ | ◐ | ◐ 含监管费 | ◐ 再平衡 | ● | ◐ | ◐ | ● MCP | ◐ |
| Coinrule | 条件块 ○ | ● 表单 | ○ | ◐ | ◐ | ○ | ◐ | ◐ LLM→规则 | ◐ |
| TradingAgents | agent 图 ○ | ○ | ◐ | ○ | ◐ 辩论 | ◐ | ◐ | ● | ○ |

### 3.2 行业标配（缺一项就被淘汰）

手续费/滑点可配、多标的回测、参数优化（hyperopt）、dry-run、REST/Webhook 外部控制、回测→实盘同一策略对象、净值/回撤/胜率报告、多交易所、策略版本化。Freqtrade / LEAN / Jesse / Composer / 3Commas 均覆盖。

### 3.3 2026 年五个趋势

1. **MCP 成为交易栈标准接口**：Composer 官方 MCP、`jesse-mcp`、OpenBB Workspace MCP 同期出现，Agent 从"内置聊天框"变为"外部可编排工具面"（[OpenBB](https://openbb.co/blog/introducing-workspace-mcp/)）。
2. **统计显著性取代单一收益率**：Freqtrade 新增 p-value 指标，Jesse 3.0 修复 Rule Significance 的前视偏差（[changelog](https://docs.jesse.trade/docs/changelog)）。
3. **Rust/原生内核 + 研究实盘同构**成为性能叙事（NautilusTrader 同一 event model/clock/cache）。
4. **LLM 决策被硬约束包裹**：Cryptohopper AI Bot 用"越不过的限额 + 逐笔批准"（[docs](https://docs.cryptohopper.com/docs/ai-bot)）。
5. **操纵/异常检测前移到交易前置过滤**：已有 wash-trade/pump&dump 实时检测实现，但没人把它做成策略可调用的过滤器——这是我们的机会。

### 3.4 我们领先 / 落后

**领先（5）**
1. DSL 四件套（校验/迁移/哈希/patch）+ 画布同构，业界没有"可视化产出可回测 DSL"的完整闭环。
2. 操纵检测作为策略原语（`manipulation_score_filter`），对标无同类。
3. 八类 Provider 同层治理（LLM/CEX/DEX/新闻/社交/链上/行情/通知），开源框架只覆盖交易所 connector。
4. 五级实盘闸门 + 人工确认 + 默认关闭，比 SaaS 的开关权限细，比开源的"自己负责"安全。
5. 本地优先 + AI 研究的"事实/解释/不确定性/风险"分层输出。

**落后（8）**
1. 资金费/保证金/爆仓模型缺失（LEAN 有 margin-call model，Nautilus 有 margin 账户）。
2. 订单簿级撮合与部分成交缺失（Nautilus 11 种 fill model）。
3. OMS 语义缺失（无 NETTING/HEDGING、无 residual fill、无 position cache）。
4. 参数优化/超参搜索缺失（Freqtrade hyperopt 是标配）。
5. 过拟合诊断缺失（无 lookahead-analysis、recursive-analysis、p-value、deflated Sharpe）。
6. 组合级资金管理缺失（无跨策略净额、无 capital allocation/sleeve）。
7. 数据管道无 point-in-time / 数据质量 / 数据目录（LEAN dataset、Nautilus Parquet catalog）。
8. 可观测性缺失（无统一 tearsheet、无 metrics/tracing/告警）。

---

## 4. 三分法：好的 / 不足 / 要重构

### 4.1 好的（继续投入，不要推倒）

1. DSL 语义与版本化（补上契约缺口后就是护城河）。
2. Command Bus + Execution Ledger + State Lease + Reconciliation 这套执行账本。
3. Provider 适配器框架与健康调度。
4. 策略状态机（纯函数 + 白名单）。
5. BFF 的显式降级契约（`data_source_unavailable` + `reason_codes`）。
6. L10n 基座与设计 token。
7. 操纵雷达 / AI 研究的不确定性表达。
8. 文档与 spec 文化。

### 4.2 不足（补齐即可，不必重构）

1. 鉴权与密钥管理（加 `require_user/require_admin` + 启动 fail-fast）。
2. 准入看板改用真实 gate（复用 `compute_for_strategy`）。
3. DSL union 补 7 个 filter 模型，或把枚举降级为"未实现"。
4. 测试门禁：CI 加 `swift test`、web vitest、覆盖率 30%→45%。
5. 可观测性：结构化日志 + Prometheus 指标 + 关键路径 trace。
6. 参数优化与过拟合诊断（直接复用 Freqtrade hyperopt/lookahead/recursive）。
7. 数据层：Parquet/DuckDB + point-in-time + 数据质量标记。
8. 文档纠偏与仓库卫生（提交/忽略规则/锁文件）。

### 4.3 要重构（动结构，不是打补丁）

| # | 重构 | 目标结构 | 为什么必须动结构 |
|---|---|---|---|
| 1 | **认证授权基线** | `app/security/deps.py` + 全局 `dependencies=[Depends(require_user)]`，白名单 `/health,/docs,/auth/*` | 305 条路由逐个加依赖不可维护 |
| 2 | **风控域收敛** | `services/risk/{state_store,guards,policy}.py`；manual block 落 Redis+DB；policy_hash 每次写入重算 | 现在三套规则/三套词表/进程内状态，补不了多 worker |
| 3 | **回测/撮合分层** | `services/sim/{fees,funding,liquidation,fill}.py`，Freqtrade 只做执行运行时 | 费+滑点合并进 `trading_fee` 无法扩展；资金费/爆仓需要独立模型 |
| 4 | **BFF 收敛** | `services/bff/` 唯一入口，删 `services/overview_aggregator.py`；`execution_bff` 聚合下沉 service | 两个 aggregator 同名字段不同语义，客户端无法稳定契约 |
| 5 | **超大模块拆分** | `live_readiness_service` → `readiness/{gates,probes,serializer}`；`factor_research` → `factors/{primitives,evaluation,backends}`；`backtest_runner` → `backtest/{runner,parser,mtf_replay}` | 1,155/1,151/630 行且成对重复，改一处要读全文件 |
| 6 | **客户端收敛** | 二选一：① 删 web 编辑器与 Tauri 壳，保留 macOS 唯一编辑器；② web 收缩为只读监控/回放，补 auth + 测试。画布只留 `canvas-web` 源码，web 直接引用并把 AltDataNodes 回灌上游 | 三份 UI（macOS/web/canvas）已产生能力分叉，继续并行只会扩大 |
| 7 | **Command Bus 可靠化** | lease 心跳 + `locked_until`；崩溃回 `RETRY_WAITING`；阻塞命令跳过而非空转；执行器线程池 + per-aggregate 锁 | 单线程 + 阻塞 subprocess + 不重试超时，是实盘事故源 |

---

## 5. 路线图

### P0：1–2 周（先止血）

| 任务 | 验收 |
|---|---|
| 全局鉴权 + 高危路由白名单 + `SECRET_KEY` 启动 fail-fast | 匿名调 `/api/trading/*`、`/api/v2/emergency/stop`、`/api/admin/*` 返回 401；缺失密钥拒绝启动 |
| `PULSEDESK_ENCRYPTION_KEY` 必填 + 明文凭据迁移 | 新写入的 provider 凭据为 Fernet 密文；启动日志不再出现 passthrough |
| readiness 三个 stub 换真实查询 | `strategy_id` 不存在时 `can_start_live_small=False`；修正 `test_live_small` 的伪断言 |
| DSL union 补齐 / 或枚举标记未实现 | 用 web 画布生成的 7 类节点发布成功（或前端明确禁用并提示） |
| 修 2 个失败测试 + CI 加 `swift test`/web test | CI 全绿；macOS 测试不再 `fatalError` |
| 清硬编码：`trace.py:106/121` 的 Basic 凭据、`main.py:6` 的 import-time keychain 干预 | 凭据只来自 `settings`；启动无隐式证书改写 |
| 仓库卫生：提交、忽略 WAL、加 ruff/mypy/eslint、锁依赖 | `git status` 干净；`ruff check`/`mypy`/`eslint` 可跑 |

### P1：4–8 周（补能力）

1. `sim/` 撮合层：fee/funding/liquidation/fill 四类模型 + 并发回测隔离（run_id 严格匹配）。
2. 策略体检：hyperopt + lookahead-analysis + recursive-analysis + deflated Sharpe/CPCV（可先用 ml4t skill 的方法论）。
3. 组合风控：跨策略净额、capital allocation、相关性与敞口上限。
4. BFF/风控域收敛 + `services/risk/` 落地。
5. 客户端决策：砍 web 或收缩为只读；画布单一来源。
6. 可观测性：Prometheus 指标（命令队列深度/延迟、回测耗时、provider 健康）+ 关键路径 trace。

### P2：一个季度（建平台）

1. 数据平台：Parquet/DuckDB + point-in-time + 数据质量标记 + 多交易所。
2. MCP 工具面：把回测/因子/风控/操纵检测暴露为 MCP server（对齐 Composer/OpenBB）。
3. 多 Agent 编排：TradingAgents 风格的辩论/风控 agent，但必须走现有闸门。
4. Provider/策略插件 SDK：第三方策略与数据源可注册、可版本化。

---

## 6. 附：证据与复现

- 全量测试：`cd backend && ../.venv/bin/python -m pytest tests/ -q -p no:cacheprovider`
  → `2 failed, 1448 passed, 3 skipped in 154.12s`
  - `test_e2e_command_worker_backtest.py::test_backtest_failure_writes_failed_events`（缺 `FREQTRADE_BACKTEST_STARTED` 事件）
  - `test_research_v2.py::test_create_and_execute_research_run`（503）
- DSL 契约复现：用 `RulePackage`/`RulePackageV3` 解析 `sentiment_filter` 均报 `union_tag_invalid`；`DSLValidator.validate` 返回 `DSL_V3_VALIDATION_FAILED`。
- 鉴权统计：`grep -rl get_current_user app/routers | wc -l` → 2 个文件；AST 统计 305 条路由仅 3 条带 token 校验。
- 客户端规模：`grep -rhoE '@Test[^\n]*func ' macos-app/Tests | wc -l` → 109；`find web -name '*.test.*'` → 0。
- 沙箱限制：`swift test` 因 SwiftPM manifest 需要 `/var/folders` 临时目录被 sandbox 拒绝，未能运行；macOS 结论均为静态取证。

### 引用

- [obra/superpowers](https://github.com/obra/superpowers) · [ml4t/skills](https://github.com/ml4t/skills) · [anthropics/skills](https://github.com/anthropics/skills) · [github/spec-kit](https://github.com/github/spec-kit)
- [NautilusTrader fill models](https://nautilustrader.io/docs/latest/concepts/backtesting/fill-models/) · [NautilusTrader accounts & margin](https://nautilustrader.io/docs/latest/concepts/backtesting/accounts-and-margin/)
- [Freqtrade lookahead analysis](https://www.freqtrade.io/en/stable/lookahead-analysis/) · [Freqtrade recursive analysis](https://www.freqtrade.io/en/stable/recursive-analysis/) · [Freqtrade hyperopt](https://www.freqtrade.io/en/stable/hyperopt/)
- [QuantConnect reality modeling](https://www.quantconnect.com/docs/v2/writing-algorithms/reality-modeling/key-concepts) · [OpenBB Workspace MCP](https://openbb.co/blog/introducing-workspace-mcp/) · [Cryptohopper AI Bot](https://docs.cryptohopper.com/docs/ai-bot) · [Composer MCP](https://pypi.org/project/composer-trade-mcp/)

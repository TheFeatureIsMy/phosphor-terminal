# PulseDesk v2.1 PRD

## 1. 产品定位

PulseDesk 是一个**个人专用 AI 量化交易工作台**，第一阶段只服务产品 owner 本人，不做 SaaS、不做多用户、不做公开信号市场、不做复制交易社区。

PulseDesk 的核心不是“做更多 AI 工具”，而是把现有功能串成一个可执行闭环：

```text
数据 → 特征 → AI/Agent → Signal → 策略 → 回测/dry-run → 风控 → Freqtrade执行 → 订单 → 归因 → 自我进化
```

## 2. 一句话描述

### 面向自己的结果描述

> 每天打开 PulseDesk，先知道今天该做什么、不该做什么、昨天为什么赚了或亏了，以及哪些策略值得继续验证。

### 工程描述

> PulseDesk 以 Signal Center 为中枢，以 Freqtrade 为 Crypto 执行底座，以 TradingAgents 投研流程和 AI-Trader Agent 管理思想为 AI 层，以 SHAP / 历史订单归因为自我成长核心。

## 3. 当前问题

当前 App 已经有以下页面雏形：

- 仪表盘
- 交易记录
- 风险管理
- 策略管理
- 回测中心
- 策略详情
- AI 工作室：RAG、价格预测、因子研究、FreqAI、AI 研究、信号中心
- 市场情绪
- 归因分析
- AI 服务管理
- 系统设置

当前问题不是页面少，而是：

```text
功能多，但没有以 Signal / 策略 / 执行 / 归因形成闭环。
```

## 4. 产品目标

### 4.1 串联现有功能

所有 AI、模型、研究、情绪、因子、策略结果必须汇总到 Signal Center，再由策略工作台决定是否进入回测、dry-run 或小仓位实盘。

```text
AI研究 / RAG / 价格预测 / 因子研究 / FreqAI / 市场情绪 / 操控雷达
  ↓
统一生成 Signal
  ↓
进入 Signal Center
  ↓
生成 StrategyDraft，并编译为 StrategyRuleDSL 后绑定已有策略版本
  ↓
回测 / Freqtrade dry-run
  ↓
RiskEngine
  ↓
Freqtrade 执行
  ↓
订单 / 持仓 / 执行日志
  ↓
SHAP / 归因 / 历史订单学习
  ↓
候选策略 / 参数优化
```

### 4.2 Crypto 执行底座

Crypto 交易执行必须通过：

```text
Freqtrade 官方 Docker 镜像 + Freqtrade REST/WebSocket + CCXT
```

PulseDesk 不直接连接交易所下单。PulseDesk 只管理：

- Freqtrade 容器启动/停止；
- config.json 生成；
- StrategyRuleDSL 生成、校验与 RulePackage 发布；
- backtest；
- dry-run；
- 状态与订单同步；
- 风控门禁；
- 执行日志；
- 归因复盘。

### 4.3 TradingAgents 与 AI-Trader 边界

二者不是并列重复功能，而是上下游关系。

| 层 | 借鉴对象 | 职责 | 输出 |
|---|---|---|---|
| AI 投研委员会 | TradingAgents | 对某个标的进行多 Agent 研究、辩论、风险判断 | ResearchReport、TradingSignal、RiskOpinion、StrategyDraft |
| Agent 平台管理 | AI-Trader 思想 | 管理长期运行的 Agent、权限、信号、表现、降权/禁用 | AgentSignal、AgentPerformance、AgentPermission |
| Signal Center | PulseDesk 自研 | 汇总所有来源的 Signal，统一状态、评分、冲突检测 | NormalizedSignal |
| Strategy Workspace | PulseDesk 自研 | 管理策略生命周期、版本、回测、dry-run、画布编辑 | Strategy / StrategyVersion |
| Freqtrade Adapter | PulseDesk 自研 | 执行 Freqtrade backtest / dry-run / live_small 管理 | FreqtradeRun、Order、Position |

实现上：

```text
TradingAgents Adapter 和 Agent Runtime 是同一个 AI Quant Core 下的两个子模块。
TradingAgents 更偏一次性/按需投研任务。
AI-Trader-style Agent Runtime 更偏长期运行的信号源管理。
二者都不能直接下单，只能发布 Signal。
```

### 4.4 策略能力

策略系统必须支持：

1. 底部长时间横盘策略；
2. 滚动低点 / 近 3 个月低点 / 前低突破策略；
3. 分批建仓策略；
4. 历史盈利/亏损订单挖掘高胜率模式；
5. 策略执行后定期自我成长；
6. 庄家操控 / 插针 / 收割风险识别；
7. 高风险猎币 / 刀口舔血模式，但必须有独立资金池与强风控。

### 4.5 Signal 数据模型是系统中枢契约

PRD 层必须明确 Signal 是什么。Signal 不是 UI 卡片，而是所有模块之间传递交易观点的基础对象。

#### Signal 必须回答 8 个问题

| 问题 | 字段 |
|---|---|
| 谁产生的？ | `source_type`, `source_name`, `agent_id`, `module_id` |
| 看什么标的？ | `market`, `exchange`, `symbol`, `timeframe` |
| 想表达什么方向？ | `direction`, `intent_type` |
| 有多可信？ | `confidence`, `score`, `risk_level` |
| 为什么？ | `reasoning`, `evidence`, `trigger_snapshot` |
| 什么时候有效？ | `created_at`, `expires_at`, `ttl_seconds` |
| 能做什么？ | `permission` |
| 当前处于什么生命周期？ | `status`, `lifecycle_events` |

#### Signal 生命周期

```text
draft
  ↓
pending
  ↓
active
  ↓
used_in_strategy / observed_in_paper / rejected / expired
  ↓
executed / archived
```

#### 最小字段表

| 字段 | 类型 | 必填 | 说明 |
|---|---|---:|---|
| id | UUID | 是 | Signal 唯一 ID |
| source_type | enum | 是 | tradingagents / sentiment / freqai / technical 等 |
| source_name | string | 是 | 具体来源名称 |
| market | enum | 是 | crypto / stock / a_share 等 |
| exchange | string | 否 | Binance / OKX / Bybit 等 |
| symbol | string | 是 | BTC/USDT |
| timeframe | string | 是 | 1m / 15m / 1h / 1d |
| direction | enum | 是 | long / short / hold / risk / block |
| confidence | float | 是 | 0-1 |
| score | float | 是 | 0-5，用于 UI 排序 |
| risk_level | enum | 是 | low / medium / high / extreme |
| trigger_condition | object | 是 | 信号触发规则 |
| current_state | object | 是 | 触发时市场状态快照 |
| target_price | float | 否 | 目标价 |
| stop_loss | float | 否 | 止损 |
| take_profit | float | 否 | 止盈 |
| reasoning | string | 是 | 可读解释 |
| evidence | array | 是 | 证据列表 |
| expires_at | datetime | 是 | 有效期 |
| permission | object | 是 | 是否可回测/模拟/实盘 |
| status | enum | 是 | draft/pending/active/expired/rejected/executed |

## 5. 非目标

第一阶段不做：

- 多用户；
- SaaS；
- 订阅收费；
- 公开信号市场；
- 复制交易社区；
- 自动大仓位实盘；
- 无人工确认的 AI 实盘交易；
- 关闭风控的任何功能；
- AI/Agent 绕过 RiskEngine 下单。

## 6. 目标用户

当前只有一个用户：产品 owner 本人。

用户画像：

- 有产品经理经验；
- 希望利用 AI 和量化方法辅助个人交易；
- 时间有限，需要系统自动分析、自动回测、自动复盘；
- 接受小资金高风险尝试，但希望强风控避免亏光；
- 需要个人工作台而非商业 SaaS。

## 7. 核心页面

### 7.1 AI 总控台

目标：打开 App 第一眼看到当前 AI 如何看市场、有哪些机会、哪些风险被拦截、哪些事项需要人工处理。

#### 首屏一级信息

只放最关键的 3 类信息：

1. **今日 AI 市场判断**：偏多 / 偏空 / 观望、置信度、风险等级。
2. **当前持仓与风险状态**：持仓、盈亏、是否触发风控。
3. **需要人工确认的操作**：待发布策略、待进入 dry-run、待 live_small 确认、风控解除确认。

#### 二级折叠信息

- Agent 信号分布；
- 今日交易机会；
- 风控拦截事件；
- 策略运行状态；
- 权益曲线；
- AI 归因摘要。

### 7.2 AI 投研室

目标：运行 TradingAgents-style 多 Agent 投研流程。

模块：

- 选择标的；
- 选择研究深度：快速 / 标准 / 深度；
- 多 Agent 分析流程；
- 多头观点；
- 空头观点；
- 技术面观点；
- 情绪观点；
- 链上观点；
- 风控观点；
- 最终评级；
- 交易建议；
- 发布为 Signal；
- 创建 StrategyDraft。

### 7.3 Agent 平台

目标：管理 AI-Trader-style Agent。

模块：

- Agent 列表；
- Agent 权限；
- Agent 最新信号；
- Agent 历史表现；
- Agent 胜率；
- Agent 风险等级；
- Agent 状态；
- Agent 权重；
- Agent 降权 / 禁用。

### 7.4 Signal Center

目标：所有模块输出统一 Signal，并在这里筛选、评分、组合、发布到策略。

模块：

- Signal 列表；
- 来源筛选；
- 标的筛选；
- 方向筛选；
- 评分排序；
- 生命周期状态筛选；
- 冲突检测；
- Signal 详情；
- 发布到策略；
- 加入 dry-run 观察；
- 生成 StrategyDraft。

### 7.5 策略工作台

目标：管理策略来源、版本、状态、回测、模拟盘、部署。

策略工作台是**生命周期管理视图**，不是可视化编辑器本身。

模块：

- 策略列表；
- 策略来源；
- 策略状态；
- 策略版本；
- 关联 Signal；
- 回测记录；
- dry-run 记录；
- Freqtrade run 状态；
- 新建策略；
- 从 Signal 创建；
- 从 AI 研究创建；
- 从 RAG 创建；
- 从历史订单学习创建；
- 打开画布编辑。

### 7.6 策略画布

目标：以 React Flow 组合 Signal、条件、风控、仓位和执行。

策略画布是策略工作台中的一个**编辑模式 / 插件**：

```text
策略工作台 → 选择策略 → 编辑 → 画布模式
```

画布不是一级主线，不独立承担策略生命周期。它只负责：

- 可视化组合 Signal；
- 配置条件；
- 配置聚合；
- 配置仓位；
- 配置风险节点；
- 生成 Strategy DSL；
- 交给 Strategy Workspace 管理版本和状态。

### 7.7 回测与模拟盘中心

#### 7.7.1 回测中心

目标：通过 Freqtrade backtesting 验证策略。

模块：

- 数据范围；
- 策略版本；
- Freqtrade backtest 配置；
- 收益曲线；
- 最大回撤；
- Sharpe；
- 胜率；
- 盈亏比；
- 交易列表；
- 失败原因。

#### 7.7.2 模拟盘 / dry-run 监控

Freqtrade dry-run 是实时运行，不等同于回测，必须独立展示。

模块：

- dry-run bot 列表；
- 当前运行策略；
- 当前状态：starting / running / degraded / stopped / error；
- 实时订单；
- 模拟持仓；
- Freqtrade 心跳；
- 最近 RPC/WebSocket 事件；
- 与 PulseDesk 连接状态；
- 失连时降级策略；
- 停止 dry-run；
- 导出 dry-run 报告。

### 7.8 执行记录

目标：记录订单、持仓、TradeIntent、RiskDecision、Freqtrade run。

每条执行记录必须展示：

- 来源 Signal；
- 来源 Agent；
- 来源策略；
- 交易意图；
- 风控决策；
- Freqtrade 执行结果；
- 最终订单或拒绝原因。

### 7.9 风控中心

目标：所有 TradeIntent 的强制门禁。

模块：

- 全局风险；
- 组合风险；
- 相关性风险；
- AI/Agent 风险；
- Signal 冲突；
- 操控风险；
- Freqtrade/API 风险；
- 模拟盘异常；
- 紧急停止。

### 7.10 操控雷达

目标：识别高集中度、插针、洗盘交易、拉盘出货、资金费率收割、流动性陷阱。

#### 数据来源

| 类型 | 必需性 | 示例来源 | 第一阶段策略 |
|---|---:|---|---|
| OHLCV K线 | 必需 | CCXT / Freqtrade data | 本地可先实现 |
| 成交量与异常波动 | 必需 | CCXT / exchange API | 本地可先实现 |
| 资金费率 | 高 | Binance/OKX/Bybit API | 优先接 Binance |
| Open Interest | 高 | 交易所 API / 第三方 | Phase 5 接入 |
| 爆仓数据 | 中 | Coinglass / 交易所/第三方 | 可后置 |
| 订单簿深度 | 中 | 交易所 API | 可后置 |
| 钱包集中度 | 高 | Etherscan / Solscan / Dune / Nansen / Arkham / 自建索引 | Phase 5 选型 |
| 交易所流入流出 | 高 | Glassnode / CryptoQuant / Nansen / Arkham / Dune | Phase 5 选型 |
| 新闻/KOL 文本 | 中 | RSS / X / CryptoPanic / 项目公告 | 先用文本输入 + FinBERT |

第一阶段操控雷达只做 K 线和成交量可计算特征，链上与订单簿数据在 Phase 5 接入。

### 7.11 复盘成长

目标：分析历史订单，生成高胜率模式与候选策略。

模块：

- 每日复盘；
- 每周诊断；
- 盈利订单共性；
- 亏损订单共性；
- SHAP 特征贡献；
- Agent 表现；
- Signal 有效性；
- Candidate Strategy；
- 自动回测结果。

### 7.12 AI 服务管理

目标：管理 LLM Provider、本地模型、金融模型、预测模型、解释模型，并明确不同模块的模型路由。

#### Provider 路由

| 模块 | 默认 Provider | 备用 Provider | 本地模式 | 对已有结果影响 |
|---|---|---|---|---|
| AI 投研室 | OpenAI/DeepSeek | Ollama | 可用但质量降级 | 新 ResearchReport 标记 provider_version，不修改旧结果 |
| RAG 策略知识库 | OpenAI/DeepSeek | Ollama | 可用 | 新 StrategyDraft 标记 embedding/model 版本 |
| FinBERT 情绪 | 本地 FinBERT | LLM fallback | 可用 | 旧 SentimentSignal 不回写 |
| TimesFM / Chronos | 本地模型 | 无 | 模型不可用时禁用 PredictionSignal | 已发布 Signal 过期不重算 |
| SHAP 归因 | 本地 SHAP | 无 | 可用 | 归因报告记录模型版本 |
| Agent 平台 | LLM Router | Ollama fallback | 可用但只允许 signal_only | Agent 权限自动降级 |

切换 Provider 后，已生成的 Signal / ResearchReport / StrategyDraft 不被静默修改，必须记录 `provider_id`、`model_name`、`model_version`、`prompt_version`。

## 8. 成功指标

### 8.1 MVP 指标：Signal Center

| 指标 | 验收标准 |
|---|---|
| Signal 发布入口 | AI 研究、市场情绪、价格预测、因子研究、FreqAI 页面均有「发布为 Signal」按钮 |
| Signal 入库 | 点击后在 `signals` 表创建记录，状态为 `pending` 或 `active` |
| Signal 必填字段 | 每条 Signal 必须展示来源、标的、方向、置信度、有效期 |
| 权限默认安全 | AI/Agent/Prediction/FreqAI Signal 的 `can_live_trade=false` |
| 生命周期可见 | Signal Center 可筛选 pending/active/expired/rejected/executed |
| 操作日志 | 发布、归档、生成策略草稿均写 `execution_logs` 或 `audit_logs` |

### 8.2 MVP 指标：Freqtrade Backtest / Dry-run

| 指标 | 验收标准 |
|---|---|
| 策略规则发布 | 从 StrategyDraft 生成 StrategyRuleDSL，经 Validator 校验后发布 RulePackage，Freqtrade 固定加载 PulseDeskUniversalStrategy.py |
| 回测可运行 | PulseDesk 可触发 Freqtrade backtest 并读取结果 |
| dry-run 可启动 | PulseDesk 可启动 Freqtrade dry-run 容器并显示状态 |
| 订单同步 | dry-run 订单同步到 PulseDesk 执行记录 |
| 失连降级 | Freqtrade 失连时策略状态标记为 degraded，不允许升级 live_small |

### 8.3 中期指标

| 指标 | 验收标准 |
|---|---|
| 订单可追溯 | 每笔订单关联 Signal、Strategy、TradeIntent、RiskDecision |
| 策略生命周期 | 策略支持 draft/validated/backtested/dry_running/paper_passed/live_pending/live_small |
| Agent 表现 | 每个 Agent 有信号数、胜率、平均收益、最大回撤、权限等级 |
| 风控拦截 | 被拒绝交易必须展示 risk_codes 与 reasoning |

### 8.4 长期指标

| 指标 | 验收标准 |
|---|---|
| 自我成长 | 系统能从历史订单生成 StrategyCandidate |
| 候选策略验证 | Candidate 必须 backtest + dry-run 后才能 live_pending |
| 操控雷达 | 每个币种可输出 manipulation_score 和证据 |
| live_small 安全 | live_small 必须人工确认、独立资金池、紧急停止可用 |

## 9. 阶段计划与 MVP 边界

### 9.1 MVP 范围：只做 3 件事

MVP 必须克制，只包含：

```text
1. Signal Center 基础功能
2. 一个策略的 Freqtrade backtest 联通
3. 基础风控拦截 + dry-run 状态同步
```

不进入 MVP：TradingAgents 完整流程、操控雷达完整链上数据、自我成长、live_small。

### 9.2 时间建议

| 阶段 | 时间 | 目标 |
|---|---:|---|
| Phase 1 | 1-2 周 | Signal Center 契约、API、UI、模块发布 Signal |
| Phase 2 | 1-2 周 | StrategyRuleDSL + UniversalStrategy：DSL Schema、Validator、固定模板、Golden Tests |
| Phase 3 | 1-2 周 | Strategy Workspace：生命周期、版本、画布编辑模式 |
| Phase 4 | 2-3 周 | AI 投研室 + Agent 平台基础版 |
| Phase 5 | 2-3 周 | 操控雷达 MVP：K线/成交量/资金费率/OI 特征 |
| Phase 6 | 2-3 周 | Growth Engine：订单特征快照、SHAP、候选策略 |
| Phase 7 | 1-2 周 | live_small 安全门禁与独立资金池 |


---

# v2.2 PRD 补充：工程化安全与可落地边界

## 1. 本地 AI 推理资源管理

### 用户问题

当本地同时运行 Ollama、FinBERT、TimesFM、Chronos、SHAP 时，单卡 GPU 容易出现显存争抢、推理延迟飙升或 OOM。

### 产品要求

新增“AI 推理队列状态”能力：

- AI 服务管理页展示当前模型、队列长度、运行中任务、失败任务；
- AI 投研任务可以排队；
- AI 任务失败时生成 degraded 状态，不影响交易执行和风控；
- 用户可以取消排队任务；
- 系统不得因 AI 任务崩溃导致 Freqtrade 监控中断。

## 2. 策略代码生成边界

### 用户问题

大模型直接生成 `Strategy.py` 可能导致语法错误、API 不兼容、代码注入和 Freqtrade 容器崩溃。

### 产品要求

PulseDesk 只允许生成 `StrategyRuleDSL(JSON)`，不允许 AI 直接生成 Python 策略代码。策略工作台和画布生成的是规则 JSON，Freqtrade 运行固定的 `PulseDeskUniversalStrategy.py` 模板。

用户看到的策略编辑方式：

```text
策略参数表单
策略画布
规则 JSON 预览
回测结果
```

用户不直接编辑 Python。

## 3. Signal 数据规模治理

### 产品要求

Signal Center 必须支持：

- 最近 Signal 快速查询；
- 历史 Signal 归档；
- expired 低分 Signal 自动清理；
- 高价值 Signal 和已执行 Signal 保留；
- 列表页不加载完整 reasoning 大文本。

## 4. MCP Server

### 用户价值

用户可以在外部 AI 客户端里直接问：

```text
最近 BTC 有哪些高置信度信号？
当前 Freqtrade dry-run 有没有持仓？
最近三笔亏损订单的风控原因是什么？
某个币的操控雷达评分是多少？
```

AI 客户端通过 MCP 读取 PulseDesk 数据，不需要用户复制日志。

### 产品限制

MCP v1 只读，不允许通过 MCP 下单、启动 live、关闭风控、修改 API Key。

## 5. Freqtrade 双层风控

### 产品要求

PulseDesk 失联时，Freqtrade 仍必须能独立执行基础止损和仓位限制。因此每个可运行策略都必须有 Freqtrade 原生配置兜底。

UI 必须显示 Freqtrade 连接状态：

```text
healthy
connection_lost
pulse_degraded
freqtrade_native_guard_only
reconciliating
failed
```

当状态为 `freqtrade_native_guard_only` 时：

- 禁止策略升级；
- 禁止提高仓位；
- 禁止启动新的 live_small；
- 显示人工检查提示。


---

## v2.5 收口说明

本文件中若仍存在与 `00_MASTER_ARCHITECTURE_DECISION_v2_5.md` 冲突的旧描述，以 v2.5 Master Architecture Decision 为准。特别是：禁止开放式 Strategy.py 生成；禁止 Canvas 生成 Python；Freqtrade 只加载固定 `PulseDeskUniversalStrategy.py` 并读取 StrategyRuleDSL RulePackage。

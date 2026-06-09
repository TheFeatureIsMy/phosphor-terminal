# PulseDesk v2.5 Master Architecture Decision

> 本文件是 PulseDesk v2.5 的最高优先级架构契约。任何旧文档、旧 Prompt、旧 Phase 中与本文件冲突的描述，均以本文件为准。

## 1. 版本结论

PulseDesk v2.5 不推翻 v2.4 的主体方向，而是做一次正式开发前的架构收口：

```text
Signal First
  → StrategyRuleDSL
  → DSL Validator
  → PulseDeskUniversalStrategy.py 固定模板
  → Freqtrade backtest / dry-run / live_small
  → Execution Ledger
  → Growth Engine
```

## 2. 不可违反的核心决策

### ADR-001：禁止开放式 Strategy.py 生成

系统内不得存在以下路径：

```text
AI / Canvas / StrategyDraft → 生成任意 Freqtrade Strategy.py
```

唯一允许路径：

```text
AI / Canvas / Manual Editor
  → StrategyDraft
  → StrategyRuleDSL(JSON)
  → DSL Validator
  → strategy_rules.json package
  → PulseDeskUniversalStrategy.py 固定模板读取规则
```

说明：

- `PulseDeskUniversalStrategy.py` 是固定、审计过的模板；
- AI、画布、用户配置只能生成 DSL，不生成 Python；
- Freqtrade 侧只加载固定模板，不加载 AI 生成代码；
- 任何文档中出现“Strategy.py 生成器”“从 StrategyDraft 生成 Strategy.py”的旧描述均废弃。

### ADR-002：Canvas 只是 StrategyVersion 的可视化编辑模式

Canvas 不是一级执行入口，不是 Python 编排器，不是自由 Agent 工作流。

第一阶段 Canvas 仅允许编辑以下 DSL 节点：

```text
SignalInputNode
IndicatorConditionNode
FilterNode
PositionSizingNode
RiskPolicyNode
ExecutionOutputNode
```

Canvas 输出必须经过 DSL Validator，验证失败不得进入 backtest / dry-run。

### ADR-003：Signal Center 是信号事实中心，不创建交易意图

Signal Center 只负责：

```text
Signal 创建
Signal 归一化
Signal 证据与 ProviderTrace
Signal 生命周期
Signal Repository 查询
```

Signal Center 禁止：

```text
创建 TradeIntent
创建 Command
直接调用 Freqtrade
直接写 strategy_versions
```

### ADR-004：Risk Engine 与 Freqtrade 采用三层风控

Freqtrade 的真实运行机制决定了 PulseDesk 不应假设“每笔订单前都能同步插入外部审批”。v2.5 采用三层风控：

```text
第一层：策略部署前风控
  StrategyRuleDSL / RiskPolicy / CapitalPool / Pairlist / ProviderHealth / ManipulationFilter

第二层：Freqtrade 内部硬风控
  stoploss / max_open_trades / stake_amount / tradable_balance_ratio / cooldown / pair lock

第三层：运行中监控风控
  Heartbeat / Order Sync / Reconciliation / EmergencyStop / ManualReview
```

`TradeIntent` 在 v2.5 中分为两类：

```text
PlannedTradeIntent
  PulseDesk 外部 AI / 手动 / 策略规划产生的交易意图。

FreqtradeExecutionIntent
  Freqtrade 实际运行事件抽象，不要求每笔订单前都有 PulseDesk 同步审批。
```

第一阶段不强制把 Freqtrade 的每个 entry signal 都转换为外部 `TradeIntent` 审批。

### ADR-005：所有 Freqtrade 写操作必须经 Command Bus

允许的写操作包括：

```text
DeployRulesCommand
StartBacktestCommand
StartDryRunCommand
StopDryRunCommand
PauseStrategyCommand
RequestLiveSmallCommand
EmergencyStopCommand
StartReconciliationCommand
```

禁止任何 UI、AI、Signal Center、Growth Engine 绕过 Command Bus 直接操作 Freqtrade。

### ADR-006：Execution Ledger 是执行事实源

所有 Freqtrade / PulseDesk / Reconciliation 事件必须 append 到 `execution_ledger_events`。

不可做：

```text
update 历史执行事件
delete 历史执行事件
通过订单表反推事实源
用 UI 状态覆盖 Freqtrade 真理源
```

允许做：

```text
append 新事件
materialize 到 exchange_orders / exchange_trades / positions
通过 reconciliation event 修正本地视图
```

### ADR-007：数据库表结构优先于 TypeScript 示例

v2.5 以后，数据库以 `10_Database_ERD_v2_5.md` 的 v2.5 修订段落和新增契约文档为准。

旧 `04_Data_Models_API_DB.md` 中涉及 `strategy_file_path`、开放式 Strategy.py、简单 `orders` 表的内容，仅作为历史参考，不可直接实现。

## 3. v2.5 必读文档顺序

开发 AI 必须按以下顺序读取：

```text
1. README.md
2. 00_MASTER_ARCHITECTURE_DECISION_v2_5.md
3. 00_Revision_Changelog_v2_5.md
4. 13_StrategyRuleDSL_Semantics_v2_5.md
5. 14_Command_Bus_Worker_Contract_v2_5.md
6. 15_Execution_Ledger_Contract_v2_5.md
7. 16_Freqtrade_Runtime_Contract_v2_5.md
8. 17_Phase_Plan_v2_5.md
9. 10_Database_ERD_v2_5.md
10. 11_Module_Boundaries_v2_4.md
11. 12_Exchange_API_Strategy_v2_4.md
```

## 4. 开发 AI 禁止事项

```text
禁止生成开放式 Strategy.py。
禁止让 Canvas 生成 Python。
禁止让 AI 直接创建 Command。
禁止让 Signal Center 创建 TradeIntent。
禁止绕过 Command Bus 操作 Freqtrade。
禁止绕过 Repository 直接查冷热分层 Signal。
禁止在 Freqtrade 热路径反复读取 JSON 规则文件。
禁止在 reconciliating 状态下部署策略或发送新交易意图。
禁止 live_small 自动确认。
```

## 5. 一句话架构边界

PulseDesk 负责信号、策略 DSL、风控、命令、执行账本、复盘和增长；Freqtrade 负责交易执行；交易所 API 第一阶段以只读和 Freqtrade 间接执行为主。

# PulseDesk v2.5 Revision Changelog

## 1. 修订目标

v2.5 是正式进入深度代码实现前的架构收口版，重点解决：

```text
1. 旧 Strategy.py 生成路径残留。
2. PostgreSQL 分区表主键 / FK 设计问题。
3. orders / trades / positions / attribution 表缺失。
4. Risk Engine 与 Freqtrade 真实运行边界不清。
5. Command Bus 缺少 worker 级可靠消费字段。
6. Execution Ledger 缺少幂等与链路追踪字段。
7. StrategyRuleDSL 缺少可执行语义规范。
8. Phase 计划顺序需要先固化 DSL 与 runtime contract。
```

## 2. 新增文件

```text
00_MASTER_ARCHITECTURE_DECISION_v2_5.md
13_StrategyRuleDSL_Semantics_v2_5.md
14_Command_Bus_Worker_Contract_v2_5.md
15_Execution_Ledger_Contract_v2_5.md
16_Freqtrade_Runtime_Contract_v2_5.md
17_Phase_Plan_v2_5.md
```

## 3. 更新文件

```text
README.md
01_PRD_PulseDesk_v2.md
02_Technical_Architecture.md
04_Data_Models_API_DB.md
06_AI_Development_Prompts.md
10_Database_ERD_v2_5.md
11_Module_Boundaries_v2_4.md
phases/Phase_02_Freqtrade_Adapter.md
```

## 4. 关键决策变更

### 4.1 Strategy.py 生成路径废弃

废弃：

```text
StrategyDraft → Strategy.py → Freqtrade
```

保留：

```text
StrategyDraft → StrategyRuleDSL → Validator → Rules JSON → PulseDeskUniversalStrategy.py
```

### 4.2 Risk Engine 重定义

废弃“每笔 Freqtrade 订单前都必须同步外部 TradeIntent 审批”的隐含假设。

改为：

```text
部署前风控 + Freqtrade 内部硬风控 + 运行中监控 / EmergencyStop
```

### 4.3 数据库结构增强

新增或明确以下表：

```text
signal_identity
provider_traces
risk_policies
risk_policy_versions
strategy_risk_policy_bindings
execution_orders
execution_trades
execution_positions
order_fills
order_attributions
portfolio_snapshots
growth_reports
strategy_candidates
```

### 4.4 Command Bus 增强

新增：

```text
locked_by
locked_at
retry_count
max_retries
next_retry_at
priority
timeout_sec
cancel_requested
correlation_id
causation_id
```

### 4.5 Execution Ledger 增强

新增：

```text
event_hash
correlation_id
causation_id
command_id
trade_intent_id
risk_decision_id
sequence_no
schema_version
raw_payload
normalized_payload
```

## 5. 开发影响

v2.5 以后开发顺序调整为：

```text
Phase 00 Architecture Contract Freeze
Phase 01 Data Foundation + Signal Center
Phase 02 StrategyRuleDSL + UniversalStrategy
Phase 03 Freqtrade Backtest / Dry-run Adapter
Phase 04 Strategy Workspace
Phase 05 Canvas WebView Editor
Phase 06 AI Research / Agent
Phase 07 Manipulation Radar
Phase 08 Growth Engine
Phase 09 Live Small Safety
```

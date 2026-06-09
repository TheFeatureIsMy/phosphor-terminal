# PulseDesk v2.5 文档包

本包是面向开发 AI 的工程化 Markdown 文档。v2.5 是正式进入深度代码实现前的架构收口版。

> 最高优先级规则：任何旧文档、旧 Prompt、旧 Phase 中与 `00_MASTER_ARCHITECTURE_DECISION_v2_5.md` 冲突的描述，均以 v2.5 Master Architecture Decision 为准。

## 1. 开发 AI 必读顺序

必须按以下顺序阅读，不允许跳过：

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
12. 01_PRD_PulseDesk_v2.md
13. 02_Technical_Architecture.md
14. 03_App_IA_and_UI_Layouts.md
15. 04_Data_Models_API_DB.md
16. 05_Security_Risk_Guardrails.md
17. 06_AI_Development_Prompts.md
18. phases/
```

## 2. v2.5 最终架构主线

```text
Signal Center
  ↓
StrategyDraft / Manual Editor / Canvas
  ↓
StrategyRuleDSL(JSON)
  ↓
DSL Validator
  ↓
RulePackage + Manifest
  ↓
PulseDeskUniversalStrategy.py 固定模板
  ↓
Freqtrade backtest / dry-run / live_small
  ↓
Execution Ledger
  ↓
Order Materialization / Growth Engine / Review
```

## 3. 最小 MVP 只包含四件事

```text
1. Signal Center + SignalRepository。
2. StrategyRuleDSL + DSL Validator + Golden Tests。
3. 固定 PulseDeskUniversalStrategy.py 读取 RulePackage 并跑 backtest。
4. Freqtrade dry-run 状态同步 + Command Bus + Execution Ledger。
```

注意：MVP 不包含复杂 Canvas、不包含 live_small 自动化、不包含高风险猎币完整链上数据、不包含 Growth Engine 深度 SHAP。

## 4. 强制原则

```text
AI/Agent 不能直接下单。
AI/Canvas/StrategyDraft 不能生成开放式 Strategy.py。
PulseDesk 不能绕过 Freqtrade 直接交易所下单。
所有 Freqtrade 写操作必须经过 Command Bus。
Signal Center 不能创建 TradeIntent。
Strategy Center 只能输出 StrategyRuleDSL / StrategyVersion。
Risk Engine 采用部署前门禁 + Freqtrade 硬风控 + 运行中监控。
Execution Ledger 是不可变执行事实源。
reconciliating 状态阻塞新策略部署和新交易意图。
live_small 必须人工确认。
```

## 5. 废弃旧描述

以下旧描述一律废弃，不得实现：

```text
Strategy.py 生成器
从 StrategyDraft 生成 Strategy.py
AI 生成 Freqtrade Strategy.py
Canvas 生成 Python
strategy_file_path 作为策略生成产物
每笔 Freqtrade 订单前都强制外部 TradeIntent 同步审批
```

正确实现是：

```text
StrategyDraft → StrategyRuleDSL → Validator → RulePackage → PulseDeskUniversalStrategy.py
```

## 6. v2.5 Phase 顺序

```text
Phase 00 Architecture Contract Freeze
  ↓
Phase 01 Data Foundation + Signal Center
  ↓
Phase 02 StrategyRuleDSL + UniversalStrategy
  ↓
Phase 03 Freqtrade Backtest / Dry-run Adapter
  ↓
Phase 04 Strategy Workspace
  ↓
Phase 05 Canvas WebView Editor
  ↓
Phase 06 AI Research / Agent
  ↓
Phase 07 Manipulation Radar
  ↓
Phase 08 Growth Engine
  ↓
Phase 09 Live Small Safety
```

## 7. v2.5 新增核心文件

```text
00_MASTER_ARCHITECTURE_DECISION_v2_5.md
00_Revision_Changelog_v2_5.md
13_StrategyRuleDSL_Semantics_v2_5.md
14_Command_Bus_Worker_Contract_v2_5.md
15_Execution_Ledger_Contract_v2_5.md
16_Freqtrade_Runtime_Contract_v2_5.md
17_Phase_Plan_v2_5.md
```

## 8. 历史文件说明

历史文件仍保留，便于追溯设计演进：

```text
00_Revision_Changelog_v2_3.md
00_Revision_Changelog_v2_3_2.md
00_Revision_Changelog_v2_4.md
07_Engineering_Optimizations_v2_2.md
08_Cloud_Hybrid_AI_Routing_v2_3.md
09_Code_Implementation_Hardening_v2_3_2.md
```

但实现优先级低于 v2.5 Master Architecture Decision。

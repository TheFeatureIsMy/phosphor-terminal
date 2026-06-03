# PulseDesk v2.5 Phase Plan

## Phase 00：Architecture Contract Freeze

目标：让开发 AI 不再被旧文档误导。

交付：

```text
README v2.5 更新
Master Architecture Decision
DSL Semantics
Command Bus Contract
Execution Ledger Contract
Freqtrade Runtime Contract
Database ERD 修正
```

验收：

```text
全文搜索 Strategy.py 生成器，不得存在有效实现要求。
全文搜索 strategy_file_path，仅允许作为废弃字段说明。
开发 Prompt 明确禁止开放式 Python 策略生成。
```

## Phase 01：Data Foundation + Signal Center

交付：

```text
signal_identity
signals partitioned table
signal_payloads
signal_evidence
provider_traces
signal_lifecycle_events
SignalRepository
```

验收：

```text
Signal 列表不扫描大文本。
被引用 Signal 可归档但可通过 Repository 还原。
ProviderTrace 可绑定 Signal / ResearchReport / StrategyDraft。
```

## Phase 02：StrategyRuleDSL + UniversalStrategy

交付：

```text
DSL JSON Schema
Pydantic Validator
DSL Interpreter
Golden Tests
PulseDeskUniversalStrategy.py fixed template
RulePackage manifest
Last-known-good cache
```

验收：

```text
非法 operator 被拒绝。
missing data 进入 safe hold。
不生成开放式 Strategy.py。
UniversalStrategy 热路径不重复读 JSON。
```

## Phase 03：Freqtrade Backtest / Dry-run Adapter

交付：

```text
Command Bus worker
DeployRulesCommand
StartBacktestCommand
StartDryRunCommand
Freqtrade container lifecycle
ExecutionLedger ingestion
basic order sync
```

验收：

```text
命令幂等。
worker 崩溃后可恢复。
每次 backtest / dry-run 都有 StrategyRun + FreqtradeRun + Ledger events。
```

## Phase 04：Strategy Workspace

交付：

```text
StrategyDraft
StrategyVersion
StrategyRuleDSL editor
Validation result panel
Backtest result panel
Dry-run status panel
```

验收：

```text
StrategyDraft 不可直接执行。
StrategyVersion validated 后才可 backtest。
RiskPolicy 缺失不可 live_small。
```

## Phase 05：Canvas WebView Editor

交付：

```text
React Flow WebView
6 类基础节点
DSL import/export
实时校验
错误定位到节点
```

验收：

```text
Canvas 只编辑 DSL。
Canvas 不生成 Python。
Canvas 不直接创建 Command。
```

## Phase 06：AI Research / Agent

交付：

```text
ResearchReport
SignalCandidate
StrategyDraft structured output
ProviderTrace
Privacy redaction
Cost guardrail
```

验收：

```text
AI 输出不能直接交易。
AI 输出必须进入 draft + validate。
云端调用记录 provider/model/cost/latency/hash。
```

## Phase 07：Manipulation Radar

交付：

```text
funding / OI / orderbook / volume anomaly features
manipulation_score
manipulation filters in DSL
missing data policy
```

验收：

```text
live_small 中缺失 manipulation_score 默认拒绝 entry。
高风险猎币必须独立资金池。
```

## Phase 08：Growth Engine

交付：

```text
feature_snapshots
trade_intent_signal_snapshots
order_attributions
growth_reports
strategy_candidates
```

验收：

```text
每笔订单可追溯到 Signal / FeatureSnapshot / RiskDecision / Ledger event。
Growth Engine 不直接扫描冷归档 Signal。
```

## Phase 09：Live Small Safety

交付：

```text
RequestLiveSmallCommand
human confirmation
capital pool limit
EmergencyStop
Reconciliation blocking
manual review
```

验收：

```text
live_small 必须人工确认。
失连恢复必须先 reconciliating。
reconciliating 阻塞新部署和新交易。
```

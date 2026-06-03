# PulseDesk v2.4 修订日志 — 底层架构、数据库与模块边界审计版

> 本版基于 v2.3.2，重点不是新增功能，而是把 **数据库结构、模块边界、执行账本、StrategyRuleDSL 契约、Command Bus、Exchange API 接入策略** 固化为开发前的底层工程契约。

## 1. 本版修订目标

上一版 v2.3.2 已解决：

- 云端/本地混合 AI 路由；
- UniversalStrategy 固定模板 + StrategyRuleDSL；
- Signal 冷热查询；
- Freqtrade reconciliating 原子对账；
- Signal 证据链完整性。

但在真正进入工程代码实现前，还需要进一步明确：

1. Signal 不能变成万能大表；
2. StrategyRuleDSL 必须成为 Freqtrade 与 PulseDesk 之间唯一执行契约；
3. Strategy / StrategyVersion / StrategyRun / FreqtradeRun 必须分层；
4. TradeIntent 必须保存触发快照，不能只保存弱引用；
5. FeatureSnapshot 必须成为 Growth Engine 的基础事实；
6. Execution Ledger 必须独立为不可变执行账本；
7. 所有 Freqtrade 写操作必须通过 Command Bus；
8. 交易所 API 必须定义主路径与补充路径。

## 2. 本版新增文档

- `10_Database_ERD_v2_4.md`：数据库 ERD、核心表结构、分区、冷热归档、索引、查询路径。
- `11_Module_Boundaries_v2_4.md`：模块边界、禁止跨模块直接写表、事件解耦、Command Bus。
- `12_Exchange_API_Strategy_v2_4.md`：交易所 API 接入策略、Freqtrade/CCXT 主路径、交易所直连数据补充、API Key 权限。

## 3. 关键架构变更

### 3.1 Signal Center 语义收敛

禁止把所有中间产物都写成 Signal。系统对象分层为：

```text
RawData     原始数据
Feature     指标/特征
Insight     解释性发现
Signal      可进入策略判断的交易信号
TradeIntent 可进入风控的交易意图
```

Signal Center 只管理 Signal，不管理所有 RawData / Feature。

### 3.2 Signal 表拆分

`signals` 只做轻量索引表，大文本和 JSON 拆出：

```text
signals
signal_payloads
signal_evidence
signal_provider_traces
signal_lifecycle_events
signal_snapshots
```

### 3.3 StrategyRuleDSL 一等公民化

所有策略来源都必须编译为 StrategyRuleDSL：

```text
AI 生成策略 / 画布策略 / 手动策略 / RAG 策略 / 历史订单挖掘策略
  ↓
StrategyRuleDSL(JSON)
  ↓
DSL Validator
  ↓
PulseDeskUniversalStrategy.py
  ↓
Freqtrade
```

禁止任何模块直接生成开放式 `Strategy.py`。

### 3.4 Execution Ledger 独立

新增不可变执行账本：

```text
execution_ledger_events
```

用于保存 Freqtrade WebSocket / REST polling / 本地风控 / 对账事件，供断线恢复和 Growth Engine 重建历史。

### 3.5 Command Bus 引入

所有对 Freqtrade 的写操作必须通过命令对象：

```text
DeployRulesCommand
StartBacktestCommand
StartDryRunCommand
StopDryRunCommand
RequestLiveSmallCommand
EmergencyStopCommand
```

禁止 UI / AI / Canvas 直接调用 Docker 或 Freqtrade 写操作。

## 4. 实施影响

- Phase 01：必须按 v2.4 拆分 Signal 表，增加 SignalRepository 和 Data Federation Layer。
- Phase 02：必须落地 Command Bus、StrategyRun、FreqtradeRun、UniversalStrategy 只读 DSL 缓存。
- Phase 03：策略工作台管理 Strategy / StrategyVersion / DSL 生命周期，画布只是编辑器。
- Phase 06：Growth Engine 必须依赖 FeatureSnapshot、TradeIntentSnapshot、ExecutionLedger。
- Phase 07：Live Small 必须以 Freqtrade / Exchange 为真理源，PulseDesk 只做上层风控和审计。

## 5. v2.4 开发原则

```text
1. 数据库结构优先于页面开发。
2. StrategyRuleDSL 优先于 AI 策略生成。
3. Execution Ledger 优先于漂亮订单表。
4. Command Bus 优先于直接调用 Freqtrade。
5. FeatureSnapshot 优先于 Growth Engine。
6. 模块边界优先于快速堆功能。
```

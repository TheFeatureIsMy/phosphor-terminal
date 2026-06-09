# Phase 03 — Strategy Workspace 与 Canvas 编辑模式

## 目标

把策略工作台定义为策略生命周期管理视图，把 React Flow 画布降级为策略详情页的编辑模式。

## 周期

建议 1-2 周。

## 本阶段不做

- 不做复杂 AI 自动生成完整策略；
- 不直接从画布启动 Freqtrade；
- 不做 live_small。

## 策略生命周期

```text
draft
  ↓ validate
validated
  ↓ backtest
backtested
  ↓ start dry-run
dry_running
  ↓ pass
paper_passed
  ↓ human approve
live_pending
```

## 页面结构

```text
策略工作台
├── 策略列表
├── 新建策略
├── 从 Signal 创建
└── 策略详情
    ├── Overview
    ├── Signals
    ├── Rules
    ├── Canvas
    ├── Backtest
    ├── Dry-run
    ├── Risk
    ├── Execution
    └── Growth
```

## 任务拆分

### T1. Strategy / StrategyVersion 模型

- Strategy 保存业务对象；
- StrategyVersion 保存每一次修改；
- Canvas 只修改当前 draft version；
- backtest 绑定具体 version；
- dry-run 绑定具体 version。

### T2. 从 Signal 创建 StrategyDraft

流程：

```text
Signal Center → 选择 Signal → 生成 StrategyDraft → 策略工作台可见
```

### T3. Canvas Tab

节点：

- SignalNode；
- ConditionNode；
- AggregateNode；
- RiskNode；
- PositionNode；
- ExecutionNode。

画布输出：

```text
Strategy DSL JSON
```

不允许：

- 画布直接调用 Freqtrade；
- 画布直接下单；
- 画布绕过 StrategyVersion。

### T4. 策略详情操作

- validate；
- run backtest；
- start dry-run；
- pause；
- archive；
- duplicate version。

## 验收标准

- 策略可从 Signal 创建；
- 策略详情可打开 Canvas Tab；
- Canvas 修改后保存为新 StrategyVersion；
- backtest 必须绑定 version；
- dry-run 必须在 backtested 后才能启动。

---

# v2.3.1 同步修订：Canvas / Strategy Workspace 与 Cloud AI 的关系

## 变更原因

Cloud LLM 可以生成更高质量的策略草稿，但策略工作台和画布必须保持确定性。画布不是代码编辑器，而是 StrategyRuleDSL 的可视化编辑器。

## 页面职责调整

策略工作台负责：

- StrategyDraft 生命周期；
- StrategyRuleDSL 版本管理；
- 回测记录；
- dry-run 状态；
- 风控状态；
- 进入画布编辑模式。

画布负责：

- 可视化编辑 Signal / 条件 / 风控 / 仓位规则；
- 输出 StrategyRuleDSL；
- 显示 DSL validation errors；
- 不直接启动 Freqtrade；
- 不直接生成 Python。

## 云端策略草稿流程

```text
AI Research / RAG / Signal Center
  ↓
Cloud LLM 生成 StrategyDraft
  ↓
Structured Output Validator
  ↓
StrategyRuleDSL Validator
  ↓
进入策略工作台 draft
  ↓
用户打开 Canvas 复核
  ↓
Backtest
```

## 新增 UI 状态

策略详情页增加：

- Draft Source：cloud_ai / local_ai / manual / canvas / signal；
- Provider：deepseek / openai / anthropic / ollama；
- Structured Validation：passed / failed；
- DSL Validation：passed / failed；
- Python Generation：禁止，固定显示 `UniversalStrategy Template`；
- Last Backtest；
- Current Dry-run Run。

## 验收标准补充

- 从 AI 生成的策略只能进入 draft；
- 画布保存后输出 DSL JSON；
- 策略详情能看到 provider_trace；
- 画布没有“编辑 Python”入口；
- 策略进入 backtest 前必须同时通过 structured output validation 和 DSL validation。

## 禁止事项

- 禁止把画布当 Python 编排器；
- 禁止在画布节点里写任意 Python 表达式；
- 禁止 AI 生成策略直接进入 dry-run；
- 禁止策略未回测直接显示为可部署。

## v2.4 补充：StrategyVersion 与 Canvas 编辑器定位

### 必做任务

1. 策略工作台必须围绕以下实体：

```text
Strategy
StrategyVersion
StrategyRuleDSL
StrategyRun
```

2. 画布不再是一级执行入口，只是 StrategyVersion 的一种编辑模式。

3. 画布保存结果必须输出 StrategyRuleDSL。

4. StrategyRuleDSL 必须支持版本号、hash、diff、validation_result。

5. 策略详情页必须展示：

```text
策略身份
版本列表
当前 DSL
DSL 校验结果
回测记录
dry-run 记录
风险状态
```

### 验收标准

```text
任何画布修改都会生成新的 StrategyVersion draft。
未通过 DSL Validator 的版本不能 backtest。
画布不会生成 Strategy.py。
画布不会直接启动 Freqtrade。
```

---

## v2.5 Phase 顺序说明

本 Phase 文件保留历史开发细节，但实现顺序以 `17_Phase_Plan_v2_5.md` 为准。若本文件存在开放式 Strategy.py、AI 直接执行、Signal 直接创建 TradeIntent 等旧描述，均以 v2.5 Master Architecture Decision 为准。

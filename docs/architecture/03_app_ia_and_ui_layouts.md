# PulseDesk v2.1 App 信息架构与页面布局

## 1. 新导航结构

```text
AI Quant
- AI 总控台
- AI 投研室
- Agent 平台
- 信号中心

Strategy
- 策略工作台
- 回测 / 模拟盘

Execution
- 执行记录
- 持仓订单
- 风控中心

Research & Growth
- 市场情绪
- 量化研究
- 操控雷达
- 复盘成长

System
- AI 服务
- 系统设置
```

> 策略画布不作为一级导航。它是策略工作台中某个策略的“画布编辑模式”。

## 2. AI 总控台布局

目标：打开 App 第一眼只回答三件事：

1. 今天市场该不该动；
2. 当前持仓有没有风险；
3. 有没有需要人工确认的操作。

### 2.1 首屏线框图

```text
┌────────────────────────────────────────────────────────────────────┐
│ TopStatus: 运行状态 | 模式 dry-run | 策略数 | 持仓数 | 风控灯 | 搜索 │
├────────────────────────────────────────────────────────────────────┤
│ AI 今日判断                                                        │
│ ┌────────────────────────────────────────────────────────────────┐ │
│ │ 市场状态: 震荡偏多   建议: 观望/小仓位   置信度: 72%  风险: 中 │ │
│ │ 主要原因: 技术面偏多；相关性过高；巨鲸流入上升                 │ │
│ └────────────────────────────────────────────────────────────────┘ │
│                                                                    │
│ ┌──────────── 当前持仓 ────────────┐ ┌──── 需要人工确认 ────────┐ │
│ │ BTC/USDT +1250 AI: 持有 风控:OK │ │ 1. 策略A 进入 dry-run?   │ │
│ │ ETH/USDT -180  AI: 减仓 风控:警 │ │ 2. Signal#12 生成策略?   │ │
│ │ SOL/USDT +340  AI: 止盈 风控:OK │ │ 3. 风控解除确认?          │ │
│ └─────────────────────────────────┘ └────────────────────────────┘ │
│                                                                    │
│ 折叠区: Agent 信号分布 | 交易机会 | 风控拦截 | 策略状态 | 权益曲线 │
└────────────────────────────────────────────────────────────────────┘
```

### 2.2 卡片优先级

| 优先级 | 卡片 | 是否首屏 |
|---|---|---:|
| P0 | AI 今日判断 | 是 |
| P0 | 当前持仓与风险 | 是 |
| P0 | 需要人工确认 | 是 |
| P1 | Agent 信号分布 | 折叠 |
| P1 | 风控拦截 | 折叠 |
| P2 | 权益曲线 | 折叠 |
| P2 | AI 归因摘要 | 折叠 |

## 3. Signal Center 布局

```text
┌────────────────────────────────────────────────────────────────────┐
│ 信号中心                                                           │
│ 统计: Signal总数 | Active | Pending | Expired | 可生成策略 | 冲突数 │
├────────────────────────────────────────────────────────────────────┤
│ Filter: 来源 ▾ | 标的 ▾ | 方向 ▾ | 状态 ▾ | 风险 ▾ | 搜索       │
├────────────────────────────────────────────────────────────────────┤
│ ┌ Signal Card ───────────────────────────────────────────────────┐ │
│ │ BTC/USDT LONG  score 3.8  confidence 0.74  active  expires 2h │ │
│ │ 来源: tradingagents / btc_research_committee                  │ │
│ │ 触发: 技术面偏多 + 情绪中性 + 无操控高风险                    │ │
│ │ 权限: backtest✓ paper✓ live× confirm✓                         │ │
│ │ 操作: 查看详情 | 生成策略草稿 | 加入 dry-run 观察 | 归档       │ │
│ └────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

### Signal 详情抽屉

```text
右侧抽屉:
- 基本信息
- trigger_condition
- current_state
- evidence
- permission
- lifecycle_events
- provider_trace
- 冲突 Signal
- 关联 Strategy / TradeIntent / Order
```

## 4. 策略工作台布局

策略工作台是策略生命周期管理页面。

```text
┌────────────────────────────────────────────────────────────────────┐
│ 策略工作台                              [新建策略] [从Signal创建] │
│ 统计: 总计 | draft | backtested | dry_running | live_pending       │
├────────────────────────────────────────────────────────────────────┤
│ 策略卡片                                                           │
│ ┌──────────────────────────────┐ ┌──────────────────────────────┐ │
│ │ RSI 均值回归                 │ │ Rolling Low Ladder           │ │
│ │ 来源: canvas                 │ │ 来源: signal_center          │ │
│ │ 状态: dry_running            │ │ 状态: backtested             │ │
│ │ Sharpe: 1.2  MDD: 8%         │ │ Sharpe: 1.5  MDD: 12%        │ │
│ │ 操作: 详情 | 回测 | dry-run   │ │ 操作: 详情 | 打开画布 | 暂停  │ │
│ └──────────────────────────────┘ └──────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

### 策略详情页 Tab

```text
Overview | Signals | Rules | Canvas | Backtest | Dry-run | Risk | Execution | Growth
```

画布位于 `Canvas` tab，不能绕过策略版本管理。

## 5. 回测 / 模拟盘页面布局

### 5.1 回测

```text
策略版本 | 时间范围 | 交易所 | 手续费 | 滑点 | 启动回测
--------------------------------------------------
收益曲线 | 回撤曲线 | 指标卡 | 交易列表 | 失败日志
```

### 5.2 dry-run 监控

```text
┌────────────────────────────────────────────────────────────────────┐
│ 模拟盘 / Freqtrade dry-run                                         │
│ Bot: btc-dryrun-001  状态: running  心跳: 8s前  连接: OK           │
├────────────────────────────────────────────────────────────────────┤
│ 当前策略 | 模拟持仓 | 近24h订单 | RPC事件 | 日志 | 停止Bot        │
├────────────────────────────────────────────────────────────────────┤
│ 实时订单列表 + Freqtrade WebSocket 事件流                          │
└────────────────────────────────────────────────────────────────────┘
```

## 6. AI 服务管理布局

```text
┌────────────────────────────────────────────────────────────────────┐
│ AI 服务管理                                                        │
│ Provider: Ollama(local) | OpenAI | DeepSeek | FinBERT | TimesFM     │
├────────────────────────────────────────────────────────────────────┤
│ 路由矩阵                                                           │
│ 任务类型        Primary        Fallback        延迟上限      策略    │
│ research_deep   OpenAI         DeepSeek/Ollama  60000ms      fallback│
│ sentiment       FinBERT        DeepSeek         5000ms       fallback│
│ prediction      TimesFM        Chronos          10000ms      disable │
├────────────────────────────────────────────────────────────────────┤
│ 健康状态 | 延迟 | 成本 | 最近错误 | 测试连接                         │
└────────────────────────────────────────────────────────────────────┘
```

## 7. 操控雷达布局

```text
标的池 | 数据源状态 | 评分周期 | 运行扫描
--------------------------------------------------
币种列表: manipulation_score | stop_hunt | concentration | funding_squeeze
--------------------------------------------------
详情:
- K线异常证据
- 成交量异常证据
- funding/OI 证据
- 链上/钱包证据
- 新闻/KOL 证据
- 风控建议: allow/reduce/paper_only/reject
```

## 8. 复盘成长布局

```text
周期: 日 / 周 / 月
--------------------------------------------------
盈利订单共性 | 亏损订单共性 | SHAP 特征贡献 | Signal 有效性
--------------------------------------------------
候选策略:
- hypothesis
- 来源
- 回测状态
- dry-run状态
- 操作: 查看 / 回测 / 加入模拟盘
```

---

# v2.2 UI 补充

## 1. AI 服务管理页新增：推理队列面板

```text
AI 服务管理
┌────────────────────────────────────────────┐
│ 模型运行状态                                │
│ Ollama: idle / loaded / running / OOM       │
│ FinBERT: ready                              │
│ TimesFM: unloaded                           │
│ Chronos: unloaded                           │
│ SHAP: idle                                  │
├────────────────────────────────────────────┤
│ 推理队列                                    │
│ [running] TradingAgents BTC research  02:31 │
│ [queued ] SHAP explain last 20 orders       │
│ [queued ] TimesFM ETH 7d forecast           │
│ [failed ] Chronos SOL forecast: timeout     │
└────────────────────────────────────────────┘
```

交互：

- 可取消 queued/running 非关键任务；
- 可查看 degraded 原因；
- 可切换本地/云端 provider；
- 不允许从该页影响 Freqtrade 风控。

## 2. 策略详情页新增：规则 DSL 编辑模式

```text
策略详情
├── 概览
├── 回测结果
├── 模拟盘状态
├── Canvas 编辑
├── DSL 规则
└── Freqtrade 配置预览
```

DSL 规则页显示：

- JSON 只读/表单编辑；
- 校验状态；
- 白名单错误；
- 生成的 `strategy_rules.json`；
- 使用的 `PulseDeskUniversalStrategy.py` 版本。

## 3. 执行中心新增：Freqtrade 连接状态卡

```text
Freqtrade 状态
状态：freqtrade_native_guard_only
REST：disconnected
WebSocket：disconnected
Docker：running
开放持仓：2
原生风控：valid
用户动作：请人工检查交易所账户和容器日志
```

## 4. 系统设置新增：MCP Server

```text
MCP Server
状态：enabled / disabled
绑定地址：127.0.0.1
权限：read-only
最近调用：12
审计日志：查看
Token：旋转
```

危险操作不显示为 MCP 工具。

---

# v2.3 Addendum — AI 服务管理页面升级

## AI 服务管理 v2.3 布局

```text
AI 服务管理
├── Provider 总览
│   ├── OpenAI: enabled / latency / cost / failure rate
│   ├── Anthropic: enabled / latency / cost / failure rate
│   ├── DeepSeek: enabled / latency / cost / failure rate
│   ├── Ollama Local: fallback / GPU state
│   ├── Replicate: remote model / scale-to-zero status
│   ├── RunPod: remote model endpoint
│   └── Private Model Server: health / queue
│
├── Task Routing Matrix
│   ├── AI 投研: provider chain
│   ├── Agent 辩论: provider chain
│   ├── RAG 摘要: provider chain
│   ├── 情绪分析: cloud structured output → FinBERT fallback
│   ├── TimesFM/Chronos: remote model provider
│   └── SHAP: remote/offline batch
│
├── Queue 状态
│   ├── cloud_llm_queue
│   ├── remote_model_queue
│   └── local_gpu_queue
│
├── 隐私设置
│   ├── public_market_data: allow cloud
│   ├── research_text: allow cloud
│   ├── order_summary: allow after redaction
│   ├── raw_order_history: local only
│   └── api_keys: never cloud
│
└── Provider Usage
    ├── 今日成本
    ├── 平均延迟
    ├── 失败率
    └── 最近调用记录
```

## AI 总控台新增状态条

```text
AI Provider: normal / degraded / cloud_unavailable
Local GPU: idle / busy / OOM_protected
Today AI Cost: $x.xx
Pending AI Jobs: n
```

## Signal 详情页新增 Provider Trace

```text
Provider: DeepSeek / OpenAI / Anthropic / Ollama / Replicate
Model: xxx
Latency: 3.2s
Cost: $0.02
Privacy Level: medium
Input Hash: sha256:...
Generated At: ...
```

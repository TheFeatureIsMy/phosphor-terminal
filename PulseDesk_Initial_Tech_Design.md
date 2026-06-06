# PulseDesk 初版技术设计方案：AI 结构化自动交易与风险防御系统

> 文档定位：初版正式设计文档  
> 适用项目：PulseDesk macOS 原生量化交易 App  
> 设计目标：将策略画布、AI、指标、市场结构防御、账户风控、Freqtrade/CCXT 自动交易、回测复盘整合为一套可落地的生产级架构。  
> 更新时间：2026-06-05

---

## 目录

1. 产品定位与设计原则  
2. 系统总体架构  
3. 核心运行链路  
4. 双轨执行架构  
5. macOS App 与策略画布设计  
6. 节点体系设计  
7. Strategy DSL 初版设计  
8. Runtime Decision Snapshot 设计  
9. Market Structure Defense Engine 设计  
10. 结构生命周期管理  
11. AI Research Engine 设计  
12. Account Risk Firewall 设计  
13. 结构止损与盘口滑点保护  
14. 结构加仓与 DCA 约束  
15. Redis / In-Memory Runtime State Store  
16. PostgreSQL 数据库设计  
17. Freqtrade / CCXT 执行集成  
18. 断连保护与灾难兜底  
19. 回测与复盘体系  
20. 自我成长与策略优化  
21. 分阶段开发计划  
22. 开发 AI 总 Prompt  
23. 最终结论

---

# 1. 产品定位与设计原则

## 1.1 产品定位

PulseDesk 不是普通的自动交易 Bot，也不是单纯的指标画布工具。

推荐定位：

> **面向加密市场的 AI 结构化自动交易与风险防御系统。**

核心差异化：

```text
大多数自动交易工具关注“如何触发交易”；
PulseDesk 更关注“什么时候不该交易”。
```

系统会在用户交易意图和交易所执行之间建立一道：

```text
Market Structure Defense Firewall
市场结构防御防火墙
```

它用于识别：

```text
流动性陷阱
假突破
止损猎杀区域
FVG / OB 失效
市场状态突变
盘口流动性空虚
账户风险超限
AI 慢信号风险
执行链路异常
```

---

## 1.2 初版设计原则

```text
1. 画布负责策略意图，不直接最终下单。
2. 指标负责量化特征，不单独触发交易。
3. AI 负责解释、过滤、复盘，不直接下单。
4. 市场结构引擎负责识别流动性陷阱和结构失效。
5. 账户级风控拥有最终拒单权。
6. Freqtrade / CCXT 只负责执行经过确认的 Runtime Decision Snapshot。
7. Redis / In-Memory 是运行时状态中心。
8. PostgreSQL 只负责确认事件、回测、复盘、审计和学习。
9. 实时交易链路不能等待 AI、新闻、研报、链上慢分析。
10. 系统异常时，不能只禁止开仓，更必须保护已有持仓。
```

---

# 2. 系统总体架构

## 2.1 总体模块

```text
┌──────────────────────────────────────────────┐
│ macOS Native App                              │
│ SwiftUI / AppKit / WKWebView / React Flow     │
└───────────────────────┬──────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────┐
│ Strategy Canvas                               │
│ 策略画布 / 节点编排 / 参数配置 / DSL 生成      │
└───────────────────────┬──────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────┐
│ Strategy Orchestrator                         │
│ DSL 解析 / 策略调度 / 运行状态管理             │
└───────────────┬──────────────────┬───────────┘
                │                  │
                ▼                  ▼
┌──────────────────────────┐ ┌──────────────────────────┐
│ Fast Track Engine         │ │ Slow Track AI Engine      │
│ 实时指标 / 结构 / 风控     │ │ 新闻 / 链上 / 研报 / Agent │
└───────────────┬──────────┘ └──────────────┬───────────┘
                │                           │
                ▼                           ▼
┌──────────────────────────┐ ┌──────────────────────────┐
│ Redis / In-Memory Store   │ │ AI Risk Cache             │
│ 运行时状态中心             │ │ 慢信号风险缓存             │
└───────────────┬──────────┘ └──────────────┬───────────┘
                │                           │
                └──────────────┬────────────┘
                               ▼
┌──────────────────────────────────────────────┐
│ Decision Engine                               │
│ 候选信号 → 结构防御 → AI 缓存过滤 → 账户风控   │
└───────────────────────┬──────────────────────┘
                        ▼
┌──────────────────────────────────────────────┐
│ Runtime Decision Snapshot                     │
│ 最终交易决策 / 止损 / 仓位 / 执行计划          │
└───────────────────────┬──────────────────────┘
                        ▼
┌──────────────────────────────────────────────┐
│ Freqtrade Universal Strategy                  │
│ 读取 Snapshot / 执行开平仓 / 本地断连保护      │
└───────────────────────┬──────────────────────┘
                        ▼
┌──────────────────────────────────────────────┐
│ CCXT / Exchange API                            │
│ Binance / OKX / Bybit / Coinbase 等           │
└───────────────────────┬──────────────────────┘
                        ▼
┌──────────────────────────────────────────────┐
│ PostgreSQL                                     │
│ 决策快照 / 订单 / 结构事件 / 回测 / 复盘 / 学习 │
└──────────────────────────────────────────────┘
```

---

## 2.2 模块边界

| 模块 | 负责 | 不负责 |
|---|---|---|
| Strategy Canvas | 策略意图编排、参数配置、DSL 生成 | 直接下单 |
| Fast Track Engine | 实时价格、指标、结构、防御、账户风控 | 等待 AI 慢分析 |
| Slow Track AI Engine | 新闻、链上、研报、多 Agent、复盘解释 | 实时下单 |
| Market Structure Defense Engine | Sweep、FVG、OB、BOS/CHoCH、结构评分 | 账户总风险最终决策 |
| Account Risk Firewall | 仓位、亏损、敞口、强平距离、断路器 | 生成交易信号 |
| Freqtrade Adapter | 执行 Snapshot，管理订单回调 | 复杂 AI / 结构推理 |
| Redis / In-Memory | 运行时状态 | 长期复盘分析 |
| PostgreSQL | 持久化、审计、回测、学习 | 高频状态读写 |

---

# 3. 核心运行链路

完整运行流程：

```text
1. 数据更新
   K线 / 成交量 / 订单簿 / Funding / OI / 新闻 / 链上

2. Fast Track 实时计算
   RSI / ATR / Volume ZScore / Swing / Liquidity Pool / FVG / OB / BOS / CHoCH

3. Slow Track 异步分析
   新闻风险 / 巨鲸行为 / 研报摘要 / 多 Agent 研究 / AI Risk Cache

4. 画布策略执行
   DSL 解析后生成 Candidate Signal，不直接下单

5. 市场结构防御
   检查是否为流动性陷阱、是否已确认 Sweep、结构是否有效

6. AI 缓存过滤
   读取 ai_risk_score、risk_flags、trade_permission

7. 盘口流动性安全检查
   检查 spread、slippage、orderbook depth、liquidity void

8. 账户风控
   检查单笔风险、日亏损、周亏损、总敞口、强平距离

9. 生成 Runtime Decision Snapshot
   包含 entry、stop、position_size、reason_codes、valid_until

10. Freqtrade 执行
   读取 Snapshot，执行开仓、平仓、止损、加仓

11. 本地断连保护
   Freqtrade 在 Snapshot / Redis 异常时使用 last_valid_stop 或 static fallback stop

12. 交易所侧灾难保护
   尽量下发 reduce-only stop-market 或 stop-limit 保护单

13. 异步落库
   确认事件、候选信号、拒单、成交、止损、复盘标签进入 PostgreSQL

14. 回测与自我成长
   基于决策快照和交易结果生成策略优化建议
```

---

# 4. 双轨执行架构

## 4.1 为什么需要双轨

加密货币市场在插针、假突破、流动性扫荡时，几秒延迟就可能导致交易质量完全失真。

不能使用如下同步链路：

```text
Data Service → Structure Engine → AI Service → Decision Service → Redis → Freqtrade
```

因为：

```text
Sweep 检测可能耗时
AI 分析可能耗时
链上数据可能延迟
Redis / DB / RPC 都可能阻塞
Freqtrade 读到信号时，价格可能已经反向运行
```

因此系统必须使用：

```text
Fast Track：毫秒级实时决策
Slow Track：秒级 / 分钟级 AI 风险缓存
```

---

## 4.2 Fast Track

Fast Track 只处理实时交易必要信息：

```text
价格
K线
成交量
ATR
订单簿 spread / depth
Swing High / Low
Liquidity Pool
Liquidity Sweep
FVG
Order Block
BOS / CHoCH
Market Regime
持仓状态
账户风控状态
```

Fast Track 禁止：

```text
实时等待大模型
实时请求新闻接口
实时请求研报接口
实时请求链上慢 API
频繁读 PostgreSQL
复杂跨服务同步调用
```

目标延迟：

| 环节 | 目标延迟 |
|---|---:|
| 行情进入内存 | < 50ms |
| 指标增量计算 | < 20ms |
| 结构检测 | < 100ms |
| 盘口流动性检查 | < 50ms |
| 账户风控 | < 20ms |
| Snapshot 生成 | < 20ms |
| Redis 写入 | < 10ms |
| Fast Track 总链路 | < 200ms |

---

## 4.3 Slow Track

Slow Track 处理：

```text
AI 新闻分析
AI 研报摘要
巨鲸地址解释
交易所流入流出解释
宏观/监管风险
TradingAgents / AI-Trader 多 Agent 研究
交易复盘
参数优化建议
```

Slow Track 只写缓存，不直接下单：

```json
{
  "symbol": "BTC/USDT",
  "ai_risk_score": 0.42,
  "ai_bias": "cautious_long",
  "risk_flags": [
    "exchange_inflow_increased"
  ],
  "trade_permission": "allow",
  "summary": "技术结构偏多，但交易所流入略高，建议降低仓位。",
  "generated_at": "2026-06-05T10:00:00Z",
  "valid_until": "2026-06-05T10:15:00Z"
}
```

---

## 4.4 AI 缓存降级策略

| 场景 | 处理 |
|---|---|
| AI cache 新鲜 | 正常参与评分 |
| AI cache 缺失 | 保守降仓，例如 0.5x |
| AI cache 轻微过期 | 降仓 |
| AI cache 严重过期 | 禁止新开仓 |
| AI hard block | 禁止新开仓 |
| Slow Track 异常 | 不阻塞 Fast Track，进入保守模式 |

Fast Track 读取 AI 缓存时必须无阻塞。

---

# 5. macOS App 与策略画布设计

## 5.1 技术选型

推荐：

```text
macOS Native Shell：SwiftUI / AppKit
Canvas：WKWebView + React Flow
通信：JSBridge / Localhost API / WebSocket
后端：Python Services
执行：Freqtrade Docker + CCXT
运行时状态：Redis / In-Memory
持久化：PostgreSQL
```

## 5.2 为什么用 WebView + React Flow

React Flow 更适合复杂策略画布：

```text
节点拖拽
边连接
节点状态展示
端口类型约束
子流程
模板复用
JSON DSL 导出
调试面板
```

macOS 原生负责：

```text
系统菜单
本地文件
服务启动/停止
Docker 状态
通知
安全权限
交易所 API 配置
```

---

## 5.3 画布定位

画布不输出订单，而输出：

```text
Strategy Decision Request
```

错误：

```text
RSI < 30 → Buy
```

正确：

```text
RSI < 30
+ Sell-side Sweep Confirmed
+ Structure Score >= 70
+ AI Risk <= 0.65
+ Account Risk Allowed
→ Candidate Long Signal
→ Decision Engine 继续判断
```

---

# 6. 节点体系设计

## 6.1 节点分层

| 层级 | 节点 | 作用 |
|---|---|---|
| 数据层 | Kline、Orderbook、Funding、OI、News、Whale | 原始数据 |
| 指标层 | RSI、MACD、ATR、EMA、Bollinger、Volume ZScore | 传统量化特征 |
| 结构层 | Liquidity Pool、Sweep、FVG、OB、BOS/CHoCH | 市场结构特征 |
| AI 层 | News AI、Whale AI、Research AI、Conflict AI | 慢信号解释和过滤 |
| 决策层 | AND、OR、Threshold、Score、State Machine | 组合策略逻辑 |
| 防御层 | Liquidity Trap Filter、Structure Entry Score、Structure Stop | 结构防御 |
| 风控层 | Position Size、Daily Loss、Exposure、Liquidation Guard | 账户级风控 |
| 执行层 | Open、Close、Partial TP、Move Stop、Structure Add | 执行意图 |
| 复盘层 | Review、Label、Learning Suggestion | 自我成长 |

---

## 6.2 核心结构节点

### Liquidity Pool Node

输出：

```json
{
  "liquidity_pools": [
    {
      "pool_id": "lp_001",
      "type": "equal_low",
      "side": "sell_side",
      "price_level": 61200,
      "status": "active",
      "current_strength": 0.76
    }
  ]
}
```

### Liquidity Sweep Node

输出：

```json
{
  "event_state": "confirmed_sweep",
  "type": "sell_side_liquidity_sweep",
  "swept_level": 61200,
  "reclaim_price": 61480,
  "volume_zscore": 2.1,
  "confidence": 0.78
}
```

### FVG Node

输出：

```json
{
  "fvg_id": "fvg_001",
  "direction": "bullish",
  "price_top": 62000,
  "price_bottom": 61550,
  "filled_ratio": 0.32,
  "status": "active",
  "current_strength": 0.84
}
```

### Structure Entry Score Node

输出：

```json
{
  "score": 76,
  "direction": "long",
  "reasons": [
    "sell_side_sweep_confirmed",
    "reclaim_confirmed",
    "bullish_fvg_active",
    "higher_timeframe_not_bearish"
  ]
}
```

### Structure Stop Node

输出：

```json
{
  "stop_type": "structure_invalidated",
  "stop_price": 60880,
  "basis": "below_sweep_low_with_atr_and_liquidity_buffer",
  "distance_pct": 0.0142
}
```

---

# 7. Strategy DSL 初版设计

## 7.1 DSL 设计原则

DSL 描述：

```text
策略基础信息
运行时架构
数据需求
指标需求
结构需求
AI 缓存需求
入场逻辑
止损策略
仓位策略
结构加仓策略
账户风控策略
执行策略
降级策略
断连保护策略
多周期结构完整性策略
盘口流动性安全策略
```

---

## 7.2 DSL 示例

```json
{
  "version": "1.0",
  "strategy": {
    "id": "btc_structure_defense_long_initial",
    "name": "BTC 结构防御反转策略",
    "symbol": "BTC/USDT",
    "timeframe": "5m",
    "mode": "auto"
  },
  "runtime_mode": {
    "execution_architecture": "dual_track",
    "fast_track_required": true,
    "slow_track_ai_cache_required": false,
    "max_fast_track_latency_ms": 200
  },
  "data_requirements": {
    "kline": ["5m", "15m", "1h"],
    "orderbook": true,
    "indicators": ["rsi", "atr", "volume_zscore", "ema"],
    "structure": ["liquidity_pool", "sweep", "fvg", "order_block", "bos_choch"],
    "ai_cache": ["news_risk", "whale_risk", "conflict_analysis"]
  },
  "entry_logic": {
    "direction": "long",
    "conditions": [
      {
        "type": "liquidity_sweep",
        "side": "sell_side",
        "state": "confirmed_sweep",
        "required": true
      },
      {
        "type": "structure_score",
        "operator": ">=",
        "value": 70
      },
      {
        "type": "market_regime",
        "not_in": ["panic", "news_shock", "liquidity_void"]
      },
      {
        "type": "ai_risk_score",
        "operator": "<=",
        "value": 0.65,
        "fallback": "reduce_size"
      }
    ]
  },
  "stop_policy": {
    "mode": "structure_invalidated",
    "priority": [
      "sweep_low",
      "order_block_low",
      "fvg_low",
      "fallback_fixed_pct"
    ],
    "atr_buffer_coef": 0.3,
    "fallback_stop_pct": 0.02,
    "max_stop_distance_pct": 0.03,
    "min_reward_risk": 1.5,
    "stop_liquidity_safety_check": true
  },
  "liquidity_execution_safety": {
    "enabled": true,
    "spread_buffer_coef": 1.0,
    "slippage_buffer_coef": 1.0,
    "liquidity_void_multiplier": 1.5,
    "max_allowed_spread_pct": 0.003,
    "min_depth_score": 0.4,
    "action_on_wide_spread": "reject_trade",
    "action_on_thin_depth": "manual_confirm_required"
  },
  "position_policy": {
    "risk_per_trade": 0.01,
    "max_position_pct": 0.1,
    "size_adjustment_by_ai_risk": true,
    "size_adjustment_by_market_regime": true
  },
  "add_position_policy": {
    "allow_dca": false,
    "allow_structure_add": true,
    "max_add_count": 2,
    "require_stop_above_breakeven": true,
    "max_total_risk_after_add": 0.01,
    "min_reward_risk_after_add": 1.5,
    "min_liquidation_distance_pct": 0.08
  },
  "account_risk_policy": {
    "max_daily_loss": 0.03,
    "max_weekly_loss": 0.08,
    "max_consecutive_losses": 4,
    "kill_switch_enabled": true
  },
  "timeframe_integrity_policy": {
    "enabled": true,
    "invalidate_only_on_same_or_higher_timeframe_close": true,
    "low_timeframe_violation_action": "mark_temporary_violation",
    "allow_low_timeframe_to_update_filled_ratio": true
  },
  "disconnect_protection": {
    "enabled": true,
    "max_snapshot_miss_ticks": 3,
    "hard_disconnect_timeout_ms": 3000,
    "fallback_stop_mode": "static_percentage",
    "fallback_stop_pct": 0.02,
    "prefer_last_valid_stop": true,
    "emergency_action": "market_close",
    "block_new_entries": true,
    "place_exchange_side_stop": true
  },
  "execution_policy": {
    "engine": "freqtrade",
    "order_type": "limit",
    "slippage_limit": 0.002,
    "manual_confirm_required": false
  },
  "degradation_policy": {
    "ai_cache_soft_expired": "reduce_size",
    "ai_cache_hard_expired": "block_new_entries",
    "redis_unavailable": "disconnect_protection",
    "structure_engine_error": "manual_confirm_only",
    "freqtrade_heartbeat_lost": "pause_strategy"
  }
}
```

---

# 8. Runtime Decision Snapshot 设计

## 8.1 Snapshot 作用

Runtime Decision Snapshot 是执行引擎唯一可信输入。

画布、指标、结构、AI、风控的结果最终汇聚成 Snapshot。

Freqtrade 只读取 Snapshot 执行，不重新做复杂判断。

---

## 8.2 Snapshot 示例

```json
{
  "snapshot_id": "snap_20260605_100000_btc_5m",
  "strategy_id": "btc_structure_defense_long_initial",
  "strategy_version": "1.0",
  "exchange": "binance",
  "symbol": "BTC/USDT",
  "timeframe": "5m",
  "generated_at": "2026-06-05T10:00:00Z",
  "valid_until": "2026-06-05T10:05:00Z",
  "candidate_signal": {
    "direction": "long",
    "intent": "open_position",
    "confidence": 0.72,
    "reason_codes": [
      "confirmed_sell_side_sweep",
      "structure_score_passed",
      "rsi_oversold"
    ]
  },
  "indicator_context": {
    "rsi_14": 28.4,
    "atr_14": 510.2,
    "volume_zscore": 2.1
  },
  "structure_context": {
    "market_regime": "range_to_bullish_reversal",
    "sweep": {
      "state": "confirmed_sweep",
      "type": "sell_side_liquidity_sweep",
      "swept_level": 61200,
      "stop_loss_level": 60880,
      "confidence": 0.78
    },
    "fvg": {
      "status": "active",
      "top": 62000,
      "bottom": 61550,
      "filled_ratio": 0.32
    },
    "structure_score": 76
  },
  "ai_context": {
    "cache_state": "fresh",
    "ai_risk_score": 0.42,
    "risk_flags": [
      "exchange_inflow_increased"
    ],
    "valid_until": "2026-06-05T10:15:00Z"
  },
  "liquidity_execution_context": {
    "spread_pct": 0.0004,
    "depth_score": 0.81,
    "liquidity_state": "normal",
    "liquidity_buffer": 12.5
  },
  "risk_context": {
    "account_risk_state": "allowed",
    "risk_per_trade": 0.01,
    "daily_loss_remaining": 0.024,
    "weekly_loss_remaining": 0.065
  },
  "execution_plan": {
    "decision": "allow_trade",
    "entry_type": "limit",
    "entry_price": 61780,
    "stop_price": 60880,
    "take_profit_1": 62800,
    "take_profit_2": 64200,
    "position_size": 0.111
  },
  "reason_codes": [
    "structure_confirmed",
    "ai_cache_fresh",
    "account_risk_allowed",
    "spread_normal"
  ]
}
```

---

# 9. Market Structure Defense Engine 设计

## 9.1 职责

负责：

```text
识别 Liquidity Pool
识别 Liquidity Sweep
识别 FVG
识别 Order Block
识别 BOS / CHoCH
识别 Market Regime
管理结构生命周期
计算结构入场评分
计算结构止损
识别流动性陷阱
```

不负责：

```text
AI 慢分析
账户级最终风险判定
交易所执行
```

---

## 9.2 Liquidity Pool

识别对象：

```text
Equal High
Equal Low
Previous Day High / Low
Previous Week High / Low
Swing High / Low
Round Number Level
High Volume Node
```

输出：

```json
{
  "pool_id": "lp_001",
  "type": "equal_low",
  "side": "sell_side",
  "price_level": 61200,
  "initial_strength": 0.82,
  "current_strength": 0.76,
  "status": "active"
}
```

---

## 9.3 Liquidity Sweep

做多方向 Sell-side Sweep：

```text
1. 当前 low 跌破活跃 sell-side liquidity pool
2. 跌破幅度大于 ATR × k
3. 跌破幅度不能过大，避免把崩盘误判为 sweep
4. 当前或后续 M 根 K 收回关键位
5. 成交量 z-score 达标
6. 市场状态不属于 panic / news_shock / liquidity_void
7. 进入 confirmed_sweep 后才允许参与入场评分
```

Sweep 状态机：

```text
none
  ↓
sweep_candidate
  ↓
reclaim_pending
  ↓
confirmed_sweep
  ↓
expired / invalidated
```

交易不能基于 `sweep_candidate` 直接触发。

---

## 9.4 结构入场评分

建议初版评分：

| 因子 | 权重 |
|---|---:|
| Sweep confirmed | 25 |
| Reclaim confirmed | 15 |
| FVG / OB 有效 | 20 |
| 高周期方向不冲突 | 15 |
| 成交量确认 | 10 |
| 市场状态允许 | 10 |
| AI 风险不过高 | 5 |

入场条件示例：

```text
structure_score >= 70
AND market_regime NOT IN ["panic", "news_shock", "liquidity_void"]
AND ai_permission != "block_new_entries"
AND account_risk_state == "allowed"
```

---

# 10. 结构生命周期管理

## 10.1 通用原则

FVG / OB / Liquidity Pool 不永久有效。

所有结构必须有生命周期：

```text
active
touched
mitigated
invalidated
expired
```

Liquidity Pool 状态：

```text
active
touched
swept
invalidated
expired
```

---

## 10.2 多周期完整性原则

高周期结构不能被低周期 K 线提前判定为彻底失效。

核心规则：

```text
只有同周期或更高周期 K 线闭合，才能 invalidated 该周期结构。
低周期穿透只能更新 touched、filled_ratio、temporary_violation。
```

时间周期等级：

```python
TIMEFRAME_RANK = {
    "1m": 1,
    "3m": 2,
    "5m": 3,
    "15m": 4,
    "30m": 5,
    "1h": 6,
    "4h": 7,
    "1d": 8,
    "1w": 9
}

def can_invalidate_structure(candle_tf: str, structure_tf: str) -> bool:
    return TIMEFRAME_RANK.get(candle_tf, 0) >= TIMEFRAME_RANK.get(structure_tf, 0)
```

---

## 10.3 FVG 生命周期规则

Bullish FVG：

| 状态 | 条件 |
|---|---|
| active | 新形成 |
| touched | 价格进入 FVG 区间 |
| mitigated | 被部分或完全回补 |
| invalidated | 同周期或更高周期收盘跌破下沿 |
| expired | 超过有效 K 线数或强度衰减归零 |

---

## 10.4 Order Block 生命周期规则

Bullish OB：

| 状态 | 条件 |
|---|---|
| active | 新形成 |
| touched | 第一次回踩 |
| mitigated | 被回踩利用 |
| invalidated | 同周期或更高周期实体收盘跌破下沿 |
| expired | 触碰次数过多或有效期结束 |

---

## 10.5 强度衰减

结构强度随以下因素衰减：

```text
时间
触碰次数
回补比例
低周期穿透次数
市场状态变化
```

伪代码：

```python
def decay_strength(zone, current_candle):
    age_penalty = min(0.3, zone.age_bars * 0.002)
    touch_penalty = min(0.4, zone.touched_count * 0.10)
    fill_penalty = min(0.4, zone.filled_ratio * 0.4)
    violation_penalty = min(0.2, zone.low_tf_violation_count * 0.05)

    return max(
        0.0,
        zone.initial_strength
        - age_penalty
        - touch_penalty
        - fill_penalty
        - violation_penalty
    )
```

---

# 11. AI Research Engine 设计

## 11.1 AI 角色

AI 不是下单员，而是：

```text
研究员
风险解释器
多因子冲突分析器
复盘分析师
策略优化建议生成器
```

AI 不允许：

```text
直接下单
覆盖账户风控
无回测自动改策略
临场扩大仓位
```

---

## 11.2 AI 节点

```text
News Sentiment AI Node
Whale Behavior AI Node
Research Summary AI Node
Conflict Analysis AI Node
Trade Explanation AI Node
Strategy Improvement AI Node
```

---

## 11.3 AI 缓存评估

Fast Track 读取 AI 缓存后生成：

```text
allow
reduce_size
block_entry
```

伪代码：

```python
def evaluate_ai_cache_perm(ai_cache, current_time):
    if not ai_cache:
        return {
            "action": "reduce_size",
            "size_multiplier": 0.5,
            "reason": "ai_cache_missing_conservative_mode"
        }

    if ai_cache.get("trade_permission") == "block_new_entries":
        return {
            "action": "block_entry",
            "size_multiplier": 0.0,
            "reason": "ai_slow_track_hard_blocked"
        }

    if current_time > ai_cache["valid_until"]:
        elapsed = (current_time - ai_cache["valid_until"]).total_seconds()

        if elapsed <= 300:
            return {
                "action": "reduce_size",
                "size_multiplier": 0.5,
                "reason": "ai_cache_soft_expired"
            }

        return {
            "action": "block_entry",
            "size_multiplier": 0.0,
            "reason": "ai_cache_hard_expired"
        }

    ai_risk_score = ai_cache.get("ai_risk_score", 0.0)

    if ai_risk_score > 0.65:
        size_multiplier = max(0.3, 1.0 - (ai_risk_score - 0.5) * 2)
        return {
            "action": "reduce_size",
            "size_multiplier": size_multiplier,
            "reason": "ai_risk_score_elevated"
        }

    return {
        "action": "allow",
        "size_multiplier": 1.0,
        "reason": "ai_cache_fresh"
    }
```

---

# 12. Account Risk Firewall 设计

## 12.1 职责

账户级风控拥有最终拒单权。

即使画布、指标、AI、结构全部通过，只要账户风险不允许，系统必须拒单。

---

## 12.2 风控项

| 风控项 | 初版建议 |
|---|---:|
| 单笔最大风险 | 0.5% - 1% |
| 单币种最大敞口 | 5% - 15% |
| 单方向最大敞口 | 20% - 30% |
| 日最大亏损 | 2% - 3% |
| 周最大亏损 | 5% - 8% |
| 连续亏损暂停 | 3 - 5 笔 |
| 高波动降仓 | 0.3x - 0.5x |
| AI 风险高降仓 | 0.3x - 0.5x |
| 盘口价差过大 | 拒单或人工确认 |
| 强平距离过近 | 拒单 |

---

## 12.3 决策输出

```json
{
  "allow": false,
  "decision": "reject_order",
  "reason": "daily_loss_limit_reached",
  "account_risk_state": "blocked",
  "cooldown_until": "2026-06-05T18:00:00Z"
}
```

---

# 13. 结构止损与盘口滑点保护

## 13.1 结构止损优先级

做多：

```text
1. Sweep Low - Buffer
2. Bullish OB Low - Buffer
3. Bullish FVG Low - Buffer
4. Fallback Static Stop
```

做空反向。

---

## 13.2 Buffer 组成

止损 Buffer 不能只用 ATR，还要考虑盘口。

做多：

```text
stop_price =
structure_stop_level
- ATR Buffer
- Spread Buffer
- Slippage Buffer
```

做空：

```text
stop_price =
structure_stop_level
+ ATR Buffer
+ Spread Buffer
+ Slippage Buffer
```

其中：

```text
ATR Buffer = ATR × atr_buffer_coef
Spread Buffer = bid_ask_spread × spread_buffer_coef
Slippage Buffer = expected_slippage × slippage_buffer_coef
```

---

## 13.3 盘口风险因子

```python
def calculate_liquidity_buffer(orderbook_context, config):
    bid = orderbook_context.get("best_bid")
    ask = orderbook_context.get("best_ask")
    mid = orderbook_context.get("mid_price")
    expected_slippage = orderbook_context.get("expected_slippage", 0.0)
    depth_score = orderbook_context.get("depth_score", 1.0)

    if not bid or not ask or not mid:
        return {
            "buffer": 0.0,
            "spread_pct": None,
            "liquidity_state": "unknown"
        }

    spread = ask - bid
    spread_pct = spread / mid

    buffer = (
        spread * config.get("spread_buffer_coef", 1.0)
        + expected_slippage * config.get("slippage_buffer_coef", 1.0)
    )

    if spread_pct > config.get("max_allowed_spread_pct", 0.003):
        liquidity_state = "wide_spread"
    elif depth_score < config.get("min_depth_score", 0.4):
        liquidity_state = "thin_depth"
    else:
        liquidity_state = "normal"

    if liquidity_state in ["wide_spread", "thin_depth"]:
        buffer *= config.get("liquidity_void_multiplier", 1.5)

    return {
        "buffer": buffer,
        "spread_pct": spread_pct,
        "liquidity_state": liquidity_state
    }
```

---

## 13.4 仓位联动

仓位必须按真实风险倒推：

```text
position_size = risk_budget / abs(entry_price - stop_price)
```

如果加入 spread / slippage buffer 后：

```text
distance_pct > max_stop_distance_pct
```

则拒单。

如果：

```text
liquidity_state in ["wide_spread", "thin_depth"]
```

则：

```text
reject_trade
或
manual_confirm_required
```

---

# 14. 结构加仓与 DCA 约束

## 14.1 原则

PulseDesk 禁止传统亏损摊平式 DCA。

允许：

```text
结构确认加仓
盈利保护后加仓
原仓位止损已移动到 breakeven 后加仓
```

---

## 14.2 加仓硬约束

必须同时满足：

```text
1. 原始方向结构未失效
2. 新结构确认信号成立
3. 原仓位止损已移动到 breakeven 或盈利保护区
4. 加仓后总风险不超过初始风险预算
5. 加仓后 R:R 达标
6. 加仓后强平距离安全
7. 加仓次数未超过上限
```

---

## 14.3 核心公式

混合平均成本：

```text
blended_avg_entry =
(old_position_size × old_avg_entry + add_position_size × add_entry_price)
/
(old_position_size + add_position_size)
```

加仓后总风险：

```text
long:
total_risk_after_add =
(blended_avg_entry - structural_stop) × total_position_size

short:
total_risk_after_add =
(structural_stop - blended_avg_entry) × total_position_size
```

风险预算：

```text
risk_budget = account_equity × max_risk_per_trade
```

硬规则：

```text
total_risk_after_add <= risk_budget
```

更严格规则：

```text
structural_trailing_stop >= blended_avg_entry
```

即：只有当结构追踪止损可以移动到混合成本之上，才允许加仓。

---

# 15. Redis / In-Memory Runtime State Store

## 15.1 原则

运行时状态不依赖 PostgreSQL。

运行时数据进入：

```text
Redis
本地内存缓存
轻量 Snapshot
```

确认事件才进入 PostgreSQL。

---

## 15.2 Redis Key 设计

```text
pd:runtime:{exchange}:{symbol}:{timeframe}:liquidity_pools
pd:runtime:{exchange}:{symbol}:{timeframe}:fvg_zones
pd:runtime:{exchange}:{symbol}:{timeframe}:order_blocks
pd:runtime:{exchange}:{symbol}:{timeframe}:structure_state
pd:runtime:{exchange}:{symbol}:{timeframe}:market_regime
pd:runtime:{exchange}:{symbol}:ai_risk_cache
pd:runtime:account:{account_id}:risk_state
pd:runtime:decision:{strategy_id}:{symbol}:{timeframe}
```

---

## 15.3 何时写 PostgreSQL

只在确认事件发生时异步写入：

```text
Liquidity Pool swept
FVG touched / mitigated / invalidated / expired
OB touched / mitigated / invalidated / expired
BOS / CHoCH confirmed
Candidate signal created
Order allowed / rejected
Order submitted / filled / cancelled
Trade closed
Review label generated
Strategy version changed
```

---

# 16. PostgreSQL 数据库设计

## 16.1 liquidity_pools

```sql
CREATE TABLE liquidity_pools (
    id BIGSERIAL PRIMARY KEY,
    exchange VARCHAR(32) NOT NULL,
    symbol VARCHAR(32) NOT NULL,
    timeframe VARCHAR(16) NOT NULL,

    pool_type VARCHAR(64) NOT NULL,
    side VARCHAR(16) NOT NULL,
    price_level NUMERIC(30, 12) NOT NULL,

    initial_strength NUMERIC(6, 4) NOT NULL,
    current_strength NUMERIC(6, 4),

    status VARCHAR(32) NOT NULL DEFAULT 'active',
    touched_count INT NOT NULL DEFAULT 0,

    candle_time TIMESTAMPTZ NOT NULL,
    first_touched_at TIMESTAMPTZ,
    last_touched_at TIMESTAMPTZ,
    swept_at TIMESTAMPTZ,
    mitigated_at TIMESTAMPTZ,
    invalidated_at TIMESTAMPTZ,
    expired_at TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,

    swept_by_snapshot_id BIGINT,
    metadata JSONB NOT NULL DEFAULT '{}',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_lp_active_lookup
ON liquidity_pools(symbol, timeframe, side, status)
WHERE status = 'active';

CREATE INDEX idx_lp_symbol_time
ON liquidity_pools(symbol, timeframe, candle_time DESC);
```

---

## 16.2 structure_zones

```sql
CREATE TABLE structure_zones (
    id BIGSERIAL PRIMARY KEY,
    exchange VARCHAR(32) NOT NULL,
    symbol VARCHAR(32) NOT NULL,
    timeframe VARCHAR(16) NOT NULL,

    zone_type VARCHAR(64) NOT NULL,
    direction VARCHAR(16) NOT NULL,

    price_top NUMERIC(30, 12) NOT NULL,
    price_bottom NUMERIC(30, 12) NOT NULL,
    price_mid NUMERIC(30, 12),

    initial_strength NUMERIC(6, 4) NOT NULL,
    current_strength NUMERIC(6, 4),
    filled_ratio NUMERIC(6, 4) DEFAULT 0,

    status VARCHAR(32) NOT NULL DEFAULT 'active',
    touched_count INT NOT NULL DEFAULT 0,

    candle_time TIMESTAMPTZ NOT NULL,
    first_touched_at TIMESTAMPTZ,
    last_touched_at TIMESTAMPTZ,
    mitigated_at TIMESTAMPTZ,
    invalidated_at TIMESTAMPTZ,
    expired_at TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,

    metadata JSONB NOT NULL DEFAULT '{}',

    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_structure_zones_active
ON structure_zones(symbol, timeframe, zone_type, status)
WHERE status = 'active';

CREATE INDEX idx_structure_zones_time
ON structure_zones(symbol, timeframe, candle_time DESC);
```

---

## 16.3 decision_snapshots

```sql
CREATE TABLE decision_snapshots (
    id BIGSERIAL PRIMARY KEY,
    snapshot_uid VARCHAR(128) UNIQUE NOT NULL,

    strategy_id BIGINT NOT NULL,
    strategy_version_id BIGINT,
    run_id BIGINT,

    exchange VARCHAR(32) NOT NULL,
    symbol VARCHAR(32) NOT NULL,
    timeframe VARCHAR(16) NOT NULL,

    candidate_signal JSONB NOT NULL DEFAULT '{}',
    indicator_context JSONB NOT NULL DEFAULT '{}',
    structure_context JSONB NOT NULL DEFAULT '{}',
    ai_context JSONB NOT NULL DEFAULT '{}',
    liquidity_execution_context JSONB NOT NULL DEFAULT '{}',
    risk_context JSONB NOT NULL DEFAULT '{}',
    execution_plan JSONB NOT NULL DEFAULT '{}',

    final_decision VARCHAR(32) NOT NULL,
    reject_reason TEXT,
    confidence NUMERIC(6, 4),

    latency_ms INT,
    fast_track_latency_ms INT,
    ai_cache_age_ms INT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_decision_snapshots_strategy_time
ON decision_snapshots(strategy_id, created_at DESC);

CREATE INDEX idx_decision_snapshots_symbol_time
ON decision_snapshots(symbol, timeframe, created_at DESC);

CREATE INDEX idx_decision_snapshots_final_decision
ON decision_snapshots(final_decision, created_at DESC);
```

---

## 16.4 risk_decision_logs

```sql
CREATE TABLE risk_decision_logs (
    id BIGSERIAL PRIMARY KEY,

    snapshot_id BIGINT REFERENCES decision_snapshots(id),
    account_id BIGINT NOT NULL,

    risk_state VARCHAR(32) NOT NULL,
    decision VARCHAR(32) NOT NULL,
    reason_code VARCHAR(128),

    account_equity NUMERIC(30, 12),
    risk_budget NUMERIC(30, 12),
    used_risk NUMERIC(30, 12),
    remaining_risk NUMERIC(30, 12),

    daily_pnl NUMERIC(30, 12),
    weekly_pnl NUMERIC(30, 12),
    open_exposure NUMERIC(30, 12),
    liquidation_distance_pct NUMERIC(10, 6),

    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

---

## 16.5 trade_learning_labels

```sql
CREATE TABLE trade_learning_labels (
    id BIGSERIAL PRIMARY KEY,

    trade_id BIGINT NOT NULL,
    snapshot_id BIGINT,

    label_type VARCHAR(64) NOT NULL,
    label_value VARCHAR(128) NOT NULL,
    confidence NUMERIC(6, 4),

    source VARCHAR(64) NOT NULL,
    notes TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

标签示例：

```text
entered_before_reclaim_confirmation
stop_too_close_to_liquidity_pool
failed_due_to_news_shock
failed_due_to_market_regime_shift
good_structure_entry
structure_add_rejected_risk_budget
ai_cache_expired_reduced_size
snapshot_disconnect_emergency_close
```

---

# 17. Freqtrade / CCXT 执行集成

## 17.1 Freqtrade 职责

Freqtrade 只做：

```text
读取 Runtime Decision Snapshot
执行 entry / exit / stop / position adjustment
维护本地断连保护
上报订单和交易结果
```

Freqtrade 不做：

```text
实时调用 AI
实时拉新闻
复杂结构识别
频繁读写 PostgreSQL
账户全局风控最终决策
```

---

## 17.2 Snapshot 读取优先级

```text
1. 本地内存缓存
2. Redis Snapshot
3. 本地 JSON 兜底快照
```

禁止每根 K 线同步读取大型 JSON 文件。

---

## 17.3 Universal Strategy 伪代码

```python
class PulseDeskUniversalStrategy(IStrategy):
    def populate_indicators(self, dataframe, metadata):
        return dataframe

    def populate_entry_trend(self, dataframe, metadata):
        snapshot = runtime_snapshot_cache.get(metadata["pair"])

        if not snapshot:
            return dataframe

        if snapshot["execution_plan"]["decision"] == "allow_trade":
            dataframe.loc[dataframe.index[-1], "enter_long"] = 1

        return dataframe

    def custom_stoploss(self, pair, trade, current_time, current_rate, current_profit, **kwargs):
        snapshot = runtime_snapshot_cache.get(pair)

        if snapshot:
            stop_price = snapshot["execution_plan"].get("stop_price")
            if stop_price:
                return convert_stop_price_to_freqtrade_stoploss(current_rate, stop_price)

        return local_snapshot_guard.get_fallback_stoploss(pair, trade, current_rate)

    def adjust_trade_position(self, trade, current_time, current_rate, current_profit, **kwargs):
        snapshot = runtime_snapshot_cache.get(trade.pair)

        if not snapshot:
            return None

        if snapshot["execution_plan"].get("decision") == "allow_add_position":
            return snapshot["execution_plan"].get("add_position_size")

        return None
```

---

# 18. 断连保护与灾难兜底

## 18.1 问题

如果 Redis / Snapshot / Structure Engine 异常，而已有持仓依赖动态结构止损更新，就可能产生裸奔风险。

所以系统不能只做：

```text
Redis 不可用 → 暂停开仓
```

还必须做：

```text
Redis 不可用 → 保护已有持仓
```

---

## 18.2 Freqtrade 本地断连保护

规则：

```text
1. 每次成功读取 Snapshot 时，缓存 last_valid_stop_price。
2. 每次成功读取 Snapshot 时，记录 last_snapshot_at。
3. 如果连续 N 个 Tick 无法读取有效 Snapshot，进入 disconnect_protection。
4. 如果已有持仓且无法获取有效 stop_price：
   - 优先使用 last_valid_stop_price；
   - 如果 last_valid_stop_price 不存在，使用 static_fallback_stop；
   - 如果价格触发兜底止损，立即 Market Close；
   - 如果超过 hard_disconnect_timeout，立即 Market Close 或下发交易所 stop-market 保护单。
5. disconnect_protection 下禁止开新仓。
```

---

## 18.3 本地保护伪代码

```python
class RuntimeSnapshotGuard:
    def __init__(self, config):
        self.config = config
        self.miss_count = {}
        self.last_snapshot_at = {}
        self.last_valid_stop_price = {}

    def update_from_snapshot(self, pair, snapshot, now):
        if snapshot and snapshot.get("execution_plan", {}).get("stop_price"):
            self.miss_count[pair] = 0
            self.last_snapshot_at[pair] = now
            self.last_valid_stop_price[pair] = snapshot["execution_plan"]["stop_price"]
            return {
                "state": "healthy",
                "stop_price": self.last_valid_stop_price[pair]
            }

        self.miss_count[pair] = self.miss_count.get(pair, 0) + 1

        if self.miss_count[pair] >= self.config.get("max_snapshot_miss_ticks", 3):
            return {
                "state": "disconnect_protection",
                "stop_price": self.last_valid_stop_price.get(pair),
                "reason": "runtime_snapshot_missing"
            }

        return {
            "state": "degraded",
            "stop_price": self.last_valid_stop_price.get(pair),
            "reason": "snapshot_temporarily_missing"
        }

    def should_emergency_close(self, pair, current_rate, trade_direction, now):
        if self.miss_count.get(pair, 0) < self.config.get("max_snapshot_miss_ticks", 3):
            return {"close": False}

        stop_price = self.last_valid_stop_price.get(pair)

        if not stop_price:
            return {
                "close": True,
                "reason": "no_valid_stop_available_under_disconnect"
            }

        if trade_direction == "long" and current_rate <= stop_price:
            return {
                "close": True,
                "reason": "last_valid_stop_triggered_under_disconnect"
            }

        if trade_direction == "short" and current_rate >= stop_price:
            return {
                "close": True,
                "reason": "last_valid_stop_triggered_under_disconnect"
            }

        last_at = self.last_snapshot_at.get(pair)
        if last_at:
            elapsed_ms = (now - last_at).total_seconds() * 1000
            if elapsed_ms > self.config.get("hard_disconnect_timeout_ms", 3000):
                return {
                    "close": True,
                    "reason": "hard_disconnect_timeout_exceeded"
                }

        return {"close": False}
```

---

## 18.4 交易所侧灾难保护单

每次开仓后应尽量创建交易所侧保护单：

```text
Spot：stop-limit / stop-market，视交易所支持情况
Futures：reduce-only stop-market
```

原则：

```text
本地结构止损负责动态优化
交易所侧保护单负责灾难兜底
```

---

# 19. 回测与复盘体系

## 19.1 两类回测

```text
策略回测
结构事件回测
```

---

## 19.2 策略回测

测试：

```text
胜率
盈亏比
最大回撤
最大连续亏损
日内亏损
周亏损
加仓后风险
止损有效性
AI 缓存降级策略
断连保护触发结果
```

---

## 19.3 结构事件回测

测试：

```text
Sell-side Sweep 后未来 N 根 K 线上涨概率
Buy-side Sweep 后未来 N 根 K 线下跌概率
FVG 第一次回踩成功率
OB 第一次触碰与第三次触碰成功率差异
不同市场状态下 Sweep 策略有效性
结构止损距离与胜率关系
多周期结构 invalidation 规则影响
```

---

## 19.4 市场状态分层

所有回测必须按市场状态分层：

```text
trend_up
trend_down
range
high_volatility
panic
news_shock
liquidity_void
```

否则结果会失真。

---

# 20. 自我成长与策略优化

## 20.1 学习数据来源

```text
decision_snapshots
risk_decision_logs
orders
trades
structure_zones
liquidity_pools
trade_learning_labels
AI review reports
```

---

## 20.2 复盘标签

```text
good_structure_entry
entered_before_reclaim_confirmation
stop_too_close_to_liquidity_pool
failed_due_to_news_shock
failed_due_to_market_regime_shift
structure_add_rejected_risk_budget
ai_cache_expired_reduced_size
snapshot_disconnect_emergency_close
```

---

## 20.3 策略优化流程

```text
1. 收集交易快照
2. 标记盈利/亏损交易
3. AI 复盘原因
4. 聚类失败模式
5. 生成参数调整建议
6. 回测候选参数
7. 人工确认
8. 发布新策略版本
```

AI 不能直接上线新策略，必须经过：

```text
回测
风险验证
人工确认
版本记录
```

---

# 21. 分阶段开发计划

## Phase 1：基础画布 + DSL + Freqtrade 打通

目标：

```text
画布能生成 DSL，并让 Freqtrade 读取 Snapshot 执行基础策略。
```

范围：

```text
macOS WebView + React Flow
基础节点系统
Kline / RSI / MACD / ATR
基础风控节点
DSL 初版
Runtime Snapshot 初版
Freqtrade Universal Strategy
基础回测
```

不做：

```text
复杂 AI
完整 SMC
Tick 级计算
结构加仓
多 Agent
```

---

## Phase 2：Fast Track + 市场结构防御引擎

目标：

```text
实现核心差异化：市场结构防御。
```

范围：

```text
Dual-Track Execution
Redis Runtime State Store
Liquidity Pool Detector
Liquidity Sweep Detector
FVG Detector
Order Block Detector
BOS / CHoCH Detector
Structure Lifecycle State Machine
Multi-Timeframe Integrity Policy
Structure Entry Score
Structure Stop
Liquidity Execution Safety
Decision Snapshot
结构事件回测
```

---

## Phase 3：断连保护 + 执行安全

目标：

```text
确保系统异常时已有持仓不裸奔。
```

范围：

```text
RuntimeSnapshotGuard
last_valid_stop_price
static fallback stop
hard disconnect timeout
emergency market close
exchange side protective stop
Freqtrade heartbeat monitor
safe mode
```

---

## Phase 4：Slow Track AI 风险缓存

目标：

```text
AI 不直接交易，只做异步风险缓存与解释。
```

范围：

```text
News Sentiment AI
Whale Behavior AI
Research Summary AI
Conflict Analysis AI
AI Risk Cache
AI Cache Degradation Policy
Trade Explanation
Trade Review Labels
```

---

## Phase 5：结构加仓与账户级高级风控

目标：

```text
实现安全的结构确认加仓，禁止无脑 DCA。
```

范围：

```text
Structural Position Adjustment Policy
Blended Avg Entry
Total Risk After Add
Breakeven Stop Check
Reward/Risk After Add
Liquidation Distance
Max Daily / Weekly Loss
Kill Switch
```

---

## Phase 6：自我成长与多 Agent

目标：

```text
基于历史交易快照和复盘标签生成策略优化建议。
```

范围：

```text
TradingAgents / AI-Trader 接入
Trade Learning Labels
Strategy Version Comparison
Parameter Suggestion
Candidate Strategy Generator
Human Approval Before Deployment
```

---

# 22. 开发 AI 总 Prompt

```markdown
你现在要基于《PulseDesk 初版技术设计方案》进行开发。

这不是一个普通交易 Bot，也不是单独的流动性猎杀插件，而是一个：
画布 + AI + 指标 + 自动交易 + 市场结构防御 + 账户风控 + 回测复盘 的一体化系统。

核心原则：
1. 画布负责策略意图，不直接下单。
2. 指标负责量化特征，不单独触发交易。
3. AI 负责新闻、链上、研报、多因子冲突解释和复盘，不直接下单。
4. Market Structure Defense Engine 负责 Liquidity Pool、Sweep、FVG、Order Block、BOS/CHoCH、结构评分和结构止损。
5. Account Risk Firewall 拥有最终拒单权，任何策略和 AI 都不能覆盖。
6. 系统必须使用 Dual-Track Execution：
   - Fast Track：毫秒级，价格 / K线 / 结构 / 风控，不等待 AI。
   - Slow Track：秒级或分钟级，AI / 新闻 / 链上 / 研报，异步写入 AI Risk Cache。
7. Redis / In-Memory 是运行时状态中心。
8. PostgreSQL 只负责确认事件、决策快照、订单事件、回测、复盘和学习。
9. FVG / OB / Liquidity Pool 必须有生命周期状态机。
10. 高周期结构不能被低周期 K线提前 invalidated。
11. 结构止损必须考虑 ATR、spread、slippage、orderbook depth。
12. 禁止无脑 DCA，只允许通过数学风控校验的结构确认加仓。
13. Freqtrade 只读取 Runtime Decision Snapshot 执行，不在主循环中调用 AI 或慢 I/O。
14. Redis / Snapshot 异常时，Freqtrade 必须有本地断连保护、last_valid_stop、static fallback stop、emergency close。
15. 所有候选信号、拒单、成交、止损、加仓都必须生成 reason_codes。

请按以下模块实现：
- Strategy Canvas Node System
- Strategy DSL
- Dual-Track Execution Architecture
- Redis Runtime State Store
- Market Structure Defense Engine
- Structure Lifecycle State Machine
- Multi-Timeframe Integrity Policy
- Liquidity Execution Safety
- Account Risk Firewall
- Structural Stop Calculator
- Structural Position Adjustment Policy
- Runtime Decision Snapshot
- Freqtrade Adapter
- Disconnect Protection
- Backtest Engine
- Trade Review / Learning Engine

输出要求：
- 模块边界
- 数据流
- 画布节点
- Redis Key 设计
- PostgreSQL 表结构
- DSL JSON 示例
- Runtime Snapshot 示例
- 核心伪代码
- 分阶段开发任务
- 测试项和验收标准
```

---

# 23. 最终结论

PulseDesk 初版架构应定义为：

```text
慢轨负责 AI 研究和风险缓存
快轨负责实时结构判断和执行防御
画布负责表达策略意图
指标负责提供量化特征
结构引擎负责识别陷阱
账户风控负责最终拒单
Freqtrade / CCXT 负责执行
Redis / In-Memory 负责运行时状态
PostgreSQL 负责复盘、回测、审计和学习
```

一句话总结：

> PulseDesk 不是让用户更快地下单，而是在用户交易意图和交易所执行之间建立一道带断路保护、市场结构识别和账户风控约束的“流动性防御防火墙”。


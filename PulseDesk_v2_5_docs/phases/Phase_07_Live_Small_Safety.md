# Phase 07 — Live Small Safety 小仓位实盘

## 目标

在所有基础设施稳定后，允许极小仓位、人工确认、强风控的 live_small 模式。

## 前置条件

必须全部满足：

- Signal Center 稳定；
- Freqtrade Adapter 稳定；
- backtest 可复现；
- dry-run 运行至少 14-30 天；
- 风控中心可用；
- emergency stop 可用；
- API Key 加密存储；
- 执行日志完整；
- 策略状态为 paper_passed；
- 人工确认。

## live_small 约束

```json
{
  "max_position_pct_per_trade": 0.01,
  "max_total_position_pct": 0.05,
  "max_daily_loss_pct": 0.01,
  "max_consecutive_losses": 2,
  "allow_leverage": false,
  "allow_market_order": false,
  "requires_human_confirm": true
}
```

## 禁止事项

- 禁止 AI 直接 live；
- 禁止 Agent 直接 live；
- 禁止 manipulation_score > 80 的标的 live；
- 禁止无止损策略 live；
- 禁止未 dry-run 策略 live；
- 禁止 Growth Engine 自动 live；
- 禁止自动提高仓位。

## 人工确认流程

```text
策略申请 live_small
  ↓
展示回测报告
  ↓
展示 dry-run 报告
  ↓
展示风控报告
  ↓
展示最大亏损估算
  ↓
用户输入确认短语
  ↓
启动 live-small Freqtrade 容器
```

确认短语示例：

```text
I understand this is live trading with real money.
```

## Kill Switch

必须支持：

- UI 紧急停止；
- API 紧急停止；
- 本地配置 emergency_stop；
- Freqtrade 容器 stop；
- 禁止新 TradeIntent；
- 已有持仓处理策略可配置：hold / reduce / exit。

## 阶段验收

- [ ] live_small 默认关闭；
- [ ] 开启需要人工确认；
- [ ] API Key 不明文存储；
- [ ] live_small 仓位受限；
- [ ] emergency stop 可立即停止新交易；
- [ ] 所有 live 事件写审计日志；
- [ ] 任何 AI/Agent 无法绕过 RiskEngine。

---

# v2.2 补充：live_small 前置硬性检查

进入 live_small 前必须额外检查：

1. Freqtrade 原生 config 包含 stoploss；
2. Freqtrade 原生 config 包含 max_open_trades；
3. Freqtrade 原生 config 不允许高风险策略 unlimited；
4. PulseDesk 与 Freqtrade REST/WebSocket 均为 healthy；
5. MCP Server 不具备启动 live 的工具；
6. StrategyRuleDSL 已锁定版本，不再接受 LLM 动态修改；
7. Inference Worker Queue 的 degraded 状态不会影响已有持仓止损；
8. 紧急停止按钮可用；
9. API Key 加密可用；
10. 人工确认记录写入 audit log。

---

# v2.3.1 同步修订：Cloud AI 与 live_small 的安全边界

## 变更原因

Cloud AI 能提升研究质量，但不能成为 live_small 的实时风控唯一依据。实盘状态下，最可靠的兜底必须在 Freqtrade 原生配置和交易所订单层，而不是远程 LLM 响应。

## live_small Provider 约束

live_small 下允许使用 Cloud AI 做：

- 盘前研究；
- 风险解释；
- 交易后复盘；
- Signal 辅助评分。

live_small 下禁止 Cloud AI 做：

- 直接下单；
- 实时止损唯一判断；
- 动态扩大仓位；
- 关闭 Freqtrade 原生 stoploss；
- 生成并热替换策略规则。

## 双层风控要求

```text
Layer 1: Freqtrade Native Guardrails
- stoploss
- trailing_stop
- max_open_trades
- stake limit
- dry_run/live mode isolation

Layer 2: PulseDesk RiskEngine
- signal conflict
- manipulation risk
- correlation risk
- agent permission
- daily loss
- emergency stop
```

## Cloud / Local 降级行为

如果 Cloud Provider 不可用：

- 不影响 Freqtrade 原生止损；
- live_small 不升级新仓；
- 允许已有持仓按 Freqtrade 原生规则继续；
- PulseDesk UI 标记 AI degraded；
- 新的 AI Signal 状态为 delayed/degraded。

如果 PulseDesk 与 Freqtrade REST 失连：

- PulseDesk 进入 degraded；
- 禁止新 live 操作；
- 保持 Freqtrade 原生 stoploss 生效；
- 触发本地通知；
- 恢复连接后进行订单 reconciliation。

## 验收标准补充

- live_small 策略 config 中必须有 stoploss / max_open_trades；
- Cloud Provider 断开时，已有 Freqtrade 容器不崩溃；
- PulseDesk REST 失连后不会错误显示“正常”；
- 用户必须能看到 Cloud AI degraded 与 Freqtrade degraded 是两个不同状态；
- 所有 live_small 操作必须有人机确认记录。

## 禁止事项

- 禁止让 Cloud AI 直接触发 live order；
- 禁止无 Freqtrade 原生 stoploss 的 live_small；
- 禁止 Cloud AI 失败时 fallback 到“默认允许交易”；
- 禁止本地 PulseDesk 失连时继续发起新 live 交易。


---

# v2.3.2 Addendum: Reconciliation State Machine

## Mandatory rule

When PulseDesk enters `reconciliating`, all outbound TradeIntent and strategy deployment operations must be blocked.

## Required implementation tasks

1. Add global `system_state` values: `healthy`, `pulse_degraded`, `freqtrade_native_guard_only`, `reconciliating`, `manual_review_required`.
2. Add reconciliation lock to prevent concurrent reconciliation jobs.
3. Add outbound TradeIntent queue block when state is `reconciliating`.
4. Fetch Freqtrade status, open trades, closed trades, recent orders, balances/positions.
5. Treat Freqtrade/exchange state as truth source.
6. Patch PulseDesk local order and position tables from Freqtrade data.
7. Run post-reconciliation risk scan.
8. Move to `healthy` only when all checks pass.
9. Move to `manual_review_required` if mismatch is unresolved.

## API behavior

- `POST /trade-intents` returns `409 SYSTEM_RECONCILING`.
- `POST /strategies/deploy` returns `409 SYSTEM_RECONCILING`.
- `GET /positions` returns stale flag until reconciliation passes.
- Emergency stop remains available through native Freqtrade / exchange path.

## Acceptance criteria

- If Freqtrade closes a trade during PulseDesk outage, PulseDesk detects it after reconnect.
- No new TradeIntent is sent before reconciliation completes.
- Local positions are overwritten by Freqtrade truth source.
- Unresolved mismatch never auto-recovers to healthy.

## v2.4 补充：Live Small 与交易所 API 边界

### 必做任务

1. live_small 必须通过 `RequestLiveSmallCommand`，且需要 `human_confirmed=true`。

2. 交易执行只能走 Freqtrade。

3. 交易所原生 API 第一阶段只读。

4. `reconciliating` 状态下禁止新 TradeIntent，只允许对账和紧急停止。

5. 对账真理源顺序：

```text
Freqtrade REST
Exchange read-only account API
Freqtrade local DB
PulseDesk local DB
```

6. live_small 前必须存在：

```text
StrategyVersion
StrategyRuleDSL
StrategyRun
FreqtradeRun
RiskDecision
ExecutionLedger
```

### 验收标准

```text
没有人工确认不能创建 live_small command。
Cloud AI provider degraded 时不能默认允许交易。
Freqtrade / PulseDesk 失连后恢复必须先 reconciliate。
差异无法解决时进入 manual_review_required。
```

---

## v2.5 Phase 顺序说明

本 Phase 文件保留历史开发细节，但实现顺序以 `17_Phase_Plan_v2_5.md` 为准。若本文件存在开放式 Strategy.py、AI 直接执行、Signal 直接创建 TradeIntent 等旧描述，均以 v2.5 Master Architecture Decision 为准。

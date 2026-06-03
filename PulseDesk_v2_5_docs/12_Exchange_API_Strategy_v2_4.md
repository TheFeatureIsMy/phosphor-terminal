# PulseDesk v2.4 交易所 API 接入策略

> 目标：明确 PulseDesk、Freqtrade、CCXT、交易所原生 API 的职责边界，避免执行路径混乱。

## 1. 默认原则

```text
1. Crypto 交易执行主路径：Freqtrade + CCXT。
2. PulseDesk 不直接向交易所下单。
3. 交易所原生 API 只做补充数据源和对账辅助。
4. 合约/OI/Funding/爆仓等数据可直连交易所或第三方数据源读取，但不用于直接执行。
5. 第一阶段只做现货 + backtest + dry-run。
6. live_small 必须经过 Freqtrade、RiskEngine、人工确认三层门禁。
```

---

## 2. 推荐第一阶段交易所范围

### 2.1 默认推荐

```text
交易所：Binance 或 OKX
交易类型：现货
执行模式：backtest + dry-run
合约：只读数据，不执行合约交易
```

### 2.2 为什么第一阶段不建议直接做合约执行

```text
1. 合约涉及杠杆、强平、资金费率、保证金模式。
2. 各交易所统一账户/逐仓/全仓语义不同。
3. Freqtrade 对不同交易所/交易模式支持边界不同。
4. 操控雷达需要读 funding / OI / liquidation，但读取不等于执行。
5. 个人项目第一阶段应优先验证策略链路，而不是放大执行风险。
```

---

## 3. API 使用分层

## 3.1 Freqtrade / CCXT 主路径

用于：

```text
backtest
dry-run
live_small 现货交易
订单同步
持仓同步
策略运行状态
```

禁止：

```text
PulseDesk 直接绕过 Freqtrade 下单。
AI 直接调用交易所 API。
Canvas 直接调用交易所 API。
```

## 3.2 交易所原生 REST / WebSocket 补充路径

用于只读数据：

```text
资金费率
Open Interest
多空比
爆仓数据
订单簿深度
大额成交
交易所系统状态
费率信息
```

写操作禁止：

```text
禁止使用交易所原生 API 下单。
禁止使用交易所原生 API 改杠杆。
禁止使用交易所原生 API 直接平仓，除非作为 EmergencyStop 的人工确认专项流程。
```

---

## 4. Exchange Data Adapter

```text
exchange_data_adapters/
├── base.py
├── binance_adapter.py
├── okx_adapter.py
├── bybit_adapter.py
├── ccxt_public_adapter.py
└── third_party_market_data_adapter.py
```

### 4.1 Base Interface

```python
class ExchangeDataAdapter:
    async def get_funding_rate(self, symbol: str) -> FundingRateSnapshot: ...
    async def get_open_interest(self, symbol: str) -> OpenInterestSnapshot: ...
    async def get_order_book(self, symbol: str, depth: int = 50) -> OrderBookSnapshot: ...
    async def get_recent_liquidations(self, symbol: str) -> list[LiquidationEvent]: ...
    async def get_exchange_status(self) -> ExchangeStatus: ...
```

### 4.2 Data Quality

所有交易所补充数据必须附带：

```json
{
  "source": "okx",
  "symbol": "BTC/USDT",
  "data_type": "funding_rate",
  "data_quality": {
    "status": "ok",
    "latency_ms": 520,
    "freshness_sec": 12,
    "is_partial": false,
    "error": null
  }
}
```

---

## 5. API Key 权限策略

## 5.1 第一阶段 API Key

```text
只读 Key：用于行情、账户状态、订单同步。
交易 Key：仅供 Freqtrade dry-run/live_small 使用。
提现权限：永远禁止。
IP 白名单：强制建议。
子账户：建议 live_small 使用独立子账户。
```

## 5.2 权限隔离

```text
PulseDesk 后端不应把交易所 secret 暴露给 AI Quant Core。
MCP Server 不得读取 secret。
Cloud LLM 请求不得包含 secret。
交易 Key 只允许 Freqtrade Adapter 访问。
```

---

## 6. Rate Limit 与重试

### 6.1 统一限流层

```text
ExchangeRateLimiter
├── per_exchange
├── per_endpoint
├── per_api_key
└── burst_control
```

### 6.2 重试策略

```text
HTTP 429：指数退避，不立即重试。
5xx：有限重试。
认证错误：不重试，进入 degraded。
数据过期：输出 data_quality=stale，不生成强交易 Signal。
```

---

## 7. Reconciliation 数据源优先级

恢复联通时，真理源顺序：

```text
1. Freqtrade REST open trades / closed trades / orders
2. Exchange account / order read-only API
3. Freqtrade local DB
4. PulseDesk local DB
```

规则：

```text
Freqtrade / Exchange 状态优先覆盖 PulseDesk 本地状态。
PulseDesk 不能用旧状态下发新 TradeIntent。
差异无法自动解决时进入 manual_review_required。
```

---

## 8. 交易所直连功能阶段规划

### Phase A：只读公共数据

```text
OHLCV
order book
funding rate
open interest
exchange status
```

### Phase B：只读账户数据

```text
balances
orders
positions
fees
```

### Phase C：应急人工流程

```text
EmergencyStop 页面提示
人工确认后允许特殊 direct exchange close 流程
所有操作写 Execution Ledger
默认不开放
```

---

## 9. 默认开发假设

除非用户另行指定，开发 AI 必须按以下假设实现：

```text
1. 第一阶段交易所：Binance 或 OKX 二选一，默认 Binance。
2. 第一阶段交易类型：现货。
3. 第一阶段执行模式：backtest + dry-run。
4. 合约数据：只读，用于操控雷达，不用于执行。
5. 所有交易执行：只走 Freqtrade。
6. 所有交易所原生 API：只读，除非后续人工确认 emergency flow。
```

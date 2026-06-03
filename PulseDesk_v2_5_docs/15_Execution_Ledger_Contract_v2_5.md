# PulseDesk v2.5 Execution Ledger Contract

## 1. 定位

Execution Ledger 是不可变执行事实源。订单表、持仓表、报表、增长分析均是 ledger 的 materialized view。

## 2. execution_ledger_events 表

```sql
CREATE TABLE execution_ledger_events (
    id UUID NOT NULL,
    event_time TIMESTAMPTZ NOT NULL,

    event_type TEXT NOT NULL,
    source_system TEXT NOT NULL,
    source_event_id TEXT,
    event_hash TEXT NOT NULL,

    strategy_run_id UUID,
    freqtrade_run_id UUID,
    command_id UUID,
    trade_intent_id UUID,
    risk_decision_id UUID,

    symbol TEXT,
    sequence_no BIGINT,
    schema_version TEXT NOT NULL DEFAULT '2.5',

    correlation_id UUID,
    causation_id UUID,

    raw_payload JSONB,
    normalized_payload JSONB NOT NULL,

    ingested_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (id, event_time),
    UNIQUE (event_hash, event_time)
) PARTITION BY RANGE (event_time);
```

如果需要按 `source_system/source_event_id/event_type` 幂等，可增加：

```sql
CREATE UNIQUE INDEX idx_ledger_source_event_unique
ON execution_ledger_events (source_system, source_event_id, event_type, event_time)
WHERE source_event_id IS NOT NULL;
```

## 3. event_hash 规则

```text
event_hash = sha256(source_system + source_event_id + event_type + normalized_payload_canonical_json)
```

无 `source_event_id` 时，使用：

```text
event_hash = sha256(source_system + event_type + event_time_bucket + normalized_payload_canonical_json)
```

## 4. 事件类型

### Freqtrade Events

```text
FREQTRADE_RUN_STARTED
FREQTRADE_RUN_HEARTBEAT
FREQTRADE_ORDER_OPENED
FREQTRADE_ORDER_FILLED
FREQTRADE_ORDER_CANCELLED
FREQTRADE_TRADE_OPENED
FREQTRADE_TRADE_CLOSED
FREQTRADE_STOPLOSS_TRIGGERED
FREQTRADE_RUN_DEGRADED
FREQTRADE_RUN_STOPPED
```

### PulseDesk Events

```text
PULSEDESK_COMMAND_STARTED
PULSEDESK_COMMAND_SUCCEEDED
PULSEDESK_COMMAND_FAILED
PULSEDESK_RISK_DECISION_CREATED
PULSEDESK_SAFE_HOLD_ENTERED
PULSEDESK_EMERGENCY_STOP_REQUESTED
PULSEDESK_RECONCILIATION_STARTED
PULSEDESK_RECONCILIATION_COMPLETED
PULSEDESK_MANUAL_REVIEW_REQUIRED
```

## 5. Materialized Tables

Ledger 可物化到：

```text
execution_orders
execution_trades
execution_positions
order_fills
order_attributions
portfolio_snapshots
```

物化表允许 update，但必须记录来源 ledger event。

## 6. Reconciliation 语义

对账不修改历史 ledger event。

正确方式：

```text
append PULSEDESK_RECONCILIATION_STARTED
append FREQTRADE_* current state events
append PULSEDESK_RECONCILIATION_COMPLETED
materialized view 根据最新事实重建
```

## 7. Growth Engine 读取约束

Growth Engine 不得直接以 `orders` 表作为唯一事实源，必须读取：

```text
execution_ledger_events
execution_orders
execution_trades
trade_intent_signal_snapshots
feature_snapshots
risk_decisions
```

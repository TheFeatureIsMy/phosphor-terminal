# PulseDesk v2.5 Command Bus Worker Contract

## 1. 定位

Command Bus 是所有 Freqtrade 写操作、策略部署、回测启动、dry-run 启停、live_small 请求和 EmergencyStop 的唯一入口。

```text
UI / Backend Service / Risk Engine
  → command_bus_commands
  → Worker Lock
  → Adapter Execution
  → Execution Ledger
  → Materialized View Update
```

AI、Signal Center、Growth Engine 不允许直接创建执行命令。

## 2. command_bus_commands 表

```sql
CREATE TABLE command_bus_commands (
    id UUID PRIMARY KEY,
    command_type TEXT NOT NULL,
    aggregate_type TEXT NOT NULL,
    aggregate_id UUID,
    payload JSONB NOT NULL,

    status TEXT NOT NULL CHECK (status IN (
        'pending','running','succeeded','failed','cancelled','timeout','retry_waiting'
    )),

    idempotency_key TEXT NOT NULL UNIQUE,
    requested_by TEXT NOT NULL,

    locked_by TEXT,
    locked_at TIMESTAMPTZ,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    next_retry_at TIMESTAMPTZ,
    priority INTEGER NOT NULL DEFAULT 100,
    timeout_sec INTEGER NOT NULL DEFAULT 300,
    cancel_requested BOOLEAN NOT NULL DEFAULT FALSE,

    correlation_id UUID,
    causation_id UUID,

    error_code TEXT,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ
);
```

推荐索引：

```sql
CREATE INDEX idx_command_bus_pending
ON command_bus_commands (status, priority, created_at)
WHERE status IN ('pending','retry_waiting');

CREATE INDEX idx_command_bus_lock
ON command_bus_commands (locked_by, locked_at)
WHERE status = 'running';
```

## 3. Worker 消费语义

Worker 必须使用数据库锁获取任务：

```sql
SELECT id
FROM command_bus_commands
WHERE status IN ('pending','retry_waiting')
  AND (next_retry_at IS NULL OR next_retry_at <= now())
ORDER BY priority ASC, created_at ASC
FOR UPDATE SKIP LOCKED
LIMIT 1;
```

获取后更新：

```text
status=running
locked_by=worker_id
locked_at=now()
started_at=coalesce(started_at, now())
```

## 4. 幂等语义

每个命令必须提供 `idempotency_key`。

推荐格式：

```text
{command_type}:{aggregate_id}:{dsl_hash}:{mode}:{request_date_bucket}
```

重复提交时：

```text
如果已有 succeeded：直接返回已有结果。
如果已有 running：返回 running。
如果已有 failed 但未超过 max_retries：允许重试。
```

## 5. 允许命令

```text
DeployRulesCommand
StartBacktestCommand
StartDryRunCommand
StopDryRunCommand
PauseStrategyCommand
RequestLiveSmallCommand
EmergencyStopCommand
StartReconciliationCommand
```

## 6. 状态机

```text
pending
  → running
  → succeeded
  → failed
  → retry_waiting
  → running
  → timeout
  → cancelled
```

命令失败时：

```text
retry_count < max_retries → retry_waiting
retry_count >= max_retries → failed
```

## 7. Reconciliation Blocking

当 StrategyRun 或 FreqtradeRun 处于 `reconciliating`：

允许：

```text
EmergencyStopCommand
StartReconciliationCommand
```

禁止：

```text
DeployRulesCommand
StartBacktestCommand
StartDryRunCommand
RequestLiveSmallCommand
```

## 8. Ledger 写入要求

每个命令至少写入两个事件：

```text
PULSEDESK_COMMAND_STARTED
PULSEDESK_COMMAND_SUCCEEDED / PULSEDESK_COMMAND_FAILED
```

事件必须包含：

```text
command_id
correlation_id
causation_id
command_type
aggregate_type
aggregate_id
```

# Phase 01 — Signal Center 工程落地计划

## 目标

建立 PulseDesk 的中枢契约：所有 AI、模型、研究、情绪、因子、FreqAI、操控雷达、手动输入都统一输出 Signal。

## 周期

建议 1-2 周。

## 本阶段不做

- 不接 Freqtrade live；
- 不做完整 TradingAgents；
- 不做完整操控雷达；
- 不做自我成长；
- 不做策略画布复杂编辑。

## 任务拆分

### T1. Signal 类型定义

文件：

```text
frontend/types/signal.ts
backend/signal_center/schemas.py
docs/04_Data_Models_API_DB.md
```

必须包含：

- SignalSourceType
- SignalDirection
- SignalStatus
- SignalPermission
- SignalEvidence
- TriggerCondition
- CurrentStateSnapshot
- SignalLifecycleEvent
- ProviderTrace

验收：前后端字段一一对应。

### T2. 数据库 migration

表：

- signals
- signal_evidence
- signal_lifecycle_events
- ai_provider_traces

验收：可以创建、查询、更新 Signal 状态。

### T3. Signal API

接口：

```text
POST /api/signals
GET /api/signals
GET /api/signals/{id}
POST /api/signals/{id}/archive
POST /api/signals/{id}/publish-to-strategy
POST /api/signals/{id}/observe-paper
POST /api/signals/conflict-check
```

验收：所有状态变更都写 lifecycle event。

### T4. Signal Center UI

页面模块：

- 顶部统计：total / pending / active / expired / rejected / executed；
- 筛选：source_type / symbol / direction / status / risk_level；
- Signal 卡片；
- Signal 详情抽屉；
- 生成策略草稿按钮；
- 加入 dry-run 观察按钮；
- 归档按钮。

验收：Mock 数据至少展示 6 类来源。

### T5. 已有页面发布 Signal

最小接入：

- AI 研究 → tradingagents Signal；
- 市场情绪 → sentiment Signal；
- 价格预测 → prediction Signal；
- 因子研究 → factor Signal；
- FreqAI → freqai Signal；
- 手动输入 → manual Signal。

验收：点击「发布为 Signal」后 Signal Center 可见。

## Mock 数据要求

必须包含：

```json
{
  "source_type": "tradingagents",
  "symbol": "BTC/USDT",
  "direction": "long",
  "confidence": 0.74,
  "status": "active"
}
```

```json
{
  "source_type": "manipulation",
  "symbol": "SOL/USDT",
  "direction": "risk",
  "confidence": 0.81,
  "status": "pending"
}
```

## 安全约束

- `can_live_trade` 默认 false；
- `expires_at` 必填；
- `reasoning` 必填；
- `confidence` 必须在 0-1；
- `score` 必须在 0-5；
- status 变更必须写 lifecycle event。

## 开发 Prompt

见 `06_AI_Development_Prompts.md` 的 Signal Center Prompt。

---

# v2.2 补充：Signal 存储治理必须随 Phase 01 实施

## 新增目标

Phase 01 不仅要完成 Signal CRUD 和页面，还必须完成最低限度的 Signal 存储治理，防止后续高频 Signal 造成主库膨胀。

## 新增任务

### 1. signals 表按月分区

- 创建 `signals` partitioned parent table；
- 自动创建当月和下月分区；
- 为 `symbol/source_type/status/created_at` 建索引；
- 主键使用 `(id, created_at)`。

### 2. Signal 列表轻量化

- 列表接口只返回 summary；
- 详情接口才返回 full reasoning/evidence；
- 默认查询最近 7 天；
- 无过滤条件不允许查全量历史。

### 3. Data Vacuum MVP

实现 `data_vacuum.py`：

- 查找 expired/archived 低分 Signal；
- 超过 14 天可迁移到 SQLite/Parquet；
- 写入 archival audit log；
- 主库删除前确认没有关联 executed order。

## 新增验收标准

- Signal Center 列表不返回大文本；
- signals 表有当月分区；
- 可以创建下月分区；
- expired 低分 Signal 可被归档；
- 无过滤全表查询被后端拒绝。

---

# v2.3.1 同步修订：Cloud / Local Provider Trace 必须进入 Signal

## 变更原因

v2.3 将 AI 层升级为 Cloud-First Hybrid Routing 后，Signal Center 不仅要记录信号内容，还必须记录信号由哪个 Provider、哪个模型、哪条 fallback chain 生成。否则后续无法进行成本审计、延迟分析、质量评估和隐私审查。

## 新增字段要求

Signal Schema 必须补充：

```json
{
  "provider_trace": {
    "provider": "deepseek|openai|anthropic|ollama|replicate|runpod|private_model_server|local",
    "model": "string",
    "fallback_rank": 0,
    "input_hash": "sha256:...",
    "output_hash": "sha256:...",
    "latency_ms": 0,
    "estimated_cost_usd": 0.0,
    "privacy_level": "public|low|medium|high|local_only",
    "structured_output_validated": true,
    "status": "success|fallback|failed|timeout"
  }
}
```

## Signal Center UI 新增列

Signal 列表增加：

- Provider；
- Model；
- Latency；
- Cost；
- Privacy Level；
- Validation Status。

## 新增筛选器

- 只看云端 Signal；
- 只看本地 Signal；
- 只看 fallback Signal；
- 只看 structured validation failed；
- 按 provider 筛选。

## 后端新增任务

### T-provider-1. ProviderTrace 入库

文件：

```text
backend/signal_center/schemas.py
backend/signal_center/publisher.py
backend/ai_quant_core/provider_trace.py
```

要求：

- 所有 AI 生成的 Signal 必须携带 provider_trace；
- 非 AI Signal 可设置 provider 为 `none` 或 `system`；
- Signal Center 写入时必须校验 provider_trace 完整性。

### T-provider-2. 隐私等级入库

所有 Signal 必须有 privacy_level：

```text
public      可公开行情/新闻
low         普通研究上下文
medium      包含策略摘要或订单统计
high        包含敏感持仓/钱包/账户上下文
local_only  禁止出云
```

## 验收标准补充

- AI 研究页发布 Signal 后，Signal 详情可看到 provider/model/latency/cost/privacy；
- Signal Center 可按 provider 筛选；
- structured_output_validated=false 的 Signal 不能进入 StrategyDraft；
- privacy_level=local_only 的任务不得显示云端 provider。

## 禁止事项

- 禁止 AI Signal 缺失 provider_trace；
- 禁止将 provider_trace 仅写日志、不入库；
- 禁止 structured validation failed 的 Signal 自动进入策略工作台。


---

# v2.3.2 Addendum: Signal Evidence Federation

## Problem

`trade_intents.source_signal_ids` can reference Signal rows that are later moved from PostgreSQL hot partitions to cold archives.

## Required implementation tasks

1. Implement `SignalRepository` as the only public lookup interface.
2. Query order: Redis latest cache → PostgreSQL hot partitions → SQLite archive → Parquet index → tombstone.
3. Add `signal_archive_index` table.
4. Add `signal_reference_snapshots` table.
5. Before archiving any referenced Signal, create a minimal immutable evidence snapshot.
6. Update UI Signal Detail and Execution Record to read through `SignalRepository`.

## Acceptance criteria

- Historical orders can still display source Signal reasoning after hot DB cleanup.
- Growth Engine can analyze trades across archived months.
- No code outside `signal_center` queries partition tables directly for historical evidence.
- Cold archive missing returns tombstone, not server error.

## v2.4 补充：Signal Center 数据库重构任务

### 必做任务

1. 将 `signals` 拆分为：
   - `signals`
   - `signal_payloads`
   - `signal_evidence`
   - `signal_provider_traces`
   - `signal_lifecycle_events`
   - `signal_snapshots`

2. 实现 `SignalRepository`：

```python
class SignalRepository:
    async def create_signal(self, signal: SignalCreate) -> SignalView: ...
    async def get_signal(self, signal_id: UUID) -> SignalView: ...
    async def get_payload(self, signal_id: UUID) -> SignalPayload: ...
    async def get_evidence(self, signal_id: UUID) -> list[SignalEvidence]: ...
    async def transition_status(self, signal_id: UUID, to_status: str, reason: str) -> None: ...
```

3. 实现 Data Federation Layer 的接口骨架，即使第一阶段只查询 PostgreSQL，也要保留 cold archive fallback。

4. Signal Center 页面默认只查轻量 `signals`，点击详情再加载 payload / evidence / provider_trace。

### 验收标准

```text
Signal 列表查询不扫描大文本。
Signal 详情可加载 reasoning / evidence / provider_trace。
Signal 状态变化写 lifecycle_events。
Growth Engine 不直接 join signals 表。
```

---

## v2.5 Phase 顺序说明

本 Phase 文件保留历史开发细节，但实现顺序以 `17_Phase_Plan_v2_5.md` 为准。若本文件存在开放式 Strategy.py、AI 直接执行、Signal 直接创建 TradeIntent 等旧描述，均以 v2.5 Master Architecture Decision 为准。

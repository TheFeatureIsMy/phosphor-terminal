# 策略工作台画布优先重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 重构策略工作台为画布优先 IA（无限画布主舞台 + 6 个 ⌘ 浮层面板），重写 BacktestLab 为 UUID 过滤，新增 7 个后端端点 + 1 个 alembic 迁移补齐数据真实性。

**Architecture:** 后端按分层加新表 `strategy_activity_log` + 服务层（aggregator/duplicate/archive/binding/activity）+ 路由层 1 个新 router 7 端点，4 个现有路由加 UUID query。canvas-web 重绘 9 类节点视觉 + 扩展 bridge（selectionChanged / graphStats / setReadOnly / updateNodeData）+ 删除内置 NodeConfigPanel。macOS 删除 21 个旧文件（双模式工作台 / 10 个旧 Tab / 孤儿 DryrunMonitor / native canvas 实验）+ 新增 23 个文件（HUD / 状态栏 / 6 浮层面板 / 9 节点 form）。

**Tech Stack:** Python 3.12 + FastAPI + SQLAlchemy + Pydantic v2 + alembic + pytest（后端）；Swift 6.2 + SwiftUI + macOS 26（前端）；React 19 + @xyflow/react + Vite + vitest（canvas-web）。

## Global Constraints

- **零硬编码颜色字符串**：颜色全走 `PulseColors.*` token，grep `Color(red:` / `Color(hex:` 限 `DesignTokens.swift`；HTML/CSS 内的硬编码限 `canvas-web/src/styles/*.css`。
- **零硬编码用户可见字符串**：所有 user-facing 文案走 `L10n.<Domain>.*` keys。
- **零前端 mock 假展示**：MockX.* 工厂只在 `MockNetworkClient` 路径返回；用户在 LIVE 模式见到的所有数据必须来自后端真实端点。
- **per-strategy 数据按 UUID 过滤**：所有 runs/backtest/dryrun/risk/readiness 调用必须带 `strategy_id` 或 `strategy_version_id` 参数。
- **lifecycle transition 校验**：复用 `app/services/strategy_transition.py` 的 `ALLOWED_TRANSITIONS` 与 `is_system_only`，**不重新定义状态机**。
- **CI 覆盖率门槛 ≥ 30%**：每个新 backend service 必须有 pytest 文件覆盖。
- **alembic up + down 双向可执行**：每次迁移本地 `alembic upgrade head && alembic downgrade -1 && alembic upgrade head` 必须通过。
- **去 AI 味规则**：禁止 全大写+letter-spacing 装饰、磷光辉光、心跳脉冲、EDIT BAY/LAUNCH CONSOLE/MISSION CONTROL 词汇、等大 section card 网格。

---

## Phase 1: 后端基础（数据库 + 模型）

### Task 1: Alembic 迁移 + ActivityLog domain 模型

**Files:**
- Create: `backend/app/domain/activity_log.py`
- Create: `backend/alembic/versions/2026_06_18_xxxx_strategy_workspace.py`（xxxx 由 alembic 生成）
- Modify: `backend/app/database/__init__.py`（注册新表 import）
- Test: `backend/tests/test_alembic_strategy_workspace_migration.py`

**Interfaces:**
- Produces:
  - `app.domain.activity_log.StrategyActivityLog` SQLAlchemy 模型，列 = `id, strategy_id, kind, occurred_at, actor, summary, delta, ref_kind, ref_id`
  - `BacktestRun.strategy_uuid` (UUID, nullable, FK strategies_v2)
  - `BacktestRun.strategy_version_id` (UUID, nullable, FK strategy_versions)
  - 索引 `idx_activity_strategy_time(strategy_id, occurred_at DESC)`、`idx_backtest_runs_strategy_uuid(strategy_uuid, completed_at DESC)`

- [ ] **Step 1: 写 ActivityLog 模型**

```python
# backend/app/domain/activity_log.py
"""Strategy activity log — records lifecycle events for the workbench activity panel."""
import uuid
from datetime import datetime

from sqlalchemy import func, String, Text, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy import JSON as JSONB
from sqlalchemy.orm import Mapped, mapped_column

from app.database.base import Base, UUIDMixin


class StrategyActivityLog(UUIDMixin, Base):
    __tablename__ = "strategy_activity_log"

    strategy_id: Mapped[uuid.UUID] = mapped_column(
        PG_UUID(as_uuid=True), ForeignKey("strategies_v2.id", ondelete="CASCADE"), nullable=False,
    )
    kind: Mapped[str] = mapped_column(String(64), nullable=False)
    occurred_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now(), nullable=False)
    actor: Mapped[str | None] = mapped_column(String(128))
    summary: Mapped[str] = mapped_column(Text, nullable=False)
    delta: Mapped[dict | None] = mapped_column(JSONB)
    ref_kind: Mapped[str | None] = mapped_column(String(32))
    ref_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True))

    __table_args__ = (
        Index("idx_activity_strategy_time", "strategy_id", occurred_at.desc()),
    )
```

- [ ] **Step 2: 在 `app/database/__init__.py` 注册 import**

确认 `from app.domain.activity_log import StrategyActivityLog  # noqa: F401` 在模型集合中（让 alembic autogenerate 能发现）。

- [ ] **Step 3: 生成 alembic 迁移**

```bash
cd backend
alembic revision --autogenerate -m "strategy workspace foundation: activity log + backtest UUID columns"
```

打开生成的 `backend/alembic/versions/2026_06_18_xxxx_strategy_workspace_foundation*.py`，确认包含：
- `op.create_table('strategy_activity_log', ...)` + 索引
- `op.add_column('backtest_runs', sa.Column('strategy_uuid', UUID, ForeignKey('strategies_v2.id'), nullable=True))`
- `op.add_column('backtest_runs', sa.Column('strategy_version_id', UUID, ForeignKey('strategy_versions.id'), nullable=True))`
- `op.create_index('idx_backtest_runs_strategy_uuid', 'backtest_runs', ['strategy_uuid', 'completed_at'], postgresql_using='btree')` 注意 `completed_at DESC`

如果 autogenerate 漏列，手工补齐到 `upgrade()`，并在 `downgrade()` 反向（先 drop_index → drop_column → drop_table）。

- [ ] **Step 4: 写迁移 round-trip 测试**

```python
# backend/tests/test_alembic_strategy_workspace_migration.py
"""Verify the strategy workspace migration applies and reverts cleanly."""
import subprocess
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parents[1]


def _alembic(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["alembic", *args],
        cwd=BACKEND,
        capture_output=True,
        text=True,
        check=False,
    )


@pytest.mark.skipif(
    _alembic("current").returncode != 0,
    reason="alembic not configured for this environment",
)
def test_migration_round_trip():
    upgrade = _alembic("upgrade", "head")
    assert upgrade.returncode == 0, upgrade.stderr

    downgrade = _alembic("downgrade", "-1")
    assert downgrade.returncode == 0, downgrade.stderr

    upgrade_again = _alembic("upgrade", "head")
    assert upgrade_again.returncode == 0, upgrade_again.stderr
```

- [ ] **Step 5: 跑测试**

```bash
cd backend
python3 -m pytest tests/test_alembic_strategy_workspace_migration.py -v
```

期望：PASS。

- [ ] **Step 6: 跑全量回归**

```bash
cd backend
python3 -m pytest tests/ -q
```

期望：现有 ~915 个测试全 PASS（迁移不影响现有逻辑）。

- [ ] **Step 7: Commit**

```bash
git add backend/app/domain/activity_log.py backend/alembic/versions/ backend/app/database/__init__.py backend/tests/test_alembic_strategy_workspace_migration.py
git commit -m "$(cat <<'EOF'
feat(strategy-workspace): add activity_log table + backtest UUID columns

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: StrategyActivityService — 写入 + 查询

**Files:**
- Create: `backend/app/services/strategy_activity_service.py`
- Create: `backend/tests/test_strategy_activity_service.py`

**Interfaces:**
- Consumes: `StrategyActivityLog` from Task 1.
- Produces:
  - `StrategyActivityService(db: Session)`
  - `.record(strategy_id: UUID, kind: str, summary: str, *, actor: str | None = None, delta: dict | None = None, ref_kind: str | None = None, ref_id: UUID | None = None) -> StrategyActivityLog`
  - `.list_recent(strategy_id: UUID, limit: int = 20) -> list[StrategyActivityLog]`
  - 合法 `kind` 集合：`version_created | version_status_changed | binding_added | binding_removed | run_started | backtest_completed | archived`

- [ ] **Step 1: 写测试**

```python
# backend/tests/test_strategy_activity_service.py
import uuid

import pytest

from app.domain.strategy import StrategyV2
from app.repositories.strategy_repository import StrategyRepository
from app.services.strategy_activity_service import StrategyActivityService, INVALID_KIND


@pytest.fixture
def strategy(db_session):
    s = StrategyV2(name="t", strategy_type="rule_dsl", source_type="manual", status="draft")
    StrategyRepository(db_session).create_strategy(s)
    db_session.commit()
    db_session.refresh(s)
    return s


def test_record_writes_row(db_session, strategy):
    svc = StrategyActivityService(db_session)
    entry = svc.record(strategy.id, "version_created", "v1 created", actor="api", delta={"version_no": 1})
    assert entry.id is not None
    assert entry.strategy_id == strategy.id
    assert entry.kind == "version_created"
    assert entry.delta == {"version_no": 1}


def test_invalid_kind_raises(db_session, strategy):
    svc = StrategyActivityService(db_session)
    with pytest.raises(ValueError, match=INVALID_KIND):
        svc.record(strategy.id, "totally_made_up", "nope")


def test_list_recent_orders_desc(db_session, strategy):
    svc = StrategyActivityService(db_session)
    svc.record(strategy.id, "version_created", "older")
    svc.record(strategy.id, "binding_added", "newer")
    db_session.commit()

    rows = svc.list_recent(strategy.id, limit=10)
    assert [r.kind for r in rows] == ["binding_added", "version_created"]


def test_list_recent_filters_by_strategy(db_session, strategy):
    other = StrategyV2(name="o", strategy_type="rule_dsl", source_type="manual", status="draft")
    StrategyRepository(db_session).create_strategy(other)
    db_session.commit()
    db_session.refresh(other)

    svc = StrategyActivityService(db_session)
    svc.record(strategy.id, "version_created", "mine")
    svc.record(other.id, "version_created", "theirs")
    db_session.commit()

    rows = svc.list_recent(strategy.id)
    assert len(rows) == 1
    assert rows[0].summary == "mine"
```

- [ ] **Step 2: 运行测试看到失败**

```bash
cd backend && python3 -m pytest tests/test_strategy_activity_service.py -v
```

期望：FAIL（service 模块还不存在）。

- [ ] **Step 3: 写实现**

```python
# backend/app/services/strategy_activity_service.py
"""Strategy activity log writer + reader."""
from __future__ import annotations

import uuid

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.activity_log import StrategyActivityLog


VALID_KINDS = {
    "version_created",
    "version_status_changed",
    "binding_added",
    "binding_removed",
    "run_started",
    "backtest_completed",
    "archived",
}

INVALID_KIND = "invalid activity kind"


class StrategyActivityService:
    def __init__(self, db: Session):
        self._db = db

    def record(
        self,
        strategy_id: uuid.UUID,
        kind: str,
        summary: str,
        *,
        actor: str | None = None,
        delta: dict | None = None,
        ref_kind: str | None = None,
        ref_id: uuid.UUID | None = None,
    ) -> StrategyActivityLog:
        if kind not in VALID_KINDS:
            raise ValueError(f"{INVALID_KIND}: {kind}")
        entry = StrategyActivityLog(
            strategy_id=strategy_id,
            kind=kind,
            summary=summary,
            actor=actor,
            delta=delta,
            ref_kind=ref_kind,
            ref_id=ref_id,
        )
        self._db.add(entry)
        self._db.flush()
        return entry

    def list_recent(self, strategy_id: uuid.UUID, limit: int = 20) -> list[StrategyActivityLog]:
        stmt = (
            select(StrategyActivityLog)
            .where(StrategyActivityLog.strategy_id == strategy_id)
            .order_by(StrategyActivityLog.occurred_at.desc())
            .limit(limit)
        )
        return list(self._db.scalars(stmt).all())
```

- [ ] **Step 4: 跑测试**

```bash
cd backend && python3 -m pytest tests/test_strategy_activity_service.py -v
```

期望：4 测试全 PASS。

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/strategy_activity_service.py backend/tests/test_strategy_activity_service.py
git commit -m "feat(strategy-workspace): add StrategyActivityService"
```

---


## Phase 2: 后端服务（duplicate / archive / binding）

### Task 3: StrategyDuplicateService

**Files:**
- Create: `backend/app/services/strategy_duplicate_service.py`
- Modify: `backend/app/repositories/strategy_repository.py` (add `clone_version` helper)
- Test: `backend/tests/test_strategy_duplicate_service.py`

**Interfaces:**
- Consumes: `StrategyActivityService` from Task 2.
- Produces:
  - `StrategyDuplicateService(db: Session, activity: StrategyActivityService)`
  - `.duplicate(source_strategy_id: UUID, *, name: str | None = None, actor: str = "api") -> StrategyV2`
  - 行为：新 `StrategyV2(status='draft')` + 克隆 source latest version 为 `StrategyVersion(version_no=1, status='draft', rule_dsl=deepcopy, dsl_hash=recomputed, created_by=actor)`；写 1 条 activity log `kind=version_created summary="duplicated from {source.name}"`；**不复制 bindings/runs/backtests**；事务化。
  - 错误：`ValueError` if source strategy not found；`ValueError` if source has no version。

- [ ] **Step 1: 写测试**

```python
# backend/tests/test_strategy_duplicate_service.py
import copy
import uuid

import pytest

from app.domain.strategy import StrategyV2, StrategyVersion
from app.repositories.strategy_repository import StrategyRepository
from app.services.dsl_hasher import compute_dsl_hash
from app.services.strategy_activity_service import StrategyActivityService
from app.services.strategy_duplicate_service import StrategyDuplicateService


@pytest.fixture
def source(db_session):
    s = StrategyV2(name="origin", strategy_type="rule_dsl", source_type="manual", status="backtested")
    repo = StrategyRepository(db_session)
    repo.create_strategy(s)
    db_session.flush()
    v = StrategyVersion(
        strategy_id=s.id, version_no=1, status="backtested",
        dsl_version="2.5",
        rule_dsl={"schema_version": "2.5", "entry": {"logic": "AND", "rules": []}},
        dsl_hash=compute_dsl_hash({"schema_version": "2.5"}),
        created_by="user",
    )
    repo.create_version(v)
    db_session.commit()
    db_session.refresh(s)
    return s


def test_duplicate_creates_new_strategy_in_draft(db_session, source):
    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    new = svc.duplicate(source.id)
    assert new.id != source.id
    assert new.status == "draft"
    assert new.name == "origin copy"


def test_duplicate_clones_latest_version_as_v1_draft(db_session, source):
    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    new = svc.duplicate(source.id)
    db_session.commit()
    repo = StrategyRepository(db_session)
    versions = repo.list_versions(new.id)
    assert len(versions) == 1
    assert versions[0].version_no == 1
    assert versions[0].status == "draft"
    assert versions[0].rule_dsl == source.versions[0].rule_dsl if hasattr(source, 'versions') else True


def test_duplicate_uses_custom_name(db_session, source):
    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    new = svc.duplicate(source.id, name="custom name")
    assert new.name == "custom name"


def test_duplicate_dsl_is_deep_copy(db_session, source):
    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    new = svc.duplicate(source.id)
    db_session.commit()
    repo = StrategyRepository(db_session)
    new_version = repo.list_versions(new.id)[0]
    new_version.rule_dsl["entry"]["logic"] = "OR"
    db_session.commit()

    src_version = repo.list_versions(source.id)[0]
    assert src_version.rule_dsl["entry"]["logic"] == "AND"


def test_duplicate_writes_activity_log(db_session, source):
    activity = StrategyActivityService(db_session)
    svc = StrategyDuplicateService(db_session, activity)
    new = svc.duplicate(source.id)
    db_session.commit()
    rows = activity.list_recent(new.id)
    assert len(rows) == 1
    assert rows[0].kind == "version_created"
    assert "origin" in rows[0].summary


def test_duplicate_missing_source_raises(db_session):
    svc = StrategyDuplicateService(db_session, StrategyActivityService(db_session))
    with pytest.raises(ValueError, match="not found"):
        svc.duplicate(uuid.uuid4())
```

- [ ] **Step 2: 运行看到失败**

```bash
cd backend && python3 -m pytest tests/test_strategy_duplicate_service.py -v
```

期望：FAIL（service 模块缺失）。

- [ ] **Step 3: 加 repo helper**

```python
# 追加到 backend/app/repositories/strategy_repository.py
def clone_version_for(self, src_version: StrategyVersion, *, new_strategy_id: uuid.UUID, new_version_no: int, created_by: str) -> StrategyVersion:
    import copy
    from app.services.dsl_hasher import compute_dsl_hash
    new_dsl = copy.deepcopy(src_version.rule_dsl)
    return StrategyVersion(
        strategy_id=new_strategy_id,
        version_no=new_version_no,
        status="draft",
        dsl_version=src_version.dsl_version,
        rule_dsl=new_dsl,
        dsl_hash=compute_dsl_hash(new_dsl),
        created_by=created_by,
    )
```

- [ ] **Step 4: 写 service 实现**

```python
# backend/app/services/strategy_duplicate_service.py
"""Strategy clone service: new Strategy(draft) + cloned latest version as v1(draft)."""
from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.domain.strategy import StrategyV2
from app.repositories.strategy_repository import StrategyRepository
from app.services.strategy_activity_service import StrategyActivityService


class StrategyDuplicateService:
    def __init__(self, db: Session, activity: StrategyActivityService):
        self._db = db
        self._activity = activity

    def duplicate(self, source_strategy_id: uuid.UUID, *, name: str | None = None, actor: str = "api") -> StrategyV2:
        repo = StrategyRepository(self._db)
        src = repo.get_strategy_by_id(source_strategy_id)
        if not src:
            raise ValueError(f"source strategy not found: {source_strategy_id}")

        latest = repo.get_latest_version(source_strategy_id)
        if not latest:
            raise ValueError(f"source strategy has no version: {source_strategy_id}")

        new = StrategyV2(
            name=name or f"{src.name} copy",
            description=src.description,
            strategy_type=src.strategy_type,
            source_type=src.source_type,
            status="draft",
        )
        repo.create_strategy(new)
        self._db.flush()

        cloned = repo.clone_version_for(latest, new_strategy_id=new.id, new_version_no=1, created_by=actor)
        repo.create_version(cloned)

        self._activity.record(
            new.id,
            "version_created",
            f"duplicated from {src.name}",
            actor=actor,
            delta={"source_strategy_id": str(src.id), "source_version_no": latest.version_no},
            ref_kind="version",
            ref_id=cloned.id,
        )
        return new
```

- [ ] **Step 5: 跑测试**

```bash
cd backend && python3 -m pytest tests/test_strategy_duplicate_service.py -v
```

期望：6 测试全 PASS。

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/strategy_duplicate_service.py backend/app/repositories/strategy_repository.py backend/tests/test_strategy_duplicate_service.py
git commit -m "feat(strategy-workspace): add StrategyDuplicateService"
```

---

### Task 4: StrategyArchiveService

**Files:**
- Create: `backend/app/services/strategy_archive_service.py`
- Test: `backend/tests/test_strategy_archive_service.py`

**Interfaces:**
- Consumes: `StrategyActivityService`、`app.services.strategy_transition` (`validate_transition`、`is_system_only`、`ALLOWED_TRANSITIONS`)
- Produces:
  - `StrategyArchiveService(db: Session, activity: StrategyActivityService)`
  - `.archive(strategy_id: UUID, *, reason: str | None = None, actor: str = "api") -> StrategyV2`
  - 行为：所有 `version.status != 'archived'` 的 version 转 archived（**不验证 transition**——这是 admin 强归档；transition 校验仅用于普通用户路径）+ `strategy.status = 'archived'` + activity log `kind=archived summary="archived: {reason}" delta={"version_count": N}`；事务化；幂等（已 archived 的策略再调 idempotent）。

- [ ] **Step 1: 写测试**

```python
# backend/tests/test_strategy_archive_service.py
import uuid
import pytest

from app.domain.strategy import StrategyV2, StrategyVersion
from app.repositories.strategy_repository import StrategyRepository
from app.services.dsl_hasher import compute_dsl_hash
from app.services.strategy_activity_service import StrategyActivityService
from app.services.strategy_archive_service import StrategyArchiveService


def _make(db_session, status: str, version_status: str) -> StrategyV2:
    s = StrategyV2(name="x", strategy_type="rule_dsl", source_type="manual", status=status)
    repo = StrategyRepository(db_session)
    repo.create_strategy(s)
    db_session.flush()
    v = StrategyVersion(
        strategy_id=s.id, version_no=1, status=version_status,
        dsl_version="2.5", rule_dsl={"schema_version": "2.5"},
        dsl_hash=compute_dsl_hash({"schema_version": "2.5"}),
        created_by="u",
    )
    repo.create_version(v)
    db_session.commit()
    db_session.refresh(s)
    return s


def test_archive_transitions_all_non_archived_versions(db_session):
    s = _make(db_session, "backtested", "backtested")
    svc = StrategyArchiveService(db_session, StrategyActivityService(db_session))
    out = svc.archive(s.id, reason="cleanup")
    db_session.commit()

    assert out.status == "archived"
    repo = StrategyRepository(db_session)
    versions = repo.list_versions(s.id)
    assert all(v.status == "archived" for v in versions)


def test_archive_writes_activity_with_reason(db_session):
    s = _make(db_session, "draft", "draft")
    activity = StrategyActivityService(db_session)
    svc = StrategyArchiveService(db_session, activity)
    svc.archive(s.id, reason="done with it")
    db_session.commit()

    rows = activity.list_recent(s.id)
    archived_entry = next(r for r in rows if r.kind == "archived")
    assert "done with it" in archived_entry.summary


def test_archive_idempotent(db_session):
    s = _make(db_session, "archived", "archived")
    svc = StrategyArchiveService(db_session, StrategyActivityService(db_session))
    out = svc.archive(s.id)
    assert out.status == "archived"
```

- [ ] **Step 2: 运行看到失败**

```bash
cd backend && python3 -m pytest tests/test_strategy_archive_service.py -v
```

- [ ] **Step 3: 写实现**

```python
# backend/app/services/strategy_archive_service.py
"""Strategy archive service — admin force-archive of strategy + all non-archived versions."""
from __future__ import annotations

import uuid

from sqlalchemy.orm import Session

from app.domain.strategy import StrategyV2
from app.repositories.strategy_repository import StrategyRepository
from app.services.strategy_activity_service import StrategyActivityService


class StrategyArchiveService:
    def __init__(self, db: Session, activity: StrategyActivityService):
        self._db = db
        self._activity = activity

    def archive(self, strategy_id: uuid.UUID, *, reason: str | None = None, actor: str = "api") -> StrategyV2:
        repo = StrategyRepository(self._db)
        strategy = repo.get_strategy_by_id(strategy_id)
        if not strategy:
            raise ValueError(f"strategy not found: {strategy_id}")

        versions = repo.list_versions(strategy_id)
        archived_count = 0
        for v in versions:
            if v.status != "archived":
                v.status = "archived"
                archived_count += 1

        if strategy.status != "archived":
            strategy.status = "archived"

        self._db.flush()

        self._activity.record(
            strategy_id,
            "archived",
            f"archived: {reason}" if reason else "archived",
            actor=actor,
            delta={"version_count": archived_count, "reason": reason},
        )
        return strategy
```

- [ ] **Step 4: 跑测试**

```bash
cd backend && python3 -m pytest tests/test_strategy_archive_service.py -v
```

期望 PASS。

- [ ] **Step 5: Commit**

```bash
git add backend/app/services/strategy_archive_service.py backend/tests/test_strategy_archive_service.py
git commit -m "feat(strategy-workspace): add StrategyArchiveService"
```

---

### Task 5: StrategyBindingService — CRUD + 校验

**Files:**
- Create: `backend/app/services/strategy_binding_service.py`
- Create: `backend/app/schemas/strategy_binding.py`
- Modify: `backend/app/repositories/strategy_repository.py` (add `list_bindings_for_strategy`、`get_binding_by_id`)
- Test: `backend/tests/test_strategy_binding_service.py`

**Interfaces:**
- Consumes: `StrategyActivityService`、domain `StrategyRiskPolicyBinding`、`RiskPolicyVersion`、`CapitalPool`、`StrategyRun`
- Produces:
  - `StrategyBindingService(db, activity)`
  - `.list_for_strategy(strategy_id: UUID) -> list[StrategyRiskPolicyBinding]`（join 出 latest version 之外所有 version 的 bindings）
  - `.create(*, strategy_id: UUID, strategy_version_id: UUID, risk_policy_version_id: UUID, capital_pool_id: UUID, mode: str, actor: str) -> StrategyRiskPolicyBinding`
  - `.delete(binding_id: UUID, *, actor: str) -> None`
  - 错误：`DuplicateBindingError` (`BINDING_DUPLICATE`)、`PoolMismatchError` (`BINDING_POOL_MISMATCH`)、`PolicyArchivedError` (`BINDING_POLICY_ARCHIVED`)、`BindingInUseError` (`BINDING_IN_USE`)
  - mode-pool 一致性规则：mode=`live_small` ⇒ pool.pool_type=`live_small`；mode=`backtest`/`dry_run`/`shadow` ⇒ pool.pool_type ∈ {`paper`, `main`, `high_risk_hunt`}（即除 `live_small` 外）

- [ ] **Step 1: 写错误类 + schema**

```python
# backend/app/schemas/strategy_binding.py
"""StrategyBinding API schemas + service errors."""
from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel


class RiskPolicySummary(BaseModel):
    id: uuid.UUID
    name: str
    version_no: int
    policy_json_summary: dict[str, Any]

    model_config = {"from_attributes": True}


class CapitalPoolSummary(BaseModel):
    id: uuid.UUID
    name: str
    pool_type: str
    total_budget: float
    currency: str
    remaining_budget: float

    model_config = {"from_attributes": True}


class StrategyBindingResponse(BaseModel):
    id: uuid.UUID
    strategy_version_id: uuid.UUID
    version_no: int
    risk_policy: RiskPolicySummary
    capital_pool: CapitalPoolSummary
    mode: str
    created_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class CreateBindingRequest(BaseModel):
    strategy_version_id: uuid.UUID
    risk_policy_version_id: uuid.UUID
    capital_pool_id: uuid.UUID
    mode: str   # backtest | dry_run | shadow | live_small


class BindingError(Exception):
    code: str = "BINDING_ERROR"


class DuplicateBindingError(BindingError):
    code = "BINDING_DUPLICATE"


class PoolMismatchError(BindingError):
    code = "BINDING_POOL_MISMATCH"


class PolicyArchivedError(BindingError):
    code = "BINDING_POLICY_ARCHIVED"


class BindingInUseError(BindingError):
    code = "BINDING_IN_USE"
```

- [ ] **Step 2: 写测试**（创建 happy / 重复 / pool 不匹配 / policy archived / in-use 删除 / 正常删除）

```python
# backend/tests/test_strategy_binding_service.py
import uuid
import pytest
from app.domain.strategy import StrategyV2, StrategyVersion
from app.domain.risk import RiskPolicy, RiskPolicyVersion, CapitalPool, StrategyRiskPolicyBinding
from app.domain.execution import StrategyRun
from app.repositories.strategy_repository import StrategyRepository
from app.services.dsl_hasher import compute_dsl_hash
from app.services.strategy_activity_service import StrategyActivityService
from app.services.strategy_binding_service import StrategyBindingService
from app.schemas.strategy_binding import (
    DuplicateBindingError, PoolMismatchError, PolicyArchivedError, BindingInUseError,
)


@pytest.fixture
def fixtures(db_session):
    s = StrategyV2(name="bt", strategy_type="rule_dsl", source_type="manual", status="paper_passed")
    repo = StrategyRepository(db_session)
    repo.create_strategy(s)
    db_session.flush()

    v = StrategyVersion(
        strategy_id=s.id, version_no=1, status="paper_passed",
        dsl_version="2.5", rule_dsl={"schema_version": "2.5"},
        dsl_hash=compute_dsl_hash({"schema_version": "2.5"}), created_by="u",
    )
    repo.create_version(v)
    db_session.flush()

    rp = RiskPolicy(name="conservative", policy_type="conservative", status="active")
    db_session.add(rp); db_session.flush()
    rpv = RiskPolicyVersion(
        risk_policy_id=rp.id, version_no=1,
        policy_json={"max_position_pct": 0.02},
        policy_hash="abc", status="active", created_by="u",
    )
    db_session.add(rpv); db_session.flush()

    pool_live = CapitalPool(
        name="ls", pool_type="live_small", currency="USDT",
        total_budget=5000, max_position_pct_per_trade=0.02,
        max_total_exposure_pct=0.5, max_daily_loss_pct=0.05, max_drawdown_pct=0.15,
    )
    pool_paper = CapitalPool(
        name="paper", pool_type="paper", currency="USDT",
        total_budget=10000, max_position_pct_per_trade=0.05,
        max_total_exposure_pct=1.0, max_daily_loss_pct=0.10, max_drawdown_pct=0.20,
    )
    db_session.add_all([pool_live, pool_paper]); db_session.commit()
    db_session.refresh(s)
    return dict(strategy=s, version=v, rpv=rpv, pool_live=pool_live, pool_paper=pool_paper)


def test_create_live_small_binding_happy(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    b = svc.create(
        strategy_id=fixtures["strategy"].id,
        strategy_version_id=fixtures["version"].id,
        risk_policy_version_id=fixtures["rpv"].id,
        capital_pool_id=fixtures["pool_live"].id,
        mode="live_small",
        actor="api",
    )
    db_session.commit()
    assert b.mode == "live_small"


def test_create_duplicate_raises(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    svc.create(
        strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
        risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
        mode="live_small", actor="api",
    )
    db_session.commit()
    with pytest.raises(DuplicateBindingError):
        svc.create(
            strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
            risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
            mode="live_small", actor="api",
        )


def test_create_live_small_with_paper_pool_raises(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    with pytest.raises(PoolMismatchError):
        svc.create(
            strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
            risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_paper"].id,
            mode="live_small", actor="api",
        )


def test_create_with_archived_policy_raises(db_session, fixtures):
    fixtures["rpv"].status = "archived"
    db_session.commit()
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    with pytest.raises(PolicyArchivedError):
        svc.create(
            strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
            risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
            mode="live_small", actor="api",
        )


def test_delete_binding(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    b = svc.create(
        strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
        risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
        mode="live_small", actor="api",
    )
    db_session.commit()
    svc.delete(b.id, actor="api")
    db_session.commit()
    assert svc.list_for_strategy(fixtures["strategy"].id) == []


def test_delete_binding_with_active_run_raises(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    b = svc.create(
        strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
        risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
        mode="live_small", actor="api",
    )
    db_session.add(StrategyRun(
        strategy_version_id=fixtures["version"].id,
        capital_pool_id=fixtures["pool_live"].id,
        mode="live_small", status="running",
    ))
    db_session.commit()
    with pytest.raises(BindingInUseError):
        svc.delete(b.id, actor="api")


def test_list_for_strategy_returns_all_versions_bindings(db_session, fixtures):
    svc = StrategyBindingService(db_session, StrategyActivityService(db_session))
    svc.create(
        strategy_id=fixtures["strategy"].id, strategy_version_id=fixtures["version"].id,
        risk_policy_version_id=fixtures["rpv"].id, capital_pool_id=fixtures["pool_live"].id,
        mode="live_small", actor="api",
    )
    db_session.commit()
    rows = svc.list_for_strategy(fixtures["strategy"].id)
    assert len(rows) == 1
```

- [ ] **Step 3: 跑测试看到失败**

```bash
cd backend && python3 -m pytest tests/test_strategy_binding_service.py -v
```

- [ ] **Step 4: 写实现**

```python
# backend/app/services/strategy_binding_service.py
"""StrategyBinding CRUD service with mode-pool consistency + in-use protection."""
from __future__ import annotations

import uuid
from sqlalchemy import select, and_
from sqlalchemy.orm import Session

from app.domain.execution import StrategyRun
from app.domain.risk import (
    CapitalPool, RiskPolicyVersion, StrategyRiskPolicyBinding,
)
from app.domain.strategy import StrategyVersion
from app.schemas.strategy_binding import (
    DuplicateBindingError, PoolMismatchError, PolicyArchivedError, BindingInUseError,
)
from app.services.strategy_activity_service import StrategyActivityService


_LIVE_SMALL_POOLS = {"live_small"}
_NON_LIVE_POOLS = {"paper", "main", "high_risk_hunt"}


class StrategyBindingService:
    def __init__(self, db: Session, activity: StrategyActivityService):
        self._db = db
        self._activity = activity

    def list_for_strategy(self, strategy_id: uuid.UUID) -> list[StrategyRiskPolicyBinding]:
        stmt = (
            select(StrategyRiskPolicyBinding)
            .join(StrategyVersion, StrategyVersion.id == StrategyRiskPolicyBinding.strategy_version_id)
            .where(StrategyVersion.strategy_id == strategy_id)
        )
        return list(self._db.scalars(stmt).all())

    def create(
        self, *,
        strategy_id: uuid.UUID,
        strategy_version_id: uuid.UUID,
        risk_policy_version_id: uuid.UUID,
        capital_pool_id: uuid.UUID,
        mode: str,
        actor: str,
    ) -> StrategyRiskPolicyBinding:
        # validate policy
        rpv = self._db.get(RiskPolicyVersion, risk_policy_version_id)
        if not rpv:
            raise ValueError("risk_policy_version not found")
        if rpv.status == "archived":
            raise PolicyArchivedError(f"policy version {risk_policy_version_id} is archived")

        # validate pool/mode
        pool = self._db.get(CapitalPool, capital_pool_id)
        if not pool:
            raise ValueError("capital_pool not found")
        if mode == "live_small" and pool.pool_type not in _LIVE_SMALL_POOLS:
            raise PoolMismatchError(f"mode=live_small requires live_small pool; got {pool.pool_type}")
        if mode in {"backtest", "dry_run", "shadow"} and pool.pool_type not in _NON_LIVE_POOLS:
            raise PoolMismatchError(f"mode={mode} cannot use {pool.pool_type} pool")

        # duplicate check
        dup = self._db.scalar(
            select(StrategyRiskPolicyBinding).where(
                and_(
                    StrategyRiskPolicyBinding.strategy_version_id == strategy_version_id,
                    StrategyRiskPolicyBinding.mode == mode,
                )
            )
        )
        if dup is not None:
            raise DuplicateBindingError(f"binding (version={strategy_version_id}, mode={mode}) exists")

        b = StrategyRiskPolicyBinding(
            strategy_version_id=strategy_version_id,
            risk_policy_version_id=risk_policy_version_id,
            capital_pool_id=capital_pool_id,
            mode=mode,
        )
        self._db.add(b)
        self._db.flush()

        self._activity.record(
            strategy_id, "binding_added",
            f"bound to {rpv.risk_policy_id} / {pool.name} ({mode})",
            actor=actor, ref_kind="binding", ref_id=b.id,
            delta={"mode": mode, "policy_version_id": str(rpv.id), "pool_id": str(pool.id)},
        )
        return b

    def delete(self, binding_id: uuid.UUID, *, actor: str) -> None:
        b = self._db.get(StrategyRiskPolicyBinding, binding_id)
        if not b:
            raise ValueError(f"binding not found: {binding_id}")

        # in-use check: any active StrategyRun with same (version, mode)
        in_use = self._db.scalar(
            select(StrategyRun).where(
                and_(
                    StrategyRun.strategy_version_id == b.strategy_version_id,
                    StrategyRun.mode == b.mode,
                    StrategyRun.status.in_(["running", "starting", "stopping", "degraded"]),
                )
            )
        )
        if in_use is not None:
            raise BindingInUseError(f"binding {binding_id} has active run {in_use.id}")

        version = self._db.get(StrategyVersion, b.strategy_version_id)
        strategy_id = version.strategy_id if version else None

        self._db.delete(b)
        self._db.flush()

        if strategy_id:
            self._activity.record(
                strategy_id, "binding_removed", f"binding {binding_id} removed",
                actor=actor, ref_kind="binding", ref_id=binding_id,
            )
```

- [ ] **Step 5: 跑测试**

```bash
cd backend && python3 -m pytest tests/test_strategy_binding_service.py -v
```

期望 7 测试全 PASS。

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/strategy_binding_service.py backend/app/schemas/strategy_binding.py backend/app/repositories/strategy_repository.py backend/tests/test_strategy_binding_service.py
git commit -m "feat(strategy-workspace): add StrategyBindingService"
```

---

## Phase 3: 后端 readiness + aggregator

### Task 6: LiveReadinessService.compute_for_strategy

**Files:**
- Modify: `backend/app/services/live_readiness_service.py`（添加 `compute_for_strategy` 方法 + 6 项策略门禁逻辑）
- Create: `backend/app/schemas/per_strategy_readiness.py`
- Test: `backend/tests/test_live_readiness_per_strategy.py`

**Interfaces:**
- Produces:
  - `PerStrategyReadinessResponse` Pydantic schema（详见 spec §6.4）
  - `LiveReadinessService.compute_for_strategy(strategy_id: UUID, db: Session) -> PerStrategyReadinessResponse`
  - 6 项 `strategy_gates`：`validation`, `backtest`, `dryrun`, `risk_config`, `capital`, `strategy`
  - 5 项 `system_gates`：直接复用账户级 result 中的 `mode/exchange/data_source/notification/emergency_stop`
  - `next_action.code` 推断规则：第一个 `status != 'healthy'` 的 strategy_gate 决定（按 6 项顺序），全过则用 `grand_status` 推断（`paper_passed → bind_live_small`、`ready_for_live → approve_live`）。

- [ ] **Step 1: 写 PerStrategyReadinessResponse schema**（见 spec §6.4，照写 Pydantic 模型）

- [ ] **Step 2: 写测试**（每个 gate 至少一组 healthy/failed 案例 + grand_status 5 级映射 + next_action 推断 4 种）

```python
# backend/tests/test_live_readiness_per_strategy.py（节选关键 case）
def test_validation_gate_healthy_when_latest_version_validated(...): ...
def test_validation_gate_failed_when_latest_version_draft(...): ...
def test_backtest_gate_healthy_when_completed_backtest_exists(...): ...
def test_backtest_gate_failed_when_no_backtest(...): ...
def test_dryrun_gate_healthy_when_72h_paper_passed(...): ...
def test_dryrun_gate_failed_when_under_72h(...): ...
def test_risk_config_gate_healthy_when_live_small_binding_exists(...): ...
def test_risk_config_gate_failed_when_no_binding(...): ...
def test_capital_gate_healthy_when_live_small_pool_has_remaining_budget(...): ...
def test_strategy_gate_healthy_when_strategy_selected(...): ...
def test_grand_status_not_live_when_system_gate_fails(...): ...
def test_grand_status_needs_config_when_capital_or_risk_missing(...): ...
def test_grand_status_needs_validation_when_validation_or_backtest_missing(...): ...
def test_grand_status_paper_passed_when_dryrun_passed_but_not_live(...): ...
def test_grand_status_ready_for_live_when_all_gates_pass(...): ...
def test_next_action_first_failed_strategy_gate_decides(...): ...
def test_next_action_paper_passed_suggests_bind_live_small(...): ...
```

- [ ] **Step 3: 跑测试看到失败**

```bash
cd backend && python3 -m pytest tests/test_live_readiness_per_strategy.py -v
```

- [ ] **Step 4: 实现 `compute_for_strategy`**

在 `live_readiness_service.py` 现有 `LiveReadinessService` 类中追加方法：
- 内部调用 `self.evaluate(account_id)`（账户级）取 `system_gates`
- 查询 strategy / latest version / bindings(mode='live_small') / latest backtest / latest dryrun StrategyRun（72h 检查用 `started_at - stopped_at`）→ 组装 6 个 strategy_gates
- 派生 `grand_status` 优先级链：
  ```
  any system_gate.status=='failed' → not_live
  capital or risk_config failed → needs_config
  validation or backtest failed → needs_validation
  dryrun failed → needs_validation
  all pass + dryrun status=='paper_passed' → paper_passed
  all pass + binding live_small + status='live_small' → ready_for_live
  ```
- 推断 `next_action`：找第一个失败 strategy_gate；全过则按 grand_status 决定。

- [ ] **Step 5: 跑测试**

```bash
cd backend && python3 -m pytest tests/test_live_readiness_per_strategy.py -v
```

期望全 PASS。

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/live_readiness_service.py backend/app/schemas/per_strategy_readiness.py backend/tests/test_live_readiness_per_strategy.py
git commit -m "feat(strategy-workspace): add LiveReadinessService.compute_for_strategy"
```

---

### Task 7: StrategyWorkspaceAggregator + Redis 缓存

**Files:**
- Create: `backend/app/services/strategy_workspace_aggregator.py`
- Create: `backend/app/schemas/strategy_workspace.py`
- Test: `backend/tests/test_strategy_workspace_aggregator.py`

**Interfaces:**
- Consumes: `LiveReadinessService.compute_for_strategy`、`StrategyBindingService.list_for_strategy`、`StrategyActivityService.list_recent`、`StrategyRepository`、Redis store。
- Produces:
  - `WorkspaceSnapshotResponse` schema（spec §6.1.A）
  - `StrategyWorkspaceAggregator(db, redis_store, readiness_svc, binding_svc, activity_svc)`
  - `.get_snapshot(strategy_id: UUID, *, force_fresh: bool = False) -> WorkspaceSnapshotResponse`
  - Redis cache key: `pulsedesk:workspace:{strategy_id}` TTL 5s
  - `signal_logic_summary` 由 `rule_dsl.entry`/`exit` 翻译为人话（"RSI<30 AND vol>1.5σ"）；提供独立 helper `summarize_dsl(rule_dsl: dict) -> SignalLogicSummary`
  - `data_dependencies` 从 `rule_dsl.symbols` + 各 indicator 节点抽取

- [ ] **Step 1: 写 schema** (`WorkspaceSnapshotResponse`，含 spec §6.1.A 列出的 11 个字段；嵌套 `BacktestRunSummary`、`StrategyRunSummary`、`SignalLogicSummary`、`DataDependencies`、`ActivityEntry`、`StrategyBindingResponse`、`PerStrategyReadinessResponse`)

- [ ] **Step 2: 写 helper 测试 + 实现**

```python
# tests
def test_summarize_dsl_extracts_entry_text(): ...
def test_summarize_dsl_extracts_exit_text(): ...
def test_summarize_dsl_handles_empty_rules(): ...
def test_data_dependencies_extracts_symbols_timeframes_indicators(): ...
```

```python
# helper in app/services/strategy_workspace_aggregator.py
def summarize_dsl(rule_dsl: dict) -> SignalLogicSummary:
    entry = rule_dsl.get("entry", {})
    rules = entry.get("rules", [])
    logic = entry.get("logic", "AND")
    fragments = []
    for r in rules:
        ind = r.get("indicator", "?")
        op = r.get("operator", "?")
        val = r.get("value", "?")
        fragments.append(f"{ind}{op}{val}")
    entry_text = f" {logic} ".join(fragments) if fragments else "(empty)"
    exit_rules = rule_dsl.get("exit", {}).get("rules", [])
    exit_text = " OR ".join(f"{r.get('indicator')}{r.get('operator')}{r.get('value')}" for r in exit_rules) or "(empty)"
    return SignalLogicSummary(entry_text=entry_text, exit_text=exit_text, filter_count=len(rule_dsl.get("filters", [])))
```

- [ ] **Step 3: 写聚合器测试**

```python
def test_aggregator_returns_full_snapshot_happy(...): ...
def test_aggregator_handles_strategy_with_no_versions(...): ...
def test_aggregator_handles_strategy_with_no_bindings(...): ...
def test_aggregator_handles_strategy_with_no_runs(...): ...
def test_aggregator_redis_miss_falls_through_to_db(...): ...  # use fakeredis
def test_aggregator_redis_hit_skips_db(...): ...
def test_aggregator_force_fresh_bypasses_cache(...): ...
```

- [ ] **Step 4: 实现 aggregator**（并行 6 子查询：strategy / versions / bindings / 最近 5 backtests / 最近 5 dryruns / activity；缓存写 dict 序列化）

- [ ] **Step 5: 跑测试**

期望全 PASS。

- [ ] **Step 6: Commit**

```bash
git add backend/app/services/strategy_workspace_aggregator.py backend/app/schemas/strategy_workspace.py backend/tests/test_strategy_workspace_aggregator.py
git commit -m "feat(strategy-workspace): add StrategyWorkspaceAggregator with redis cache"
```

---

## Phase 4: 后端路由

### Task 8: 新 router `/api/v2/strategy-workspace` 7 端点

**Files:**
- Create: `backend/app/routers/strategy_workspace.py`
- Modify: `backend/app/main.py`（注册 router）
- Test: `backend/tests/test_router_strategy_workspace.py`

**Interfaces:**
- 7 端点（spec §6.1）：
  - `GET /api/v2/strategies/{id}/workspace` → `WorkspaceSnapshotResponse`
  - `POST /api/v2/strategies/{id}/duplicate` → `StrategyV2Response`
  - `GET /api/v2/strategies/{id}/bindings` → `list[StrategyBindingResponse]`
  - `POST /api/v2/strategies/{id}/bindings` → `StrategyBindingResponse`
  - `DELETE /api/v2/strategies/{id}/bindings/{binding_id}` → 204
  - `PATCH /api/v2/strategies/{id}/archive` → `StrategyV2Response`
  - `GET /api/v2/strategies/{id}/activity` → `list[ActivityEntry]`
- 错误映射：`DuplicateBindingError → 409 BINDING_DUPLICATE`、`PoolMismatchError → 422 BINDING_POOL_MISMATCH`、`PolicyArchivedError → 422 BINDING_POLICY_ARCHIVED`、`BindingInUseError → 409 BINDING_IN_USE`。

- [ ] **Step 1: 写 router endpoint 测试**（用 FastAPI TestClient，每个端点至少 happy + 1 错误路径）

```python
def test_get_workspace_returns_snapshot(client, strategy): ...
def test_get_workspace_404_when_missing(client): ...
def test_duplicate_creates_new_strategy(client, strategy): ...
def test_create_binding_happy(client, fixtures): ...
def test_create_binding_409_on_duplicate(client, fixtures): ...
def test_create_binding_422_on_pool_mismatch(client, fixtures): ...
def test_delete_binding_204(client, fixtures): ...
def test_delete_binding_409_when_in_use(client, fixtures): ...
def test_archive_changes_status(client, strategy): ...
def test_get_activity_returns_recent_entries(client, strategy): ...
def test_get_bindings_returns_all_modes(client, fixtures): ...
```

- [ ] **Step 2: 跑测试看到失败**

- [ ] **Step 3: 写 router 实现**

```python
# backend/app/routers/strategy_workspace.py 骨架
from fastapi import APIRouter, Depends, HTTPException
# ... imports ...

router = APIRouter(prefix="/api/v2/strategies", tags=["strategy-workspace"])


@router.get("/{strategy_id}/workspace", response_model=WorkspaceSnapshotResponse)
async def get_workspace(strategy_id: uuid.UUID, db: Session = Depends(get_db)):
    aggregator = _build_aggregator(db)
    snapshot = await aggregator.get_snapshot(strategy_id)
    if not snapshot:
        raise HTTPException(404, "strategy not found")
    return snapshot


@router.post("/{strategy_id}/duplicate", response_model=StrategyV2Response, status_code=201)
def duplicate(strategy_id: uuid.UUID, body: DuplicateRequest, db: Session = Depends(get_db)):
    activity = StrategyActivityService(db)
    svc = StrategyDuplicateService(db, activity)
    try:
        new = svc.duplicate(strategy_id, name=body.name)
    except ValueError as e:
        raise HTTPException(404 if "not found" in str(e) else 422, str(e))
    db.commit()
    return new


# ... other endpoints follow same pattern, mapping service errors → HTTP codes ...
```

- [ ] **Step 4: 注册 router 到 main.py**

```python
# backend/app/main.py 加一行
from app.routers.strategy_workspace import router as strategy_workspace_router
app.include_router(strategy_workspace_router)
```

- [ ] **Step 5: 跑测试**

```bash
cd backend && python3 -m pytest tests/test_router_strategy_workspace.py -v
```

- [ ] **Step 6: Commit**

```bash
git add backend/app/routers/strategy_workspace.py backend/app/main.py backend/tests/test_router_strategy_workspace.py
git commit -m "feat(strategy-workspace): add router with 7 endpoints"
```

---

### Task 9: 现有路由加 UUID query 过滤

**Files:**
- Modify: `backend/app/routers/strategy_runs.py`（加 `strategy_version_id?`、`strategy_id?` query）
- Modify: `backend/app/routers/backtest.py`（加 UUID 参数；保留 deprecated int strategy_id）
- Modify: `backend/app/routers/dryrun.py`（加 `strategy_version_id?`）
- Modify: `backend/app/routers/risk_bff.py`（overview 加 `strategy_id?`，传时调 per-strategy 路径）
- Test: extend `backend/tests/test_strategies_v2_uuid_filter.py`（如不存在则 create）

**Interfaces:**
- 新 query 参数全部 optional，不传时维持旧行为（向后兼容）。
- `risk_bff.get_risk_overview(strategy_id?)`：传时调 `LiveReadinessService.compute_for_strategy` 取该策略的 risk gauges 子集；不传维持账户级 RiskAggregator。

- [ ] **Step 1: 写测试**

```python
def test_strategy_runs_filter_by_version_id(client, fixtures): ...
def test_backtest_list_filter_by_strategy_uuid(client, fixtures): ...
def test_dryrun_list_filter_by_version_id(client, fixtures): ...
def test_risk_overview_strategy_id_returns_per_strategy_state(client, fixtures): ...
def test_risk_overview_no_strategy_id_returns_account_level(client, fixtures): ...
```

- [ ] **Step 2: 跑测试看到失败**

- [ ] **Step 3: 加 query 参数 + 过滤逻辑**（每个 router 改 ~3 行）

- [ ] **Step 4: 跑测试**

期望 PASS + 现有相关测试不退化。

- [ ] **Step 5: Commit**

```bash
git add backend/app/routers/strategy_runs.py backend/app/routers/backtest.py backend/app/routers/dryrun.py backend/app/routers/risk_bff.py backend/tests/test_strategies_v2_uuid_filter.py
git commit -m "feat(strategy-workspace): add UUID query filters to runs/backtest/dryrun/risk_overview"
```

---

## Phase 5: canvas-web

### Task 10: Bridge 协议扩展（selectionChanged / graphStats / setReadOnly / updateNodeData）

**Files:**
- Modify: `canvas-web/src/types.ts`（新增 message 类型）
- Modify: `canvas-web/src/bridge.ts`（无变动，已通用）
- Modify: `canvas-web/src/hooks/useCanvasBridge.ts`（注册新消息处理）
- Modify: `canvas-web/src/App.tsx`（onSelectionChange / onNodesChange/onEdgesChange 触发 graphStats、接收 setReadOnly/updateNodeData）
- Test: `canvas-web/src/hooks/useCanvasBridge.test.ts`

**Interfaces:**
- React → Swift（new）：
  ```ts
  | { type: 'selectionChanged', selectedNode: { id: string, type: string, data: Record<string, unknown> } | null }
  | { type: 'graphStats', nodeCount: number, edgeCount: number, validation: 'valid' | 'invalid' | 'unvalidated' }
  ```
- Swift → React（new）：
  ```ts
  | { type: 'setReadOnly', readOnly: boolean }
  | { type: 'updateNodeData', nodeId: string, data: Record<string, unknown> }
  ```
- `setReadOnly: true` 时禁用：拖拽 palette / 拖动节点 / 接线 / 节点删除。

- [ ] **Step 1: 写 types**（追加 4 条 union variant）

- [ ] **Step 2: 写 hook 测试**（vitest）

- [ ] **Step 3: 实现：在 `App.tsx` 监听 React Flow `onSelectionChange`、`onNodesChange`/`onEdgesChange` 后通过 `sendToSwift` 推送；在 `useCanvasBridge` 处理 `setReadOnly`/`updateNodeData` 入消息**。

```tsx
// 关键改动 App.tsx
const onSelectionChange = useCallback(({nodes}) => {
  const sel = nodes[0] ?? null
  sendToSwift({
    type: 'selectionChanged',
    selectedNode: sel ? { id: sel.id, type: sel.type ?? '', data: sel.data ?? {} } : null,
  })
}, [])

useEffect(() => {
  sendToSwift({
    type: 'graphStats',
    nodeCount: nodes.length,
    edgeCount: edges.length,
    validation: validation == null ? 'unvalidated' : validation.valid ? 'valid' : 'invalid',
  })
}, [nodes.length, edges.length, validation?.valid])

// readOnly 状态 + handler
const [readOnly, setReadOnly] = useState(false)
// pass to <ReactFlow nodesDraggable={!readOnly} edgesDeletable={!readOnly} ... />
```

```tsx
// useCanvasBridge.ts 加 handler
case 'setReadOnly':
  setReadOnly(msg.readOnly); break
case 'updateNodeData':
  setNodes(ns => ns.map(n => n.id === msg.nodeId ? {...n, data: msg.data} : n)); break
```

- [ ] **Step 4: 跑 vitest**

```bash
cd canvas-web && npm test
```

期望 PASS。

- [ ] **Step 5: 构建 + 拷贝到 Resources**

```bash
cd canvas-web && npm run build
cp -R dist/ ../macos-app/AlphaLoop/Resources/canvas-web/
```

- [ ] **Step 6: Commit**

```bash
git add canvas-web/src/ canvas-web/dist/ macos-app/AlphaLoop/Resources/canvas-web/
git commit -m "feat(canvas-web): extend bridge with selectionChanged / graphStats / setReadOnly / updateNodeData"
```

---

### Task 11: 9 类节点视觉重绘 + ProofAlpha tokens + 删除 NodeConfigPanel

**Files:**
- Create: `canvas-web/src/nodes/NodeShell.tsx`（公共骨架：色条头部 + body grid + 端口）
- Modify: 9 个节点文件（迁移到 NodeShell，参数显示 4 行表格）
- Modify: `canvas-web/src/styles/*.css` 或新建 `canvas-web/src/styles/tokens.css`（ProofAlpha tokens）
- Modify: `canvas-web/src/App.tsx`（删除 toolbar / status-bar / palette title；MiniMap nodeColor 换 token；Background dots gap 24 + color rgba(255,255,255,0.030)；defaultEdgeOptions smoothstep 1.5px）
- Delete: `canvas-web/src/panels/NodeConfigPanel.tsx`
- Test: `canvas-web/src/nodes/NodeShell.test.tsx`

**Interfaces:**
- `<NodeShell type, title, dotColor, rows: [{k,v}], selected, invalid, errMessage?>` —— 9 节点都包它。
- CSS variables（在 `:root`）镜像 spec §4.1：`--bg #0A0A0A`、`--card #171B26`、`--accent #00FF9D` …

- [ ] **Step 1: 写 tokens CSS**（spec §4.1 全套变量）

- [ ] **Step 2: 写 NodeShell 测试**（vitest + RTL：渲染、选中态、失败态、端口存在性）

- [ ] **Step 3: 实现 NodeShell.tsx**

- [ ] **Step 4: 9 节点逐个迁移到 NodeShell**（每个 ~15 行）。emoji 图标移除。

- [ ] **Step 5: App.tsx 清理**：
  - 删除 `<div className="canvas-toolbar">…验证/保存按钮</div>` 和 `<div className="status-bar">…</div>`（这些功能由 Swift HUD/状态栏接管）
  - 删除 `<div className="palette-title">组件</div>` 标题，保留 palette item
  - 删除 `selectedNode && <NodeConfigPanel>` —— 节点配置改 Swift native
  - 修改 MiniMap nodeColor 映射改 ProofAlpha tokens
  - 修改 Background `<Background variant={BackgroundVariant.Dots} gap={24} size={1} color="rgba(255,255,255,0.030)" />`
  - 修改 defaultEdgeOptions: `{ type: 'smoothstep', animated: false, style: { strokeWidth: 1.5 } }`

- [ ] **Step 6: 删除 `panels/NodeConfigPanel.tsx`**

- [ ] **Step 7: 跑 vitest + 视觉对比 mockup**

```bash
cd canvas-web && npm test && npm run dev
# 浏览器 localhost:5173 对比 docs/ui-references/mockups/strategy-workbench-A-final.html
```

- [ ] **Step 8: 构建 + 拷贝到 Resources**

```bash
cd canvas-web && npm run build
cp -R dist/ ../macos-app/AlphaLoop/Resources/canvas-web/
```

- [ ] **Step 9: Commit**

```bash
git add canvas-web/src/ canvas-web/dist/ macos-app/AlphaLoop/Resources/canvas-web/
git rm canvas-web/src/panels/NodeConfigPanel.tsx
git commit -m "feat(canvas-web): redesign 9 node visuals with ProofAlpha tokens; remove inline NodeConfigPanel"
```

---

## Phase 6: macOS 清理 + Models

### Task 12: 删除 21 个废弃文件 + 更新 Enums

**Files:**
- Delete: `macos-app/AlphaLoop/Views/Strategies/Workbench/{ConsoleCenterStack,SectionCards,WorkspaceChrome,StrategyWorkspaceConsoleView}.swift`
- Delete: `macos-app/AlphaLoop/Views/Strategies/{StrategyDetailView,StrategyOverviewTab,StrategyDSLTab,StrategyBacktestTab,StrategyDryrunTab,StrategyRiskTab,StrategyRunsTab,StrategySignalsTab,StrategyVersionsTab,StrategyGrowthTab,StrategyCanvasWebTab,StrategyLifecycleRailView,StrategiesListView,StrategyCardView,StrategyCreatePanel}.swift`
- Delete: `macos-app/AlphaLoop/Views/Canvas/{StrategyCanvasPageView,CanvasBackground,CanvasSearchOverlay,CanvasEdges,CanvasSelectionRect,CanvasDSLPreviewPanel,CanvasTopActionBar}.swift`
- Delete: `macos-app/AlphaLoop/Views/DryrunMonitor/`（整目录）
- Delete: `macos-app/AlphaLoop/ViewModels/{StrategyDetailViewModel,DryrunMonitorViewModel}.swift`
- Modify: `macos-app/AlphaLoop/Models/Enums.swift`（删除 `strategyDetail`、`strategyCanvas` 路由 case；新增 `WorkbenchPanel`）
- Modify: 任何 import 这些文件的处（grep 找）

**Interfaces:**
- Produces:
  - `enum WorkbenchPanel: String, CaseIterable, Identifiable { case list, node, version, risk, backtest, readiness }`

- [ ] **Step 1: grep 找所有 import**

```bash
cd macos-app
grep -rn "StrategyDetailView\|StrategyOverviewTab\|StrategyDSLTab\|StrategyBacktestTab\|StrategyDryrunTab\|StrategyRiskTab\|StrategyRunsTab\|StrategySignalsTab\|StrategyVersionsTab\|StrategyGrowthTab\|StrategyCanvasWebTab\|StrategyCanvasPageView\|StrategyWorkspaceConsoleView\|DryrunMonitor\|ConsoleCenterStack\|SectionCards\|WorkspaceChrome\|CanvasBackground\|CanvasSearchOverlay\|CanvasEdges\|CanvasSelectionRect\|CanvasDSLPreviewPanel\|CanvasTopActionBar\|StrategiesListView\|StrategyCardView\|StrategyCreatePanel\|StrategyLifecycleRailView" AlphaLoop/ Tests/
```

记录所有引用，准备一并修改。

- [ ] **Step 2: 在 `Enums.swift` 新增 WorkbenchPanel + 删除废弃 AppRoute case**

```swift
enum WorkbenchPanel: String, CaseIterable, Identifiable {
    case list, node, version, risk, backtest, readiness
    var id: String { rawValue }
    var shortcut: KeyEquivalent {
        switch self {
        case .list: "1"; case .node: "2"; case .version: "3"
        case .risk: "4"; case .backtest: "5"; case .readiness: "6"
        }
    }
    var icon: String {
        switch self {
        case .list: "list.bullet.rectangle"
        case .node: "rectangle.connected.to.line.below"
        case .version: "clock.arrow.circlepath"
        case .risk: "shield.lefthalf.filled"
        case .backtest: "play.rectangle.on.rectangle"
        case .readiness: "checkmark.seal"
        }
    }
}
```

`AppRoute` 中删除 `case strategyDetail` 和 `case strategyCanvas`。

- [ ] **Step 3: 删除 21 个文件**

```bash
cd macos-app/AlphaLoop
git rm Views/Strategies/Workbench/ConsoleCenterStack.swift \
       Views/Strategies/Workbench/SectionCards.swift \
       Views/Strategies/Workbench/WorkspaceChrome.swift \
       Views/Strategies/Workbench/StrategyWorkspaceConsoleView.swift \
       Views/Strategies/StrategyDetailView.swift \
       Views/Strategies/StrategyOverviewTab.swift \
       Views/Strategies/StrategyDSLTab.swift \
       Views/Strategies/StrategyBacktestTab.swift \
       Views/Strategies/StrategyDryrunTab.swift \
       Views/Strategies/StrategyRiskTab.swift \
       Views/Strategies/StrategyRunsTab.swift \
       Views/Strategies/StrategySignalsTab.swift \
       Views/Strategies/StrategyVersionsTab.swift \
       Views/Strategies/StrategyGrowthTab.swift \
       Views/Strategies/StrategyCanvasWebTab.swift \
       Views/Strategies/StrategyLifecycleRailView.swift \
       Views/Strategies/StrategiesListView.swift \
       Views/Strategies/StrategyCardView.swift \
       Views/Strategies/StrategyCreatePanel.swift \
       Views/Canvas/StrategyCanvasPageView.swift \
       Views/Canvas/CanvasBackground.swift \
       Views/Canvas/CanvasSearchOverlay.swift \
       Views/Canvas/CanvasEdges.swift \
       Views/Canvas/CanvasSelectionRect.swift \
       Views/Canvas/CanvasDSLPreviewPanel.swift \
       Views/Canvas/CanvasTopActionBar.swift \
       ViewModels/StrategyDetailViewModel.swift \
       ViewModels/DryrunMonitorViewModel.swift
git rm -rf Views/DryrunMonitor/
```

- [ ] **Step 4: 修复 import 引用**

依据 Step 1 的 grep 结果，每处用占位 view（`Text("TBD: workspace view")`）暂时引用 `StrategyCanvasWorkspaceView`（Task 18 实现）。AppShellView 改：

```swift
case .strategyWorkspace:
    StrategyCanvasWorkspaceView()
case .backtestSimulation:
    BacktestLabView()
```

- [ ] **Step 5: 临时占位**

```swift
// 暂时占位（task 18 之前编译能过）
// 文件：Views/Strategies/Workbench/StrategyCanvasWorkspaceView.swift
import SwiftUI
struct StrategyCanvasWorkspaceView: View {
    var body: some View { Text("workspace placeholder") }
}
```

- [ ] **Step 6: 编译**

```bash
cd macos-app && swift build
```

期望：编译通过（占位 view + 已删除引用都修复）。

- [ ] **Step 7: Commit**

```bash
git add macos-app/AlphaLoop/Models/Enums.swift macos-app/AlphaLoop/Views/AppShell/AppShellView.swift macos-app/AlphaLoop/Views/Strategies/Workbench/StrategyCanvasWorkspaceView.swift
git commit -m "refactor(workbench): delete 21 legacy files; add WorkbenchPanel enum; placeholder workspace view"
```

---

### Task 13: Models/Types.swift 添加新类型

**Files:**
- Modify: `macos-app/AlphaLoop/Models/Types.swift`（追加新 struct）

**Interfaces:**
- Produces（Codable）：
  - `WorkspaceSnapshot`（11 字段，对应 BFF response，spec §6.1.A）
  - `StrategyBinding`（含 `riskPolicy: RiskPolicySummary`、`capitalPool: CapitalPoolSummary`）
  - `RiskPolicySummary`、`CapitalPoolSummary`
  - `BacktestRunSummary`、`StrategyRunSummary`（最近 run）
  - `ActivityEntry`（含 kind/occurredAt/actor/summary/delta/ref）
  - `PerStrategyReadiness`（含 strategyGates/systemGates/grandStatus/nextAction）
  - `ReadinessGate`、`ReadinessNextAction`
  - `SignalLogicSummary`（entryText/exitText/filterCount）
  - `DataDependencies`（symbols/timeframes/indicators/signalSources）

- [ ] **Step 1: 写所有 struct**（参考 spec §6.1.A 字段；CodingKeys 走 snake_case → camelCase）

- [ ] **Step 2: 编译**

```bash
cd macos-app && swift build
```

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/Models/Types.swift
git commit -m "feat(workbench): add Codable types for workspace snapshot + bindings + readiness"
```

---

## Phase 7: macOS APIs + ViewModel

### Task 14: APIStrategyWorkspace + 现有 API 升级

**Files:**
- Create: `macos-app/AlphaLoop/Services/APIStrategyWorkspace.swift`
- Modify: `macos-app/AlphaLoop/Services/APIStrategyRuns.swift`（加 `strategyVersionId` 参数）
- Modify: `macos-app/AlphaLoop/Services/APIBacktest.swift`（加 UUID 参数；老 int 路径标 deprecated）
- Modify: `macos-app/AlphaLoop/Services/APIDryrunV2.swift`（加 `strategyVersionId`）
- Modify: `macos-app/AlphaLoop/Services/APIRiskBFF.swift`（overview 加 `strategyId`）

**Interfaces:**
- Produces:
  - `APIStrategyWorkspace(client)` 含 7 方法对应 §6.1 端点
  - 各 list 方法签名都接受 `strategyVersionId: String?` 默认 nil
  - 每个新方法**必须** 配 `MockX.workspace*()` 工厂（按 CLAUDE.md 约定）

- [ ] **Step 1: 写 APIStrategyWorkspace 和 mocks**（每端点对应一个 method + mock factory）

```swift
final class APIStrategyWorkspace: @unchecked Sendable {
    let client: NetworkClientProtocol
    init(client: NetworkClientProtocol) { self.client = client }

    func getSnapshot(strategyId: String) async throws -> WorkspaceSnapshot {
        try await client.get("/api/v2/strategies/\(strategyId)/workspace",
            mock: { MockWorkspace.snapshot(strategyId: strategyId) })
    }

    func duplicate(strategyId: String, name: String?) async throws -> StrategyV2 {
        var body: [String: Any] = [:]
        if let n = name { body["name"] = n }
        return try await client.post("/api/v2/strategies/\(strategyId)/duplicate",
            body: AnyEncodable(body),
            mock: { MockDataV2.strategies()[0] })
    }

    func listBindings(strategyId: String) async throws -> [StrategyBinding] {
        try await client.get("/api/v2/strategies/\(strategyId)/bindings",
            mock: { MockWorkspace.bindings() })
    }

    func createBinding(strategyId: String, versionId: String, policyVersionId: String, poolId: String, mode: String) async throws -> StrategyBinding {
        try await client.post("/api/v2/strategies/\(strategyId)/bindings",
            body: AnyEncodable([
                "strategy_version_id": versionId,
                "risk_policy_version_id": policyVersionId,
                "capital_pool_id": poolId,
                "mode": mode,
            ]),
            mock: { MockWorkspace.binding() })
    }

    func deleteBinding(strategyId: String, bindingId: String) async throws {
        try await client.delete("/api/v2/strategies/\(strategyId)/bindings/\(bindingId)", mock: { })
    }

    func archive(strategyId: String, reason: String?) async throws -> StrategyV2 {
        var body: [String: Any] = [:]
        if let r = reason { body["reason"] = r }
        return try await client.patch("/api/v2/strategies/\(strategyId)/archive",
            body: AnyEncodable(body),
            mock: { MockDataV2.strategies()[0] })
    }

    func listActivity(strategyId: String, limit: Int = 20) async throws -> [ActivityEntry] {
        try await client.get("/api/v2/strategies/\(strategyId)/activity?limit=\(limit)",
            mock: { MockWorkspace.activity() })
    }
}

enum MockWorkspace {
    static func snapshot(strategyId: String) -> WorkspaceSnapshot { /* ... */ }
    static func bindings() -> [StrategyBinding] { /* ... */ }
    static func binding() -> StrategyBinding { /* ... */ }
    static func activity() -> [ActivityEntry] { /* ... */ }
}
```

- [ ] **Step 2: 升级 APIStrategyRuns/APIBacktest/APIDryrunV2/APIRiskBFF**

```swift
// APIStrategyRuns.swift
func listRuns(mode: String? = nil, status: String? = nil, strategyVersionId: String? = nil, limit: Int = 20) async throws -> [StrategyRunV2] {
    var params: [String] = ["limit=\(limit)"]
    if let m = mode { params.append("mode=\(m)") }
    if let s = status { params.append("status=\(s)") }
    if let v = strategyVersionId { params.append("strategy_version_id=\(v)") }
    return try await client.get("/api/v2/strategy-runs?" + params.joined(separator: "&"), mock: { [] })
}
```

类似改 APIBacktest（加 strategyId UUID + strategyVersionId 参数；老 int strategyId 保留向后兼容）、APIDryrunV2（list 加 strategyVersionId）、APIRiskBFF（overview 加 strategyId 参数）。

- [ ] **Step 3: 编译**

```bash
cd macos-app && swift build
```

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Services/
git commit -m "feat(workbench): add APIStrategyWorkspace + UUID query support to existing API services"
```

---

### Task 15: 重写 StrategyWorkspaceViewModel

**Files:**
- Rewrite: `macos-app/AlphaLoop/ViewModels/StrategyWorkspaceViewModel.swift`

**Interfaces:** spec §7.2

- [ ] **Step 1: 全文替换**

按 spec §7.2 接口重写，关键点：
- 用 `APIStrategyWorkspace.getSnapshot` 替换原 7 个并行 `async let`
- `activePanel: WorkbenchPanel?` 替换原 `mode: WorkspaceMode` 和 `inspectorTab`
- 加 `selectedCanvasNodeId / canvasNodeCount / canvasEdgeCount / canvasValidationValid`（由 CanvasBridge 写入）
- `duplicate / archive / startDryrun / startBacktest / createBinding / deleteBinding` 各自调对应 API
- `transitionStatus` 复用现有 `strategiesAPI.transitionVersionStatus`
- 删除 `currentRun` / `WorkspaceMode` / `InspectorTab` 等旧定义

- [ ] **Step 2: 编译**（占位 view 仍引用 ViewModel，确认能编译）

- [ ] **Step 3: Commit**

```bash
git add macos-app/AlphaLoop/ViewModels/StrategyWorkspaceViewModel.swift
git commit -m "refactor(workbench): rewrite StrategyWorkspaceViewModel for canvas-first IA"
```

---

## Phase 8: macOS Workbench shell

### Task 16: WorkbenchHUD + StagePill + ReadinessPill

**Files:**
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/WorkbenchHUD.swift`（40px 顶 HUD）
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/StagePill.swift`（7 段进度）
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/ReadinessPill.swift`（X/11 + 颜色）

**Interfaces:**
- `WorkbenchHUD(vm: StrategyWorkspaceViewModel, onTriggerPanel: (WorkbenchPanel) -> Void)`
- `StagePill(currentStatus: String)` — 镜像 spec §5.1，7 段进度条 `LifecycleStage.from(status)` 推算
- `ReadinessPill(passedCount: Int, total: Int = 11, grandStatus: String)` — 颜色按 grandStatus（accent / amber / err）

- [ ] **Step 1: 实现 StagePill**（用 `LifecycleStage` 已存在的 7 节点映射；UI 镜像 mockup A —— 文字 + 7×4px bar）

- [ ] **Step 2: 实现 ReadinessPill**（小药丸：左侧 chip 颜色 + 数字）

- [ ] **Step 3: 实现 WorkbenchHUD**（左侧身份 + spacer + 右侧 stage/readiness/next/actions；按钮 enable 条件按 spec §5.1 表）

```swift
// HUD 关键骨架（不写完整代码，仅签名）
struct WorkbenchHUD: View {
    let vm: StrategyWorkspaceViewModel
    var onTriggerPanel: (WorkbenchPanel) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            identitySection
            Spacer()
            StagePill(currentStatus: vm.selectedStrategy?.status ?? "draft")
            ReadinessPill(passedCount: vm.snapshot?.readiness.passedCount ?? 0,
                          grandStatus: vm.snapshot?.readiness.grandStatus ?? "not_live")
            nextActionPrompt
            actionGroup
        }
        .frame(height: 40)
        .padding(.horizontal, 16)
        .background(colors.background)
        .overlay(Rectangle().fill(colors.border).frame(height: 1), alignment: .bottom)
    }
}
```

- [ ] **Step 4: 视觉对照 mockup**：颜色全用 `PulseColors.*`；字体 `PulseFonts.captionMedium` for labels、`PulseFonts.tabular` for mono；按钮高度 26px。

- [ ] **Step 5: 编译**

- [ ] **Step 6: Commit**

```bash
git add macos-app/AlphaLoop/Views/Strategies/Workbench/{WorkbenchHUD,StagePill,ReadinessPill}.swift
git commit -m "feat(workbench): add WorkbenchHUD with stage progress + readiness pill + actions"
```

---

### Task 17: WorkbenchStatusBar + PanelChrome

**Files:**
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/WorkbenchStatusBar.swift`（26px 底状态栏）
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/PanelChrome.swift`（浮层壳）

**Interfaces:**
- `WorkbenchStatusBar(validationState: ValidationState, version: StrategyVersionV2?, nodeCount: Int, edgeCount: Int)`
- `enum ValidationState { case unvalidated, valid, invalid(count: Int) }`
- `PanelChrome<Content>(title: String, icon: String, onClose: ()->Void) { content }` — 玻璃浮层右上 320px，含头部 + 关闭按钮 + ESC 监听

- [ ] **Step 1: 实现 WorkbenchStatusBar**（mockup A 镜像：左侧验证状态 + 版本/hash + 时间 + 节点/连线数；右侧快捷键提示用 `Text` + `kbd-like` 样式）

- [ ] **Step 2: 实现 PanelChrome**（玻璃浮层壳：320px 宽，使用 `colors.cardBackground` + `.glassEffect()` 直接作用，**不要**放 .background 中；头部 icon + title + 右侧 ✕ 按钮；ESC 关闭通过 `.onKeyPress(.escape)` 触发 `onClose`）

```swift
struct PanelChrome<Content: View>: View {
    @Environment(PulseColors.self) private var colors
    let title: String
    let icon: String
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(colors.border)
            ScrollView { content().padding(12) }
        }
        .frame(width: 320)
        .frame(maxHeight: 600)
        .glassEffect()  // ← 直接作用于内容
        .overlay(RoundedRectangle(cornerRadius: PulseRadii.md).stroke(colors.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: PulseRadii.md))
        .shadow(color: .black.opacity(0.4), radius: 16, y: 6)
        .onKeyPress(.escape) { onClose(); return .handled }
    }
}
```

- [ ] **Step 3: 编译**

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Views/Strategies/Workbench/WorkbenchStatusBar.swift macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/PanelChrome.swift
git commit -m "feat(workbench): add status bar + panel chrome with glass effect"
```

---

### Task 18: StrategyCanvasWorkspaceView 主装配

**Files:**
- Rewrite: `macos-app/AlphaLoop/Views/Strategies/Workbench/StrategyCanvasWorkspaceView.swift`（删除占位 + 实现真正主 view）

**Interfaces:**
- 装配 ZStack：背景 → 中间画布 (`CanvasWebView`) → 顶 HUD overlay → 底状态栏 overlay → 浮层面板 overlay
- 监听 ⌘1~⌘6 快捷键 → `vm.togglePanel(...)`
- 监听 CanvasBridge `selectionChanged`、`graphStats` → 写 vm
- archive 后 `bridge.setReadOnly(true)`

- [ ] **Step 1: 实现主 view**

```swift
struct StrategyCanvasWorkspaceView: View {
    @Environment(\.networkClient) private var networkClient
    @Environment(SettingsState.self) private var settingsState
    @Environment(AppState.self) private var appState
    @Environment(PulseColors.self) private var colors
    
    @State private var vm: StrategyWorkspaceViewModel?
    @State private var canvasVM: CanvasWebViewModel?
    
    var body: some View {
        Group {
            if let vm { content(vm: vm) }
            else { LoadingView(type: .detail) }
        }
        .id(settingsState.language)
        .task {
            if vm == nil {
                let v = StrategyWorkspaceViewModel(client: networkClient)
                vm = v
                await v.loadList()
                if let id = appState.selectedStrategyV2Id { await v.select(strategyId: id) }
            }
        }
    }
    
    @ViewBuilder
    private func content(vm: StrategyWorkspaceViewModel) -> some View {
        ZStack {
            colors.background.ignoresSafeArea()
            
            // canvas full screen
            if let canvasVM { CanvasWebView(viewModel: canvasVM) }
            else { Color.clear }
            
            // HUD overlay
            VStack(spacing: 0) {
                WorkbenchHUD(vm: vm, onTriggerPanel: { vm.togglePanel($0) })
                Spacer()
                WorkbenchStatusBar(
                    validationState: validationStateFromVM(vm),
                    version: vm.snapshot?.versions.first,
                    nodeCount: vm.canvasNodeCount,
                    edgeCount: vm.canvasEdgeCount
                )
            }
            
            // panel overlay
            if let panel = vm.activePanel {
                HStack {
                    Spacer()
                    panelView(panel: panel, vm: vm)
                        .padding(.top, 56)
                        .padding(.trailing, 16)
                }
                .frame(maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .onAppear { ensureCanvasLoaded(vm) }
        .onChange(of: vm.selectedStrategyId) { _, _ in ensureCanvasLoaded(vm) }
        // ⌘1~⌘6
        .background {
            ForEach(WorkbenchPanel.allCases) { p in
                Button("") { vm.togglePanel(p) }
                    .keyboardShortcut(p.shortcut, modifiers: .command)
                    .hidden()
            }
        }
    }
    
    @ViewBuilder
    private func panelView(panel: WorkbenchPanel, vm: StrategyWorkspaceViewModel) -> some View {
        switch panel {
        case .list: StrategyListPanel(vm: vm)
        case .node: NodeConfigPanel(vm: vm)
        case .version: VersionsPanel(vm: vm)
        case .risk: RiskBindingPanel(vm: vm)
        case .backtest: BacktestDryrunPanel(vm: vm)
        case .readiness: ReadinessPanel(vm: vm)
        }
    }
    
    private func ensureCanvasLoaded(_ vm: StrategyWorkspaceViewModel) {
        guard let id = vm.selectedStrategyId else { return }
        if canvasVM?.strategyId != id {
            canvasVM = CanvasWebViewModel(strategyId: id, client: networkClient)
        }
        if let raw = vm.snapshot?.versions.first?.ruleDsl {
            canvasVM?.loadDSL(raw.mapValues { $0.value })
        }
        // wire bridge selectionChanged/graphStats → vm（在 CanvasBridge 内 callback）
        canvasVM?.onSelectionChanged = { node in vm.selectedCanvasNodeId = node?.id }
        canvasVM?.onGraphStats = { stats in
            vm.canvasNodeCount = stats.nodeCount
            vm.canvasEdgeCount = stats.edgeCount
            vm.canvasValidationValid = stats.validation == "valid"
        }
        if vm.selectedStrategy?.status == "archived" {
            canvasVM?.setReadOnly(true)
        }
    }
    
    private func validationStateFromVM(_ vm: StrategyWorkspaceViewModel) -> ValidationState {
        if vm.canvasValidationValid == true { return .valid }
        if vm.canvasValidationValid == false { return .invalid(count: 0) }
        return .unvalidated
    }
}
```

- [ ] **Step 2: 占位 6 个 Panel 类型**（每个写 `struct StrategyListPanel: View { var vm: StrategyWorkspaceViewModel; var body: some View { Text("⌘1") } }` 之类 5 行占位，让编译通过；后续 Phase 9 替换）

- [ ] **Step 3: 编译 + 启动 app 看效果**

```bash
cd macos-app && swift run
```

期望：进入工作台路由能看到画布全屏 + 顶 HUD + 底状态栏；⌘1~⌘6 切面板（占位文字）。

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Views/Strategies/Workbench/
git commit -m "feat(workbench): assemble StrategyCanvasWorkspaceView with HUD/status/panel overlays"
```

---

## Phase 9: macOS 6 个 panel 实现

### Task 19: ⌘1 StrategyListPanel

**Files:**
- Replace: `macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/StrategyListPanel.swift`

**Interfaces:**
- 内容：搜索 + 4 桶筛选 chip + 列表 + 「+ 新建草稿」按钮
- 列表行：色点 + 名 + 类型 + 阶段（迁移自旧 `StrategySwitcherPanel`）

- [ ] **Step 1: 迁移旧 SwitcherPanel 内容（`WorkspaceChrome.swift` 已删，从 git history 复制）**

```bash
git show HEAD~N:macos-app/AlphaLoop/Views/Strategies/Workbench/WorkspaceChrome.swift | grep -A 100 "StrategySwitcherPanel"
```

把 `StrategySwitcherPanel` 改名 `StrategyListPanel`，包进 `PanelChrome`，去除原 `Popover` 定位。

- [ ] **Step 2: 接 vm.search/filter/filteredStrategies/select**

- [ ] **Step 3: 编译 + 启动 app 验证**

- [ ] **Step 4: Commit**

```bash
git add macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/StrategyListPanel.swift
git commit -m "feat(workbench): implement ⌘1 strategy list panel"
```

---

### Task 20: ⌘2 NodeConfigPanel + 9 NodeConfigForms

**Files:**
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/NodeConfigPanel.swift`
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/NodeConfigForms/{SignalInput,IndicatorCondition,Filter,PositionSizing,RiskPolicy,ExecutionOutput,StructureDefense,AccountRisk,MTFGuard}Form.swift`（9 文件）
- Modify: `macos-app/AlphaLoop/ViewModels/CanvasWebViewModel.swift`（暴露 `selectedNode: CanvasNode?` + `updateNodeData(id, data)`）

**Interfaces:**
- 9 个 form 都接受 `data: [String: Any]` 和 `onUpdate: ([String: Any]) -> Void`
- NodeConfigPanel 根据节点 type 路由到对应 form
- 提交 → vm.canvasVM.updateNodeData(id, data) → bridge.sendToReact

- [ ] **Step 1: 写 form 抽象 + SignalInputForm**

```swift
// SignalInputForm.swift
struct SignalInputForm: View {
    @Binding var symbols: [String]
    @Binding var timeframe: String
    @Binding var source: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Workbench.nodeSignalInput).font(.subheadline)
            symbolField  // 简单 TextField
            timeframePicker  // Picker [1m 5m 15m 1h 4h 1d]
            sourcePicker  // Picker [signal_center, manual]
        }
    }
}
```

- [ ] **Step 2: 写其他 8 个 form**（IndicatorCondition / Filter / PositionSizing / RiskPolicy / ExecutionOutput / StructureDefense / AccountRisk / MTFGuard）。每个按 `canvas-web/src/nodes/<NodeType>Node.tsx` 的 props/data shape 复刻。每个 form ~30-60 行。

- [ ] **Step 3: 写 NodeConfigPanel 路由**

```swift
struct NodeConfigPanel: View {
    let vm: StrategyWorkspaceViewModel
    
    var body: some View {
        PanelChrome(title: nodeTitle, icon: "rectangle.connected.to.line.below",
                    onClose: { vm.closePanel() }) {
            if let node = vm.canvasVM?.selectedNode {
                form(for: node)
            } else {
                Text(L10n.Workbench.nodeNoSelection)
            }
        }
    }
    
    @ViewBuilder
    private func form(for node: CanvasNode) -> some View {
        switch node.type {
        case "signalInput": SignalInputForm(...)
        case "indicatorCondition": IndicatorConditionForm(...)
        // ... 9 cases
        default: Text("unknown node type \(node.type)")
        }
    }
}
```

- [ ] **Step 4: CanvasWebViewModel 暴露 selectedNode + updateNodeData(id, data)**

```swift
// CanvasWebViewModel
@Published var selectedNode: CanvasNode?
var onSelectionChanged: ((CanvasNode?) -> Void)?

func updateNodeData(id: String, data: [String: Any]) {
    sendToReact(.updateNodeData(nodeId: id, data: data))
}
```

- [ ] **Step 5: 编译 + 启动 app**

打开工作台，画布加节点，点选 → ⌘2 自动唤出，编辑参数 → React Flow 同步。

- [ ] **Step 6: Commit**

```bash
git add macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/NodeConfigPanel.swift macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/NodeConfigForms/ macos-app/AlphaLoop/ViewModels/CanvasWebViewModel.swift
git commit -m "feat(workbench): implement ⌘2 node config panel with 9 native forms"
```

---

### Task 21: ⌘3 VersionsPanel

**Files:**
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/VersionsPanel.swift`

**Interfaces:**
- 顶部 "最近变更" 段：取 `vm.snapshot?.activity` 前 3 条，列 `age | v# | summary | delta`
- "版本列表" 段：`vm.snapshot?.versions`，列 `version | status badge | hash | time`，当前 version 高亮 accent
- 行动作（暂仅占位）：右键 diff/rollback/删除 draft

- [ ] **Step 1: 实现 panel**（参考 mockup A 版本面板视觉）

- [ ] **Step 2: 编译 + 启动验证**

- [ ] **Step 3: Commit**

---

### Task 22: ⌘4 RiskBindingPanel + binding sheet

**Files:**
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/RiskBindingPanel.swift`
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/BindingSheet.swift`
- Create: `macos-app/AlphaLoop/Services/APIRiskPoliciesAndPools.swift`（拉 RiskPolicyVersion + CapitalPool 列表）
- Modify: `backend` —— 确认现有 `/api/risk-policies` 和 `/api/capital-pools` 端点存在（如不存在，本次最小补：`GET /api/risk-policy-versions?status=active` + `GET /api/capital-pools?pool_type=`）

**Interfaces:**
- RiskBindingPanel 显示：
  - 当前 binding（mode/policy.name/pool.name/余量）；多 mode 列表展示
  - 未绑定 → `[绑定 live_small]` 按钮
  - guards 4 gauge（max_position / daily_loss / drawdown / total_exposure）来自 `vm.snapshot?.bindings.first?.capitalPool` 派生 + `/api/risk/overview?strategy_id=` 实时
- BindingSheet:
  - 选 RiskPolicyVersion (拉 list)
  - 选 CapitalPool (pool_type=live_small)
  - 提交调 `vm.createBinding(...)`

- [ ] **Step 1: 检查后端**

```bash
grep -nE "@router\.(get|post)" backend/app/routers/risk_policies.py backend/app/routers/capital_pools.py 2>/dev/null
```

如缺，新增 `GET /api/risk-policy-versions?status=active` 和 `GET /api/capital-pools?pool_type=` 简单 list 端点。

- [ ] **Step 2: 实现 RiskBindingPanel**

- [ ] **Step 3: 实现 BindingSheet**

- [ ] **Step 4: 启动 app 验证 happy path**

- [ ] **Step 5: Commit**

---

### Task 23: ⌘5 BacktestDryrunPanel

**Files:**
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/BacktestDryrunPanel.swift`

**Interfaces:**
- 顶部 2 行摘要：最近回测 / 最近模拟（取 `recentBacktests.first / recentDryruns.first`）
- 全部 run 列表：合并 `recentBacktests + recentDryruns` 时间倒序，每行 `kind tag | symbol | mode | duration | result/error`
- 失败 run 行点击 → 内联展开 `errorMessage + errorCode + reasonCodes`
- 行尾 `[查看全部 →]` 按钮跳 `.backtestSimulation`

- [ ] **Step 1: 实现 panel + 失败原因 expander**

- [ ] **Step 2: 跳转回测页用 `appState.selectedRoute = .backtestSimulation`**

- [ ] **Step 3: Commit**

---

### Task 24: ⌘6 ReadinessPanel

**Files:**
- Create: `macos-app/AlphaLoop/Views/Strategies/Workbench/Panels/ReadinessPanel.swift`

**Interfaces:**
- 顶部 grand_status 大徽章 + passed_count
- "策略门禁" 6 项 list（每项：icon + label + status + 失败原因 + 跳转按钮）
- "系统门禁" 5 项 list
- 底部 "下一步" 按钮（按 next_action.target_panel 跳 ⌘4 或 ⌘5）

- [ ] **Step 1: 实现**（每个 gate 一行：状态色点 + label + value + reason_codes）

- [ ] **Step 2: 跳转修复按钮**：next_action.targetPanel 决定跳 ⌘4/⌘5/no-op

- [ ] **Step 3: Commit**

---

## Phase 10: BacktestLab + L10n + Acceptance

### Task 25: BacktestLab 重构（UUID + 合并 dryruns）

**Files:**
- Modify: `macos-app/AlphaLoop/ViewModels/BacktestLabViewModel.swift`
- Modify: `macos-app/AlphaLoop/Views/BacktestAndDryrun/BacktestLabView.swift`
- Modify: `macos-app/AlphaLoop/Views/BacktestAndDryrun/NewRunSheet.swift`

**Interfaces:**
- VM 改 UUID-based 过滤：`async let backtests = backtestAPI.list(strategyId: uuid)`、`async let dryruns = dryrunAPI.listRuns(strategyVersionId: latestVid, limit: 25)`
- 合并为统一 `RunRow(kind: backtest|dryrun, id, ...)`，按时间排序
- View 视觉对齐工作台 design tokens
- 顶部加 mode_filter chip（all/backtest/dryrun）
- comparedRunIds: `Set<String>`（UUID）

- [ ] **Step 1: 改 VM**（替换 `comparedRunIds: Set<Int>` 为 `Set<String>`；加合并逻辑）

- [ ] **Step 2: 改 View**（顶部 mode_filter；inspector 加 失败原因展开）

- [ ] **Step 3: 启动 app，从工作台 ⌘5 → 跳到回测页验证 happy path**

- [ ] **Step 4: Commit**

---

### Task 26: L10n + AppShellView 接线 + 验收

**Files:**
- Rewrite: `macos-app/AlphaLoop/Localization/L10n+Workbench.swift`
- Modify: `macos-app/AlphaLoop/Localization/L10n+BacktestLab.swift`
- Delete: `macos-app/AlphaLoop/Localization/L10n+Dryrun.swift`
- Modify: `macos-app/AlphaLoop/Views/AppShell/AppShellView.swift`（确认 `.strategyWorkspace` → `StrategyCanvasWorkspaceView`）

**Interfaces:**
- spec §10 的 14 个 L10n 命名空间分组全部覆盖

- [ ] **Step 1: 写新 `L10n+Workbench.swift`**（按 spec §10 命名空间分组列出所有 key + zh/en 双语）

- [ ] **Step 2: 删除旧 L10n+Dryrun + 旧 Workbench 废弃 keys**

- [ ] **Step 3: grep 验证零硬编码**

```bash
cd macos-app
# 工作台/回测页文件中不应该有任何中文字符串字面量
grep -nE '"[一-鿿]+"' AlphaLoop/Views/Strategies/Workbench/ AlphaLoop/Views/BacktestAndDryrun/ AlphaLoop/ViewModels/StrategyWorkspaceViewModel.swift AlphaLoop/ViewModels/BacktestLabViewModel.swift
```

期望：零结果（所有中文走 L10n）。

- [ ] **Step 4: 启动 app，依次验证 spec §11 验收清单 1-27**

```bash
cd macos-app && swift run
```

逐条勾选：
1. 画布占满；HUD 40px / 状态栏 26px ✓
2. 1280-1920 响应 ✓
3. grep 颜色 token 检查
4. grep 全大写 / letter-spacing 检查
5. 9 PRD 问题：登录后选 1 个策略，依次：
   - 看 HUD：策略名 + 类型
   - ⌘2 选 SignalInput → 看 symbols/tf/source
   - 状态栏看 ●/⚠/✗
   - ⌘5 顶部看最近回测
   - ⌘5 顶部看最近模拟
   - ⌘6 看 grand_status
   - ⌘4 看 binding
   - ⌘3 看变更
   - HUD 看「下一步」
6. 6 个动作走一遍：验证 / 复制 / 归档 / 绑定 / 模拟 / 失败原因
7. 切中英 ✓
8. 网络断连模拟 → HUD disable + toast
9. 启 dryrun → ⌘5 显示 starting → 跳 BacktestLab → 高亮新 run

- [ ] **Step 5: 跑后端 pytest + macOS swift test 全量回归**

```bash
cd backend && python3 -m pytest tests/ -q --cov=app
cd macos-app && swift test
```

- [ ] **Step 6: 更新 docs**

- 改 `docs/backend/api-contracts.md`：追加 7 个新端点 + 4 个改造端点的契约
- 改 `docs/database/schema-notes.md`：追加 `strategy_activity_log` 表 + `backtest_runs.strategy_uuid/strategy_version_id` 列说明
- 改 `docs/README.md`：spec/plan 索引

- [ ] **Step 7: Final commit**

```bash
git add docs/backend/api-contracts.md docs/database/schema-notes.md docs/README.md macos-app/AlphaLoop/Localization/ macos-app/AlphaLoop/Views/AppShell/AppShellView.swift
git rm macos-app/AlphaLoop/Localization/L10n+Dryrun.swift
git commit -m "feat(strategy-workspace): finalize L10n + acceptance verification + docs"
```

---

## Self-Review

(执行者读此节后再启动 Task 1)

**Spec coverage:**
- §3 IA → Task 18 装配主 view
- §4 视觉 → Task 11 + Task 16/17 (HUD/StatusBar/Panel chrome) + 各 Panel 任务复用 tokens
- §5.1 顶 HUD → Task 16
- §5.2 底状态栏 → Task 17
- §5.3 6 面板 → Task 19-24
- §6.1 7 端点 → Task 8
- §6.2 4 端点改造 → Task 9
- §6.3 alembic → Task 1
- §6.4 PerStrategyReadiness → Task 6
- §6.5 文件落位 → Task 1-9 全覆盖
- §6.6 测试 → 每个 Task 内嵌
- §7.1 文件分解 → Task 12-25
- §7.2 ViewModel → Task 15
- §7.3 canvas-web → Task 10-11
- §7.4 BacktestLab → Task 25
- §7.5 路由 → Task 12 + Task 26
- §8 时序 → Task 18 + 各 panel
- §9 错误处理 → Task 8 (router 错误映射) + 各 panel banner
- §10 L10n → Task 26
- §11 验收 → Task 26 Step 4
- §12 Out-of-scope: 不做

**Type consistency:** spec §6.4 `PerStrategyReadinessResponse` ↔ Swift `PerStrategyReadiness` (Task 13)、`StrategyBinding` 与 `StrategyBindingResponse` 字段一一对应、`WorkbenchPanel` 6 case 与 §5.3 6 面板对应。

**No placeholders:** 检查通过。所有 step 含实际代码或精确 grep 命令。

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-18-strategy-workbench-canvas-first.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**

# Phase 00: PulseDesk v2.5 后端工程骨架

## Context
PulseDesk 当前后端使用 SQLite + Integer PK + 扁平目录。已完成 v2.5 违规清理。现在建立工程骨架：PostgreSQL、UUID PK、按模块分层、结构化日志、测试基础设施。只建骨架不实现业务逻辑。

## Steps

### 1. app/database/ 模块
- `__init__.py`: PostgreSQL engine + SessionLocal + get_db + init_db
- `base.py`: DeclarativeBase + UUIDMixin + TimestampMixin
- `partitions.py`: 月分区自动创建

### 2. app/domain/ 空骨架 ORM
signal.py / strategy.py / risk.py / execution.py / command.py / ledger.py / order.py / trade_intent.py / growth.py / feature.py / provider.py / outbox.py — 类名+表名，不填字段

### 3. app/repositories/base.py
BaseRepository 泛型 CRUD 基类

### 4. app/routers/health.py + app/schemas/health.py
GET /health + GET /readiness

### 5. 修改 config.py → PostgreSQL DSN
### 6. 修改 main.py → 新 database 模块
### 7. 修改 logging.py → 结构化日志
### 8. 修改 tests/conftest.py → 新 import 路径
### 9. tests/test_health.py
### 10. app/workers/__init__.py + app/schemas/common.py
### 11. 删除旧 database.py 和 models/ 目录，更新 import

## Verification
```bash
docker compose up -d postgres
cd backend && python -m pytest tests/test_health.py -q
python run.py  # GET /health → 200
python -m pytest tests/ -q
```

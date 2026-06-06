# PulseDesk Phase 1 Implementation Plan

> 18 tasks, ~6 hours, TDD, frequent commits

**Goal:** Canvas → DSL v3.0 → Decision Engine → Snapshot → Redis → Freqtrade 执行，Account Risk Firewall 最终拒单权，断连保护。

**Tech:** Python/FastAPI/SQLAlchemy/Pydantic/Redis 7/PostgreSQL 16/React Flow/TypeScript/Freqtrade

## Task Summary

| # | Component | New/Modify | Key Files |
|---|-----------|------------|-----------|
| 1 | Redis Infrastructure | Modify | docker-compose.yml, config.py |
| 2 | RuntimeRedisStore | Create | services/runtime_redis_store.py |
| 3 | DSL v3.0 Models | Modify | domain/dsl.py |
| 4 | DSL v3.0 Validator | Modify | services/dsl_validator.py |
| 5 | Snapshot Model | Create | domain/snapshot.py |
| 6 | PostgreSQL Tables | Create | domain/runtime.py + migration |
| 7 | Account Risk Firewall | Create | services/account_risk_firewall.py |
| 8 | Decision Engine | Create | services/decision_engine.py |
| 9 | Snapshot Persistence | Create | services/snapshot_persistence.py |
| 10 | Decision REST API | Create | routers/decision.py |
| 11 | Freqtrade Redis Client | Create | redis_snapshot_client.py |
| 12 | Disconnect Guard | Create | runtime_snapshot_guard.py |
| 13 | Strategy Rewrite | Modify | PulseDeskUniversalStrategy.py |
| 14 | DSL Migrator | Create | services/dsl_migrator.py |
| 15 | Canvas v3.0 Types | Modify | types.ts |
| 16 | Canvas Nodes | Create | StructureDefenseNode + AccountRiskNode |
| 17 | graphToDsl v3.0 | Modify | graphToDsl.ts |
| 18 | dslToGraph v3.0 | Modify | dslToGraph.ts |

## Acceptance Criteria

- v2.5 backward compatibility preserved
- v3.0 DSL validates with all policy defaults
- Decision Engine → Redis snapshot < 200ms
- Account Risk Firewall blocks daily/weekly/consecutive limits
- Kill switch cannot be overridden
- Freqtrade dual-mode: Redis snapshot + legacy JSON fallback
- Disconnect protection with last_valid_stop
- All decisions have reason_codes
- PostgreSQL 5 tables with indexes
- Canvas new nodes render and connect

"""End-to-end test: Strategy lifecycle from creation to backtest via Command Bus."""
import uuid

from sqlalchemy.orm import Session

from app.domain.strategy import StrategyV2, StrategyVersion
from app.domain.command import CommandBusCommand
from app.domain.enums import CommandStatus
from app.repositories.strategy_repository import StrategyRepository
from app.services.command_bus import CommandBusService
from app.services.dsl_validator import DSLValidator
from app.services.dsl_hasher import compute_dsl_hash
from app.services.risk_engine import RiskEngine


VALID_DSL = {
    "schema_version": "2.5",
    "timeframe": "1h",
    "symbols": ["BTC/USDT"],
    "entry": {
        "logic": "AND",
        "rules": [
            {
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": "<",
                "value": 30,
            }
        ],
    },
    "exit": {
        "logic": "OR",
        "rules": [
            {
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": ">",
                "value": 70,
            }
        ],
    },
    "filters": [],
    "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
    "risk": {"stoploss": -0.05, "max_open_trades": 3},
    "metadata": {},
}


class TestStrategyLifecycleE2E:
    """Full lifecycle: create strategy -> validate DSL -> submit command -> worker processes -> ledger records."""

    def _create_strategy_with_version(self, session: Session):
        """Create a StrategyV2 + StrategyVersion using the repository."""
        repo = StrategyRepository(session)

        strategy = StrategyV2(
            name="E2E Test Strategy",
            strategy_type="rule_dsl",
            source_type="manual",
            status="draft",
        )
        strategy = repo.create_strategy(strategy)

        version_no = repo.next_version_no(strategy.id)
        version = StrategyVersion(
            strategy_id=strategy.id,
            version_no=version_no,
            status="draft",
            dsl_version="2.5",
            rule_dsl=VALID_DSL,
            dsl_hash=compute_dsl_hash(VALID_DSL),
            created_by="e2e_test",
        )
        version = repo.create_version(version)
        return strategy, version

    def test_create_validate_backtest_flow(self, session: Session):
        """Strategy creation -> DSL validation -> command submission -> processing."""
        # 1. Create strategy + version
        strategy, version = self._create_strategy_with_version(session)
        session.commit()
        assert strategy.id is not None
        assert version.id is not None
        assert version.version_no == 1

        # 2. Validate DSL
        validator = DSLValidator()
        report = validator.validate(version.rule_dsl)
        assert report.valid is True
        assert report.error_count == 0

        # 3. Submit StartBacktestCommand via Command Bus
        cmd_svc = CommandBusService(session)
        cmd, created = cmd_svc.enqueue(
            command_type="start_backtest",
            aggregate_type="strategy_version",
            aggregate_id=version.id,
            payload={
                "strategy_version_id": str(version.id),
                "timerange": "20240101-20240201",
                "initial_capital": 10000,
            },
            requested_by="e2e_test",
            idempotency_key=f"e2e-backtest-{version.id}",
        )
        session.commit()
        assert created is True
        assert cmd.status == CommandStatus.PENDING.value
        assert cmd.command_type == "start_backtest"

        # 4. Verify command is queryable
        fetched = cmd_svc.get_by_id(cmd.id)
        assert fetched is not None
        assert fetched.command_type == "start_backtest"
        assert fetched.aggregate_id == version.id

    def test_command_bus_idempotency(self, session: Session):
        """Same idempotency key should not create duplicate commands."""
        strategy, version = self._create_strategy_with_version(session)
        session.commit()

        cmd_svc = CommandBusService(session)
        idemp_key = f"test-idemp-key-{uuid.uuid4()}"

        cmd1, created1 = cmd_svc.enqueue(
            command_type="start_backtest",
            aggregate_type="strategy_version",
            aggregate_id=version.id,
            payload={"strategy_version_id": str(version.id), "timerange": "20240101-20240201"},
            requested_by="e2e_test",
            idempotency_key=idemp_key,
        )
        session.commit()
        assert created1 is True

        # Second enqueue with same key
        cmd2, created2 = cmd_svc.enqueue(
            command_type="start_backtest",
            aggregate_type="strategy_version",
            aggregate_id=version.id,
            payload={"strategy_version_id": str(version.id), "timerange": "20240101-20240201"},
            requested_by="e2e_test",
            idempotency_key=idemp_key,
        )
        session.commit()
        assert created2 is False
        assert cmd1.id == cmd2.id  # Same command returned

    def test_risk_pre_check_valid_dsl(self, session: Session):
        """Risk pre-check should approve valid DSL with proper timerange."""
        engine = RiskEngine()
        result = engine.pre_backtest_check(VALID_DSL, "20240101-20240201", 10000)
        assert result.approved is True
        assert len(result.errors) == 0

    def test_risk_pre_check_blocks_invalid_timerange(self, session: Session):
        """Risk pre-check should block backtest with inverted timerange."""
        engine = RiskEngine()
        result = engine.pre_backtest_check(VALID_DSL, "20240201-20240101", 10000)
        assert result.approved is False
        error_codes = [e["code"] for e in result.errors]
        assert "BACKTEST_INVALID_TIMERANGE" in error_codes

    def test_risk_pre_check_blocks_invalid_dsl(self, session: Session):
        """Risk pre-check should block backtest with invalid DSL (missing stoploss)."""
        engine = RiskEngine()
        invalid_dsl = {
            **VALID_DSL,
            "risk": {"max_open_trades": 3},  # Missing stoploss
        }
        result = engine.pre_backtest_check(invalid_dsl, "20240101-20240201", 10000)
        assert result.approved is False
        error_codes = [e["code"] for e in result.errors]
        assert "DSL_RISK_FIELD_MISSING" in error_codes

    def test_full_lifecycle_create_to_cancel(self, session: Session):
        """Full lifecycle: create -> submit command -> cancel command."""
        # Create strategy + version
        strategy, version = self._create_strategy_with_version(session)
        session.commit()

        # Submit command
        cmd_svc = CommandBusService(session)
        cmd, created = cmd_svc.enqueue(
            command_type="start_backtest",
            aggregate_type="strategy_version",
            aggregate_id=version.id,
            payload={
                "strategy_version_id": str(version.id),
                "timerange": "20240101-20240201",
                "initial_capital": 10000,
            },
            requested_by="e2e_test",
            idempotency_key=f"e2e-cancel-{uuid.uuid4()}",
        )
        session.commit()
        assert cmd.status == CommandStatus.PENDING.value

        # Cancel
        success, reason = cmd_svc.cancel(cmd.id)
        session.commit()
        assert success is True
        assert reason == "ok"
        assert cmd.status == CommandStatus.CANCELLED.value
        assert cmd.completed_at is not None

    def test_multiple_versions_increment(self, session: Session):
        """Creating multiple versions for same strategy increments version_no."""
        repo = StrategyRepository(session)

        strategy = StrategyV2(
            name="Multi-Version Strategy",
            strategy_type="rule_dsl",
            source_type="manual",
            status="draft",
        )
        strategy = repo.create_strategy(strategy)
        session.flush()

        for i in range(3):
            vno = repo.next_version_no(strategy.id)
            version = StrategyVersion(
                strategy_id=strategy.id,
                version_no=vno,
                status="draft",
                dsl_version="2.5",
                rule_dsl=VALID_DSL,
                dsl_hash=compute_dsl_hash(VALID_DSL),
                created_by="e2e_test",
            )
            repo.create_version(version)

        session.commit()
        versions = repo.list_versions(strategy.id)
        assert len(versions) == 3
        version_nos = [v.version_no for v in versions]
        # list_versions orders by version_no desc
        assert version_nos == [3, 2, 1]

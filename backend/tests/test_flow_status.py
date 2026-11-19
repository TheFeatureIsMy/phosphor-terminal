"""A successful backtest advances a draft or validated version to backtested."""
import uuid
from unittest.mock import patch

from app.domain.enums import StrategyVersionStatus as S
from app.domain.strategy import StrategyV2, StrategyVersion
from app.services.backtest_runner import BacktestMetrics, BacktestResult
from app.services.strategy_transition import apply_backtest_success_status, validate_transition
from app.workers.backtest_handler import StartBacktestHandler
from tests.test_backtest_handler import VALID_PAYLOAD, _make_command


def test_draft_and_validated_become_backtested():
    for start in ("draft", "validated"):
        version = StrategyVersion(
            strategy_id=uuid.uuid4(),
            version_no=1,
            status=start,
            dsl_version="2.5",
            rule_dsl={"timeframe": "15m"},
            dsl_hash="hash",
            created_by="test",
        )
        taken = apply_backtest_success_status(version)
        print("FROM", start, "STEPS", [(a.value, b.value) for a, b in taken], "STATUS", version.status)
        assert version.status == S.BACKTESTED.value
        assert taken
        for before, after in taken:
            validate_transition(before, after)


@patch("app.workers.backtest_handler.FreqtradeBacktestRunner")
def test_handler_success_marks_draft_version_backtested(mock_runner_cls, session):
    strategy = StrategyV2(
        name="flow", strategy_type="dsl", source_type="manual", status="active",
    )
    session.add(strategy)
    session.flush()
    version = StrategyVersion(
        strategy_id=strategy.id,
        version_no=1,
        status="draft",
        dsl_version="2.5",
        rule_dsl={"timeframe": "15m"},
        dsl_hash="hash",
        created_by="test",
    )
    session.add(version)
    session.flush()

    mock_runner_cls.return_value.run.return_value = BacktestResult(
        success=True,
        metrics=BacktestMetrics(total_trades=56, win_rate=40 / 56, absolute_profit=3.957),
    )
    payload = {**VALID_PAYLOAD, "strategy_version_id": str(version.id)}
    command = _make_command(session, payload)
    StartBacktestHandler().execute(command, session)
    session.refresh(version)
    print("HANDLER_STATUS", version.status)
    assert version.status == "backtested"

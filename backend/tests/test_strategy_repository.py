"""Strategy Repository tests."""
import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.domain.strategy import StrategyV2, StrategyVersion
from app.repositories.strategy_repository import StrategyRepository


class TestStrategyRepository:
    def test_create_strategy(self, session: Session):
        repo = StrategyRepository(session)
        s = StrategyV2(name="RSI Bottom", strategy_type="bottom_accumulation",
                       source_type="manual", status="draft")
        repo.create_strategy(s)
        session.commit()
        assert s.id is not None
        assert s.status == "draft"

    def test_get_strategy_by_id(self, session: Session):
        repo = StrategyRepository(session)
        s = StrategyV2(name="Test", strategy_type="ma_cross", source_type="manual")
        repo.create_strategy(s)
        session.commit()
        found = repo.get_strategy_by_id(s.id)
        assert found is not None
        assert found.name == "Test"

    def test_list_strategies(self, session: Session):
        repo = StrategyRepository(session)
        for i in range(3):
            repo.create_strategy(StrategyV2(
                name=f"S{i}", strategy_type="test", source_type="manual", status="draft",
            ))
        session.commit()
        results = repo.list_strategies()
        assert len(results) == 3

    def test_list_strategies_filter_status(self, session: Session):
        repo = StrategyRepository(session)
        repo.create_strategy(StrategyV2(name="A", strategy_type="t", source_type="m", status="draft"))
        repo.create_strategy(StrategyV2(name="B", strategy_type="t", source_type="m", status="active"))
        session.commit()
        drafts = repo.list_strategies(status="draft")
        assert len(drafts) == 1
        assert drafts[0].name == "A"

    def test_create_version(self, session: Session):
        repo = StrategyRepository(session)
        s = StrategyV2(name="S", strategy_type="t", source_type="m")
        repo.create_strategy(s)
        v = StrategyVersion(
            strategy_id=s.id, version_no=1, dsl_version="2.5",
            rule_dsl={"entry": {"logic": "AND", "rules": []}},
            dsl_hash="sha256:abc", created_by="test",
        )
        repo.create_version(v)
        session.commit()
        assert v.id is not None
        assert v.version_no == 1

    def test_next_version_no(self, session: Session):
        repo = StrategyRepository(session)
        s = StrategyV2(name="S", strategy_type="t", source_type="m")
        repo.create_strategy(s)
        assert repo.next_version_no(s.id) == 1

        repo.create_version(StrategyVersion(
            strategy_id=s.id, version_no=1, dsl_version="2.5",
            rule_dsl={}, dsl_hash="h1", created_by="test",
        ))
        session.commit()
        assert repo.next_version_no(s.id) == 2

    def test_get_latest_version(self, session: Session):
        repo = StrategyRepository(session)
        s = StrategyV2(name="S", strategy_type="t", source_type="m")
        repo.create_strategy(s)
        repo.create_version(StrategyVersion(
            strategy_id=s.id, version_no=1, dsl_version="2.5",
            rule_dsl={}, dsl_hash="h1", created_by="test",
        ))
        repo.create_version(StrategyVersion(
            strategy_id=s.id, version_no=2, dsl_version="2.5",
            rule_dsl={"v": 2}, dsl_hash="h2", created_by="test",
        ))
        session.commit()
        latest = repo.get_latest_version(s.id)
        assert latest.version_no == 2

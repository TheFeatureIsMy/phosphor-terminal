"""Execution Ledger Repository tests — append-only + idempotent."""
import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.domain.ledger import ExecutionLedgerEvent
from app.repositories.ledger_repository import LedgerRepository


def _make_event(**overrides) -> ExecutionLedgerEvent:
    now = datetime.now(timezone.utc)
    defaults = dict(
        id=uuid.uuid4(), event_time=now,
        event_type="PULSEDESK_COMMAND_STARTED", source_system="pulsedesk",
        event_hash="placeholder", normalized_payload={"test": True},
        schema_version="2.5",
    )
    defaults.update(overrides)
    if defaults["event_hash"] == "placeholder":
        defaults["event_hash"] = LedgerRepository.compute_event_hash(
            defaults["source_system"], defaults.get("source_event_id"),
            defaults["event_type"], defaults["normalized_payload"],
            defaults["event_time"],
        )
    return ExecutionLedgerEvent(**defaults)


class TestEventHash:
    def test_deterministic(self):
        h1 = LedgerRepository.compute_event_hash("pulsedesk", "evt-1", "TEST", {"a": 1})
        h2 = LedgerRepository.compute_event_hash("pulsedesk", "evt-1", "TEST", {"a": 1})
        assert h1 == h2
        assert len(h1) == 64

    def test_differs_on_content(self):
        h1 = LedgerRepository.compute_event_hash("pulsedesk", "evt-1", "TEST", {"a": 1})
        h2 = LedgerRepository.compute_event_hash("pulsedesk", "evt-1", "TEST", {"a": 2})
        assert h1 != h2

    def test_differs_on_source_system(self):
        h1 = LedgerRepository.compute_event_hash("pulsedesk", "evt-1", "TEST", {"a": 1})
        h2 = LedgerRepository.compute_event_hash("freqtrade", "evt-1", "TEST", {"a": 1})
        assert h1 != h2

    def test_differs_on_event_type(self):
        h1 = LedgerRepository.compute_event_hash("pulsedesk", "evt-1", "TYPE_A", {"a": 1})
        h2 = LedgerRepository.compute_event_hash("pulsedesk", "evt-1", "TYPE_B", {"a": 1})
        assert h1 != h2

    def test_without_source_event_id_uses_time_bucket(self):
        t1 = datetime(2025, 1, 1, 10, 0, tzinfo=timezone.utc)
        t2 = datetime(2025, 1, 1, 10, 30, tzinfo=timezone.utc)
        t3 = datetime(2025, 1, 1, 11, 0, tzinfo=timezone.utc)
        h1 = LedgerRepository.compute_event_hash("pulsedesk", None, "TEST", {"a": 1}, t1)
        h2 = LedgerRepository.compute_event_hash("pulsedesk", None, "TEST", {"a": 1}, t2)
        h3 = LedgerRepository.compute_event_hash("pulsedesk", None, "TEST", {"a": 1}, t3)
        assert h1 == h2  # same hour bucket
        assert h1 != h3  # different hour bucket


class TestAppendIdempotency:
    def test_append_event(self, session: Session):
        repo = LedgerRepository(session)
        evt = _make_event()
        result, created = repo.append(evt)
        session.commit()
        assert created is True
        assert result.id == evt.id

    def test_hash_idempotent(self, session: Session):
        repo = LedgerRepository(session)
        now = datetime.now(timezone.utc)
        evt1 = _make_event(
            event_time=now, source_system="pulsedesk",
            source_event_id="cmd-1", event_type="PULSEDESK_COMMAND_STARTED",
            normalized_payload={"cmd": "test"},
        )
        result1, created1 = repo.append(evt1)
        session.commit()
        assert created1 is True

        evt2 = _make_event(
            id=uuid.uuid4(), event_time=now, source_system="pulsedesk",
            source_event_id="cmd-1", event_type="PULSEDESK_COMMAND_STARTED",
            normalized_payload={"cmd": "test"},
        )
        result2, created2 = repo.append(evt2)
        assert created2 is False
        assert result2.id == result1.id

    def test_source_event_idempotent(self, session: Session):
        """Same source_system + source_event_id + event_type + event_time → dedup."""
        repo = LedgerRepository(session)
        now = datetime.now(timezone.utc)

        evt1 = _make_event(
            event_time=now, source_system="freqtrade",
            source_event_id="order-123", event_type="FREQTRADE_ORDER_OPENED",
            normalized_payload={"order_id": "order-123", "status": "open"},
        )
        result1, created1 = repo.append(evt1)
        session.commit()
        assert created1 is True

        evt2 = _make_event(
            id=uuid.uuid4(), event_time=now, source_system="freqtrade",
            source_event_id="order-123", event_type="FREQTRADE_ORDER_OPENED",
            normalized_payload={"order_id": "order-123", "status": "open", "extra": True},
        )
        result2, created2 = repo.append(evt2)
        assert created2 is False
        assert result2.id == result1.id

    def test_different_source_event_id_not_deduped(self, session: Session):
        repo = LedgerRepository(session)
        now = datetime.now(timezone.utc)

        evt1 = _make_event(
            event_time=now, source_system="freqtrade",
            source_event_id="order-111", event_type="FREQTRADE_ORDER_OPENED",
            normalized_payload={"order_id": "order-111"},
        )
        evt2 = _make_event(
            event_time=now, source_system="freqtrade",
            source_event_id="order-222", event_type="FREQTRADE_ORDER_OPENED",
            normalized_payload={"order_id": "order-222"},
        )
        _, c1 = repo.append(evt1)
        _, c2 = repo.append(evt2)
        session.commit()
        assert c1 is True
        assert c2 is True

    def test_no_source_event_id_not_source_deduped(self, session: Session):
        """Events without source_event_id skip the source dedup path."""
        repo = LedgerRepository(session)
        now = datetime.now(timezone.utc)

        evt1 = _make_event(
            event_time=now, source_system="pulsedesk",
            event_type="PULSEDESK_SAFE_HOLD_ENTERED",
            normalized_payload={"reason": "drawdown"},
        )
        _, c1 = repo.append(evt1)
        session.commit()
        assert c1 is True

        evt2 = _make_event(
            id=uuid.uuid4(), event_time=now, source_system="pulsedesk",
            event_type="PULSEDESK_SAFE_HOLD_ENTERED",
            normalized_payload={"reason": "drawdown-2"},
        )
        _, c2 = repo.append(evt2)
        session.commit()
        assert c2 is True


class TestQueries:
    def test_list_by_strategy_run(self, session: Session):
        repo = LedgerRepository(session)
        run_id = uuid.uuid4()
        for i in range(3):
            evt = _make_event(strategy_run_id=run_id, normalized_payload={"i": i})
            repo.append(evt)
        repo.append(_make_event(normalized_payload={"other": True}))
        session.commit()
        assert len(repo.list_by_strategy_run(run_id)) == 3

    def test_list_by_command(self, session: Session):
        repo = LedgerRepository(session)
        cmd_id = uuid.uuid4()
        for i in range(2):
            evt = _make_event(command_id=cmd_id, normalized_payload={"step": i})
            repo.append(evt)
        session.commit()
        assert len(repo.list_by_command(cmd_id)) == 2

    def test_list_by_correlation_id(self, session: Session):
        repo = LedgerRepository(session)
        corr_id = uuid.uuid4()
        for i in range(4):
            evt = _make_event(correlation_id=corr_id, normalized_payload={"seq": i})
            repo.append(evt)
        repo.append(_make_event(normalized_payload={"noise": True}))
        session.commit()
        assert len(repo.list_by_correlation_id(corr_id)) == 4

    def test_list_by_event_type(self, session: Session):
        repo = LedgerRepository(session)
        for i in range(2):
            repo.append(_make_event(event_type="FREQTRADE_ORDER_FILLED", normalized_payload={"i": i}))
        repo.append(_make_event(event_type="FREQTRADE_RUN_STARTED", normalized_payload={"x": 1}))
        session.commit()
        assert len(repo.list_by_event_type("FREQTRADE_ORDER_FILLED")) == 2

    def test_list_by_symbol(self, session: Session):
        repo = LedgerRepository(session)
        repo.append(_make_event(symbol="BTC/USDT", normalized_payload={"s": 1}))
        repo.append(_make_event(symbol="BTC/USDT", normalized_payload={"s": 2}))
        repo.append(_make_event(symbol="ETH/USDT", normalized_payload={"s": 3}))
        session.commit()
        assert len(repo.list_by_symbol("BTC/USDT")) == 2

    def test_find_by_source_event(self, session: Session):
        repo = LedgerRepository(session)
        now = datetime.now(timezone.utc)
        evt = _make_event(
            event_time=now, source_system="freqtrade",
            source_event_id="fill-99", event_type="FREQTRADE_ORDER_FILLED",
            normalized_payload={"fill": 99},
        )
        repo.append(evt)
        session.commit()

        found = repo.find_by_source_event("freqtrade", "fill-99", "FREQTRADE_ORDER_FILLED", now)
        assert found is not None
        assert found.id == evt.id

        missing = repo.find_by_source_event("freqtrade", "fill-00", "FREQTRADE_ORDER_FILLED", now)
        assert missing is None

    def test_list_events_combined_filter(self, session: Session):
        repo = LedgerRepository(session)
        run_id = uuid.uuid4()
        repo.append(_make_event(
            strategy_run_id=run_id, event_type="FREQTRADE_ORDER_OPENED",
            symbol="BTC/USDT", normalized_payload={"match": True},
        ))
        repo.append(_make_event(
            strategy_run_id=run_id, event_type="FREQTRADE_ORDER_FILLED",
            symbol="BTC/USDT", normalized_payload={"no_match": True},
        ))
        session.commit()

        results = repo.list_events(
            strategy_run_id=run_id, event_type="FREQTRADE_ORDER_OPENED",
        )
        assert len(results) == 1
        assert results[0].normalized_payload["match"] is True

    def test_pagination(self, session: Session):
        repo = LedgerRepository(session)
        run_id = uuid.uuid4()
        for i in range(5):
            repo.append(_make_event(strategy_run_id=run_id, normalized_payload={"i": i}))
        session.commit()

        page1 = repo.list_by_strategy_run(run_id, offset=0, limit=2)
        page2 = repo.list_by_strategy_run(run_id, offset=2, limit=2)
        page3 = repo.list_by_strategy_run(run_id, offset=4, limit=2)
        assert len(page1) == 2
        assert len(page2) == 2
        assert len(page3) == 1

    def test_get_by_id(self, session: Session):
        repo = LedgerRepository(session)
        evt = _make_event()
        repo.append(evt)
        session.commit()

        found = repo.get_by_id(evt.id)
        assert found is not None
        assert found.event_hash == evt.event_hash

        missing = repo.get_by_id(uuid.uuid4())
        assert missing is None

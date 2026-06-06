"""Execution Ledger Service tests."""
import uuid
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.services.ledger_service import LedgerService, SCHEMA_VERSION
from app.domain.enums import LedgerEventType, LedgerSourceSystem


class TestRecordEvent:
    def test_auto_hash_and_schema_version(self, session: Session):
        svc = LedgerService(session)
        event, created = svc.record_event(
            event_type=LedgerEventType.PULSEDESK_COMMAND_STARTED.value,
            source_system=LedgerSourceSystem.PULSEDESK.value,
            normalized_payload={"cmd": "deploy"},
        )
        session.commit()
        assert created is True
        assert len(event.event_hash) == 64
        assert event.schema_version == SCHEMA_VERSION

    def test_with_correlation_and_causation(self, session: Session):
        svc = LedgerService(session)
        corr = uuid.uuid4()
        cause = uuid.uuid4()
        cmd = uuid.uuid4()
        event, created = svc.record_event(
            event_type=LedgerEventType.PULSEDESK_COMMAND_STARTED.value,
            source_system=LedgerSourceSystem.PULSEDESK.value,
            normalized_payload={"cmd": "start"},
            correlation_id=corr,
            causation_id=cause,
            command_id=cmd,
        )
        session.commit()
        assert event.correlation_id == corr
        assert event.causation_id == cause
        assert event.command_id == cmd

    def test_raw_and_normalized_payload_separate(self, session: Session):
        svc = LedgerService(session)
        raw = {"freqtrade_raw": True, "extra_field": "x"}
        norm = {"order_id": "123", "status": "open"}
        event, _ = svc.record_event(
            event_type=LedgerEventType.FREQTRADE_ORDER_OPENED.value,
            source_system=LedgerSourceSystem.FREQTRADE.value,
            normalized_payload=norm,
            raw_payload=raw,
        )
        session.commit()
        assert event.raw_payload == raw
        assert event.normalized_payload == norm
        assert event.raw_payload != event.normalized_payload

    def test_idempotent_same_hash(self, session: Session):
        svc = LedgerService(session)
        now = datetime.now(timezone.utc)
        kwargs = dict(
            event_type=LedgerEventType.PULSEDESK_COMMAND_SUCCEEDED.value,
            source_system=LedgerSourceSystem.PULSEDESK.value,
            source_event_id="cmd-abc",
            normalized_payload={"result": "ok"},
            event_time=now,
        )
        e1, c1 = svc.record_event(**kwargs)
        session.commit()
        e2, c2 = svc.record_event(**kwargs)
        assert c1 is True
        assert c2 is False
        assert e1.id == e2.id

    def test_idempotent_source_event(self, session: Session):
        svc = LedgerService(session)
        now = datetime.now(timezone.utc)
        e1, c1 = svc.record_event(
            event_type=LedgerEventType.FREQTRADE_ORDER_FILLED.value,
            source_system=LedgerSourceSystem.FREQTRADE.value,
            source_event_id="fill-42",
            normalized_payload={"fill_id": "42", "price": 100},
            event_time=now,
        )
        session.commit()
        assert c1 is True

        e2, c2 = svc.record_event(
            event_type=LedgerEventType.FREQTRADE_ORDER_FILLED.value,
            source_system=LedgerSourceSystem.FREQTRADE.value,
            source_event_id="fill-42",
            normalized_payload={"fill_id": "42", "price": 100, "extra": "retry"},
            event_time=now,
        )
        assert c2 is False
        assert e2.id == e1.id

    def test_all_event_types_writable(self, session: Session):
        svc = LedgerService(session)
        for et in LedgerEventType:
            source = LedgerSourceSystem.FREQTRADE.value if et.value.startswith("FREQTRADE") else LedgerSourceSystem.PULSEDESK.value
            event, created = svc.record_event(
                event_type=et.value,
                source_system=source,
                normalized_payload={"type": et.value},
            )
            assert created is True
        session.commit()


class TestGetEventChain:
    def test_chain_by_correlation(self, session: Session):
        svc = LedgerService(session)
        corr = uuid.uuid4()
        cmd_id = uuid.uuid4()

        svc.record_event(
            event_type=LedgerEventType.PULSEDESK_COMMAND_STARTED.value,
            source_system=LedgerSourceSystem.PULSEDESK.value,
            normalized_payload={"step": "started"},
            correlation_id=corr, command_id=cmd_id,
        )
        svc.record_event(
            event_type=LedgerEventType.FREQTRADE_RUN_STARTED.value,
            source_system=LedgerSourceSystem.FREQTRADE.value,
            normalized_payload={"step": "ft_start"},
            correlation_id=corr, command_id=cmd_id,
        )
        svc.record_event(
            event_type=LedgerEventType.PULSEDESK_COMMAND_SUCCEEDED.value,
            source_system=LedgerSourceSystem.PULSEDESK.value,
            normalized_payload={"step": "done"},
            correlation_id=corr, command_id=cmd_id,
        )
        svc.record_event(
            event_type=LedgerEventType.FREQTRADE_RUN_HEARTBEAT.value,
            source_system=LedgerSourceSystem.FREQTRADE.value,
            normalized_payload={"noise": True},
        )
        session.commit()

        chain = svc.get_event_chain(corr)
        assert len(chain) == 3
        assert all(e.correlation_id == corr for e in chain)

    def test_get_event_by_id(self, session: Session):
        svc = LedgerService(session)
        event, _ = svc.record_event(
            event_type=LedgerEventType.PULSEDESK_COMMAND_STARTED.value,
            source_system=LedgerSourceSystem.PULSEDESK.value,
            normalized_payload={"lookup": True},
        )
        session.commit()

        found = svc.get_event(event.id)
        assert found is not None
        assert found.normalized_payload["lookup"] is True

        missing = svc.get_event(uuid.uuid4())
        assert missing is None


class TestListEvents:
    def test_filter_by_source_system(self, session: Session):
        svc = LedgerService(session)
        svc.record_event(
            event_type=LedgerEventType.FREQTRADE_RUN_STARTED.value,
            source_system=LedgerSourceSystem.FREQTRADE.value,
            normalized_payload={"ft": True},
        )
        svc.record_event(
            event_type=LedgerEventType.PULSEDESK_COMMAND_STARTED.value,
            source_system=LedgerSourceSystem.PULSEDESK.value,
            normalized_payload={"pd": True},
        )
        session.commit()

        ft_events = svc.list_events(source_system="freqtrade")
        assert len(ft_events) == 1
        assert ft_events[0].source_system == "freqtrade"

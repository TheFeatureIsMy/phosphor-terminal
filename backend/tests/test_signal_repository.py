"""Signal Repository tests."""
import uuid
from datetime import datetime, timezone, timedelta

import pytest
from sqlalchemy.orm import Session

from app.repositories.signal_repository import SignalRepository
from app.domain.signal import SignalPayload, SignalEvidence


class TestSignalRepository:
    def test_create_signal(self, session: Session):
        repo = SignalRepository(session)
        sig = repo.create_signal(
            signal_id=uuid.uuid4(), source_type="test", symbol="BTC/USDT",
            market="crypto", direction="long", status="pending",
            valid_from=datetime.now(timezone.utc), confidence=0.85,
        )
        session.commit()
        assert sig.symbol == "BTC/USDT"
        assert sig.direction == "long"
        assert float(sig.confidence) == 0.85

    def test_get_by_id(self, session: Session):
        repo = SignalRepository(session)
        sid = uuid.uuid4()
        repo.create_signal(
            signal_id=sid, source_type="test", symbol="ETH/USDT",
            market="crypto", direction="short", status="active",
            valid_from=datetime.now(timezone.utc),
        )
        session.commit()
        found = repo.get_by_id(sid)
        assert found is not None
        assert found.symbol == "ETH/USDT"

    def test_get_by_id_not_found(self, session: Session):
        repo = SignalRepository(session)
        assert repo.get_by_id(uuid.uuid4()) is None

    def test_list_signals_with_filter(self, session: Session):
        repo = SignalRepository(session)
        now = datetime.now(timezone.utc)
        repo.create_signal(signal_id=uuid.uuid4(), source_type="ai", symbol="BTC/USDT",
                           market="crypto", direction="long", status="active", valid_from=now)
        repo.create_signal(signal_id=uuid.uuid4(), source_type="manual", symbol="ETH/USDT",
                           market="crypto", direction="short", status="pending", valid_from=now)
        repo.create_signal(signal_id=uuid.uuid4(), source_type="ai", symbol="BTC/USDT",
                           market="crypto", direction="risk", status="active", valid_from=now)
        session.commit()

        btc_active = repo.list_signals(symbol="BTC/USDT", status="active")
        assert len(btc_active) == 2

        ai_only = repo.list_signals(source_type="ai")
        assert len(ai_only) == 2

        all_sigs = repo.list_signals()
        assert len(all_sigs) == 3

    def test_count_signals(self, session: Session):
        repo = SignalRepository(session)
        now = datetime.now(timezone.utc)
        for i in range(5):
            repo.create_signal(signal_id=uuid.uuid4(), source_type="test", symbol="BTC/USDT",
                               market="crypto", direction="long", status="active", valid_from=now)
        session.commit()
        assert repo.count_signals() == 5
        assert repo.count_signals(status="active") == 5
        assert repo.count_signals(status="expired") == 0

    def test_save_and_get_payload(self, session: Session):
        repo = SignalRepository(session)
        sid = uuid.uuid4()
        repo.create_signal(signal_id=sid, source_type="test", symbol="BTC/USDT",
                           market="crypto", direction="long", status="active",
                           valid_from=datetime.now(timezone.utc))
        payload = SignalPayload(signal_id=sid, reasoning="RSI oversold at 25")
        repo.save_payload(payload)
        session.commit()

        loaded = repo.get_payload(sid)
        assert loaded is not None
        assert loaded.reasoning == "RSI oversold at 25"

    def test_add_and_get_evidence(self, session: Session):
        repo = SignalRepository(session)
        sid = uuid.uuid4()
        repo.create_signal(signal_id=sid, source_type="test", symbol="BTC/USDT",
                           market="crypto", direction="long", status="active",
                           valid_from=datetime.now(timezone.utc))
        repo.add_evidence(SignalEvidence(signal_id=sid, evidence_type="indicator", evidence_ref="RSI=25"))
        repo.add_evidence(SignalEvidence(signal_id=sid, evidence_type="news", evidence_ref="BTC ETF approved"))
        session.commit()

        evidence = repo.get_evidence(sid)
        assert len(evidence) == 2

    def test_transition_status_writes_lifecycle(self, session: Session):
        repo = SignalRepository(session)
        sid = uuid.uuid4()
        repo.create_signal(signal_id=sid, source_type="test", symbol="BTC/USDT",
                           market="crypto", direction="long", status="pending",
                           valid_from=datetime.now(timezone.utc))
        session.commit()

        sig = repo.transition_status(sid, "active", reason="confirmed", actor="system")
        session.commit()
        assert sig.status == "active"

        from app.domain.signal import SignalLifecycleEvent
        from sqlalchemy import select
        events = list(session.scalars(
            select(SignalLifecycleEvent).where(SignalLifecycleEvent.signal_id == sid)
        ).all())
        assert len(events) == 1
        assert events[0].from_status == "pending"
        assert events[0].to_status == "active"
        assert events[0].reason == "confirmed"

    def test_transition_nonexistent_signal(self, session: Session):
        repo = SignalRepository(session)
        result = repo.transition_status(uuid.uuid4(), "active")
        assert result is None

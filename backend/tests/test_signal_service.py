"""Tests for SignalService."""
import uuid
from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy.orm import Session

from app.services.signal_service import SignalService
from app.domain.signal import Signal, SignalIdentity, SignalPayload, SignalLifecycleEvent


class TestCreateSignal:
    def test_creates_signal_with_lifecycle_event(self, session: Session):
        svc = SignalService(session)
        data = {
            "source_type": "ai_research",
            "symbol": "BTC/USDT",
            "direction": "long",
            "confidence": 0.85,
            "risk_level": "medium",
            "expires_at": datetime.now(timezone.utc) + timedelta(hours=24),
            "reasoning": "Strong RSI divergence",
        }
        signal = svc.create_signal(data)
        session.commit()
        assert signal is not None
        assert signal.status == "pending"
        # Verify lifecycle event was created
        events = session.query(SignalLifecycleEvent).filter(
            SignalLifecycleEvent.signal_id == signal.id
        ).all()
        assert len(events) >= 1

    def test_creates_payload_when_provided(self, session: Session):
        svc = SignalService(session)
        data = {
            "source_type": "manual",
            "symbol": "ETH/USDT",
            "direction": "short",
            "confidence": 0.7,
            "risk_level": "high",
            "expires_at": datetime.now(timezone.utc) + timedelta(hours=12),
            "reasoning": "Bearish engulfing",
            "structured_output": {"pattern": "bearish_engulfing"},
        }
        signal = svc.create_signal(data)
        session.commit()
        payload = session.query(SignalPayload).filter(
            SignalPayload.signal_id == signal.id
        ).first()
        assert payload is not None


class TestTransitionStatus:
    def test_valid_transition(self, session: Session):
        svc = SignalService(session)
        signal = svc.create_signal({
            "source_type": "ai_research", "symbol": "BTC/USDT",
            "direction": "long", "confidence": 0.8, "risk_level": "low",
            "expires_at": datetime.now(timezone.utc) + timedelta(hours=24),
            "reasoning": "test",
        })
        session.commit()
        updated = svc.transition_status(signal.id, "active")
        session.commit()
        assert updated.status == "active"

    def test_invalid_transition_raises(self, session: Session):
        svc = SignalService(session)
        signal = svc.create_signal({
            "source_type": "manual", "symbol": "BTC/USDT",
            "direction": "long", "confidence": 0.5, "risk_level": "medium",
            "expires_at": datetime.now(timezone.utc) + timedelta(hours=24),
            "reasoning": "test",
        })
        session.commit()
        with pytest.raises(ValueError):
            svc.transition_status(signal.id, "executed")  # Can't go pending->executed


class TestConflictCheck:
    def test_finds_opposing_signals(self, session: Session):
        svc = SignalService(session)
        # Create a long signal
        signal = svc.create_signal({
            "source_type": "ai_research", "symbol": "BTC/USDT",
            "direction": "long", "confidence": 0.8, "risk_level": "low",
            "expires_at": datetime.now(timezone.utc) + timedelta(hours=24),
            "reasoning": "bullish",
        })
        session.commit()
        # Activate it
        svc.transition_status(signal.id, "active")
        session.commit()
        # Check for conflict with short direction
        result = svc.conflict_check("BTC/USDT", "short")
        assert result["has_conflict"] is True


class TestAggregate:
    def test_aggregates_by_symbol(self, session: Session):
        svc = SignalService(session)
        for sym in ["BTC/USDT", "BTC/USDT", "ETH/USDT"]:
            s = svc.create_signal({
                "source_type": "ai_research", "symbol": sym,
                "direction": "long", "confidence": 0.7, "risk_level": "low",
                "expires_at": datetime.now(timezone.utc) + timedelta(hours=24),
                "reasoning": "test",
            })
            svc.transition_status(s.id, "active")
        session.commit()
        result = svc.aggregate(group_by="symbol")
        assert result["total_count"] >= 3

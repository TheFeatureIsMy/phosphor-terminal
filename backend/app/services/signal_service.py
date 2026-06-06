"""Signal Center business logic layer."""
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select, func, and_
from sqlalchemy.orm import Session

from app.domain.signal import (
    Signal, SignalPayload, SignalEvidence,
    SignalLifecycleEvent, SignalSnapshot, SignalIdentity,
)
from app.domain.enums import SignalStatus
from app.repositories.signal_repository import SignalRepository


class SignalService:
    """Wraps SignalRepository with business logic, lifecycle events, and validation."""

    # Valid status transitions per v2.5 spec
    VALID_TRANSITIONS = {
        "pending": ["active", "rejected", "expired"],
        "active": ["used_in_strategy", "observed_in_paper", "rejected", "expired"],
        "used_in_strategy": ["executed", "archived"],
        "observed_in_paper": ["used_in_strategy", "archived"],
        "rejected": ["archived"],
        "expired": ["archived"],
        "executed": ["archived"],
    }

    def __init__(self, session: Session):
        self._s = session
        self._repo = SignalRepository(session)

    def create_signal(self, data: dict) -> Signal:
        """Create signal + identity + payload + initial lifecycle event."""
        signal_id = uuid.uuid4()
        now = datetime.now(timezone.utc)

        # 1. Create Signal via repository (which also creates SignalIdentity)
        sig = self._repo.create_signal(
            signal_id=signal_id,
            source_type=data["source_type"],
            symbol=data["symbol"],
            market=data.get("market", "crypto"),
            direction=data["direction"],
            status="pending",
            valid_from=now,
            confidence=data.get("confidence"),
            score=data.get("score"),
            risk_level=data.get("risk_level", "medium"),
            timeframe=data.get("timeframe"),
            source_id=data.get("source_id"),
            source_name=data.get("source_name"),
            expires_at=data.get("expires_at"),
            permission={"can_live_trade": data.get("can_live_trade", False)},
        )

        # 2. Create SignalPayload if reasoning/structured_output/raw_output provided
        has_payload = any(
            data.get(k) for k in (
                "reasoning", "structured_output", "raw_output",
                "trigger_condition", "current_state",
            )
        )
        if has_payload:
            payload = SignalPayload(
                signal_id=signal_id,
                reasoning=data.get("reasoning"),
                structured_output=data.get("structured_output"),
                raw_output=(
                    {"text": data["raw_output"]}
                    if isinstance(data.get("raw_output"), str)
                    else data.get("raw_output")
                ),
                trigger_condition=data.get("trigger_condition"),
                current_state=data.get("current_state"),
            )
            self._repo.save_payload(payload)

        # 3. Create evidence items if provided
        evidence_items = data.get("evidence") or []
        for item in evidence_items:
            ev = SignalEvidence(
                signal_id=signal_id,
                evidence_type=item.get("evidence_type", "unknown"),
                evidence_ref=item.get("evidence_ref"),
                evidence_payload=item.get("evidence_payload") or item.get("content"),
                source_uri=item.get("source_uri"),
                quality_score=item.get("quality_score"),
            )
            self._repo.add_evidence(ev)

        # 4. Write lifecycle event: "created" -> "pending"
        self._repo.add_lifecycle_event(
            signal_id=signal_id,
            event_type="created",
            from_status=None,
            to_status="pending",
            reason="signal created",
            actor="system",
        )

        return sig

    def list_signals(
        self, *,
        source_type: str | None = None,
        symbol: str | None = None,
        direction: str | None = None,
        status: str | None = None,
        risk_level: str | None = None,
        days: int = 7,
        limit: int = 50,
        offset: int = 0,
    ) -> list[Signal]:
        """Lightweight list - no payload loading. Default 7 day window."""
        stmt = select(Signal)
        filters = []

        if source_type:
            filters.append(Signal.source_type == source_type)
        if symbol:
            filters.append(Signal.symbol == symbol)
        if direction:
            filters.append(Signal.direction == direction)
        if status:
            filters.append(Signal.status == status)
        if risk_level:
            filters.append(Signal.risk_level == risk_level)

        # Default time window
        cutoff = datetime.now(timezone.utc) - timedelta(days=days)
        filters.append(Signal.created_at >= cutoff)

        if filters:
            stmt = stmt.where(and_(*filters))

        stmt = stmt.order_by(Signal.created_at.desc()).offset(offset).limit(limit)
        return list(self._s.scalars(stmt).all())

    def get_signal_detail(self, signal_id: uuid.UUID) -> dict:
        """Full detail: signal + payload + evidence + lifecycle events."""
        sig = self._repo.get_by_id(signal_id)
        if sig is None:
            return {}

        payload = self._repo.get_payload(signal_id)
        evidence = self._repo.get_evidence(signal_id)

        # Query lifecycle events directly (not in repository)
        lifecycle_stmt = (
            select(SignalLifecycleEvent)
            .where(SignalLifecycleEvent.signal_id == signal_id)
            .order_by(SignalLifecycleEvent.created_at.asc())
        )
        lifecycle_events = list(self._s.scalars(lifecycle_stmt).all())

        return {
            "signal": sig,
            "payload": payload,
            "evidence": evidence,
            "lifecycle_events": lifecycle_events,
        }

    def transition_status(
        self, signal_id: uuid.UUID, target_status: str, reason: str | None = None,
    ) -> Signal:
        """Transition with validation + lifecycle event."""
        sig = self._repo.get_by_id(signal_id)
        if sig is None:
            raise ValueError(f"Signal {signal_id} not found")

        current = sig.status
        allowed = self.VALID_TRANSITIONS.get(current, [])
        if target_status not in allowed:
            raise ValueError(
                f"Invalid transition: {current} -> {target_status}. "
                f"Allowed: {allowed}"
            )

        sig = self._repo.transition_status(
            signal_id, target_status, reason=reason, actor="system",
        )
        return sig

    def archive_signal(self, signal_id: uuid.UUID) -> Signal:
        """Archive signal. Check for referenced orders - if exists, create reference snapshot first."""
        sig = self._repo.get_by_id(signal_id)
        if sig is None:
            raise ValueError(f"Signal {signal_id} not found")

        # Check for referenced orders (ExecutionOrder by symbol during signal lifetime)
        from app.domain.order import ExecutionOrder

        orders_stmt = (
            select(ExecutionOrder)
            .where(
                ExecutionOrder.symbol == sig.symbol,
                ExecutionOrder.opened_at >= sig.valid_from,
            )
            .limit(10)
        )
        referenced_orders = list(self._s.scalars(orders_stmt).all())

        if referenced_orders:
            # Create snapshot before archiving
            snapshot_data = {
                "signal_status": sig.status,
                "symbol": sig.symbol,
                "direction": sig.direction,
                "confidence": float(sig.confidence) if sig.confidence else None,
                "referenced_order_ids": [str(o.id) for o in referenced_orders],
            }
            snapshot = SignalSnapshot(
                signal_id=signal_id,
                snapshot_reason="pre_archive_with_orders",
                snapshot_payload=snapshot_data,
            )
            self._s.add(snapshot)
            self._s.flush()

        # Transition to archived
        current = sig.status
        allowed = self.VALID_TRANSITIONS.get(current, [])
        if "archived" not in allowed:
            raise ValueError(
                f"Cannot archive signal in status '{current}'. "
                f"Allowed transitions: {allowed}"
            )

        sig = self._repo.transition_status(
            signal_id, "archived", reason="signal archived", actor="system",
        )
        return sig

    def publish_to_strategy(self, signal_id: uuid.UUID) -> dict:
        """Create a StrategyDraft from this signal."""
        from app.models.research_v2 import StrategyDraft, SignalCandidate, ResearchReport

        sig = self._repo.get_by_id(signal_id)
        if sig is None:
            raise ValueError(f"Signal {signal_id} not found")

        payload = self._repo.get_payload(signal_id)

        # Create a placeholder ResearchReport for the signal-sourced draft
        report = ResearchReport(
            run_id=0,  # synthetic — signal center origin
            symbol=sig.symbol,
            market=sig.market,
            timeframe=sig.timeframe or "1d",
            rating="signal_center",
            direction=sig.direction,
            confidence=float(sig.confidence) if sig.confidence else 0.5,
            risk_level=sig.risk_level or "medium",
            agent_opinions={},
            summary=payload.reasoning if payload else "",
            evidence=[],
        )
        self._s.add(report)
        self._s.flush()

        # Create a SignalCandidate linked to the report
        candidate = SignalCandidate(
            report_id=report.id,
            symbol=sig.symbol,
            direction=sig.direction,
            confidence=float(sig.confidence) if sig.confidence else 0.5,
            risk_level=sig.risk_level or "medium",
            reasoning=payload.reasoning if payload else "",
            entry_logic=payload.reasoning if payload else "",
            exit_logic="",
            can_live_trade=sig.permission.get("can_live_trade", False),
        )
        self._s.add(candidate)
        self._s.flush()

        # Create StrategyDraft
        draft = StrategyDraft(
            candidate_id=candidate.id,
            report_id=report.id,
            name=f"Signal-{sig.symbol}-{sig.direction}-{sig.created_at.strftime('%Y%m%d')}",
            description=f"Auto-generated from Signal Center signal {signal_id}",
            rule_dsl={
                "source": "signal_center",
                "signal_id": str(signal_id),
                "symbol": sig.symbol,
                "direction": sig.direction,
                "trigger_condition": payload.trigger_condition if payload else None,
            },
            source_type="signal_center",
            auto_execute=False,
            requires_human_confirm=True,
        )
        self._s.add(draft)
        self._s.flush()

        # Transition signal to used_in_strategy
        self.transition_status(signal_id, "used_in_strategy", "published to strategy draft")

        return {
            "draft_id": draft.id,
            "signal_id": signal_id,
            "name": draft.name,
        }

    def observe_paper(self, signal_id: uuid.UUID) -> Signal:
        """Mark signal as observed_in_paper."""
        return self.transition_status(signal_id, "observed_in_paper", "added to paper observation")

    def conflict_check(self, symbol: str, direction: str) -> dict:
        """Find active signals with opposite direction for same symbol."""
        opposite = {"long": "short", "short": "long"}
        opp_direction = opposite.get(direction)

        if opp_direction is None:
            return {"has_conflict": False, "conflicting_signals": []}

        stmt = (
            select(Signal)
            .where(
                Signal.symbol == symbol,
                Signal.direction == opp_direction,
                Signal.status.in_(["pending", "active"]),
            )
            .order_by(Signal.created_at.desc())
            .limit(20)
        )
        conflicts = list(self._s.scalars(stmt).all())

        return {
            "has_conflict": len(conflicts) > 0,
            "conflicting_signals": conflicts,
        }

    def aggregate(
        self, symbols: list[str] | None = None, group_by: str = "symbol",
    ) -> dict:
        """Aggregate active signals by symbol/source/direction."""
        group_col = {
            "symbol": Signal.symbol,
            "source_type": Signal.source_type,
            "direction": Signal.direction,
        }.get(group_by, Signal.symbol)

        stmt = (
            select(group_col, func.count().label("count"))
            .where(Signal.status.in_(["pending", "active"]))
        )

        if symbols:
            stmt = stmt.where(Signal.symbol.in_(symbols))

        stmt = stmt.group_by(group_col).order_by(func.count().desc())
        rows = self._s.execute(stmt).all()

        groups = [{"key": row[0], "count": row[1]} for row in rows]
        total = sum(g["count"] for g in groups)

        return {
            "groups": groups,
            "total_count": total,
        }

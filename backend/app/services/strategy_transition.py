"""Strategy version status transition engine — pure logic, no DB dependency."""
from __future__ import annotations

from app.domain.enums import StrategyVersionStatus as S


class InvalidTransitionError(Exception):
    def __init__(self, from_status: S, to_status: S):
        self.from_status = from_status
        self.to_status = to_status
        super().__init__(f"Cannot transition from {from_status.value} to {to_status.value}")


ALLOWED_TRANSITIONS: dict[S, set[S]] = {
    S.DRAFT:         {S.VALIDATED, S.ARCHIVED, S.REJECTED},
    S.VALIDATED:     {S.BACKTESTED, S.DRAFT, S.ARCHIVED, S.REJECTED},
    S.BACKTESTED:    {S.PAPER_RUNNING, S.ARCHIVED, S.REJECTED},
    S.PAPER_RUNNING: {S.PAPER_PASSED, S.PAUSED, S.ARCHIVED, S.REJECTED},
    S.PAPER_PASSED:  {S.LIVE_PENDING, S.ARCHIVED, S.REJECTED},
    S.LIVE_PENDING:  {S.LIVE_SMALL, S.REJECTED},
    S.LIVE_SMALL:    {S.PAUSED, S.ARCHIVED},
    S.PAUSED:        {S.PAPER_RUNNING, S.ARCHIVED},
    S.ARCHIVED:      set(),
    S.REJECTED:      {S.DRAFT},
}

SYSTEM_ONLY_TRANSITIONS: set[tuple[S, S]] = {
    (S.VALIDATED, S.BACKTESTED),
    (S.PAPER_RUNNING, S.PAPER_PASSED),
}


def validate_transition(from_status: S, to_status: S) -> None:
    allowed = ALLOWED_TRANSITIONS.get(from_status, set())
    if to_status not in allowed:
        raise InvalidTransitionError(from_status, to_status)


def is_system_only(from_status: S, to_status: S) -> bool:
    return (from_status, to_status) in SYSTEM_ONLY_TRANSITIONS

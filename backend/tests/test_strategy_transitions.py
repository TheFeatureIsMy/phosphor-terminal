"""Tests for strategy version status transition engine."""
import pytest

from app.domain.enums import StrategyVersionStatus as S
from app.services.strategy_transition import (
    ALLOWED_TRANSITIONS,
    InvalidTransitionError,
    is_system_only,
    validate_transition,
)


class TestValidTransitions:
    @pytest.mark.parametrize("from_s,to_s", [
        (S.DRAFT, S.VALIDATED),
        (S.VALIDATED, S.BACKTESTED),
        (S.BACKTESTED, S.PAPER_RUNNING),
        (S.PAPER_RUNNING, S.PAPER_PASSED),
        (S.PAPER_PASSED, S.LIVE_PENDING),
        (S.LIVE_PENDING, S.LIVE_SMALL),
    ])
    def test_happy_path_forward(self, from_s, to_s):
        validate_transition(from_s, to_s)

    @pytest.mark.parametrize("from_s", [
        S.DRAFT, S.VALIDATED, S.BACKTESTED, S.PAPER_RUNNING, S.PAPER_PASSED,
    ])
    def test_any_to_archived(self, from_s):
        validate_transition(from_s, S.ARCHIVED)

    @pytest.mark.parametrize("from_s", [
        S.DRAFT, S.VALIDATED, S.BACKTESTED, S.PAPER_RUNNING, S.PAPER_PASSED, S.LIVE_PENDING,
    ])
    def test_any_to_rejected(self, from_s):
        validate_transition(from_s, S.REJECTED)

    def test_live_small_to_paused(self):
        validate_transition(S.LIVE_SMALL, S.PAUSED)

    def test_live_small_to_archived(self):
        validate_transition(S.LIVE_SMALL, S.ARCHIVED)

    def test_paused_resume(self):
        validate_transition(S.PAUSED, S.PAPER_RUNNING)

    def test_paused_to_archived(self):
        validate_transition(S.PAUSED, S.ARCHIVED)

    def test_rejected_rework(self):
        validate_transition(S.REJECTED, S.DRAFT)

    def test_validated_back_to_draft(self):
        validate_transition(S.VALIDATED, S.DRAFT)


class TestBlockedTransitions:
    def test_draft_cannot_skip_to_paper(self):
        with pytest.raises(InvalidTransitionError):
            validate_transition(S.DRAFT, S.PAPER_RUNNING)

    def test_archived_is_terminal(self):
        for target in S:
            if target == S.ARCHIVED:
                continue
            with pytest.raises(InvalidTransitionError):
                validate_transition(S.ARCHIVED, target)

    def test_draft_cannot_go_to_backtested(self):
        with pytest.raises(InvalidTransitionError):
            validate_transition(S.DRAFT, S.BACKTESTED)

    def test_paper_passed_cannot_skip_to_live_small(self):
        with pytest.raises(InvalidTransitionError):
            validate_transition(S.PAPER_PASSED, S.LIVE_SMALL)


class TestSystemOnly:
    def test_validated_to_backtested_is_system_only(self):
        assert is_system_only(S.VALIDATED, S.BACKTESTED) is True

    def test_paper_running_to_paper_passed_is_system_only(self):
        assert is_system_only(S.PAPER_RUNNING, S.PAPER_PASSED) is True

    def test_draft_to_validated_not_system_only(self):
        assert is_system_only(S.DRAFT, S.VALIDATED) is False

    def test_all_states_covered(self):
        for status in S:
            assert status in ALLOWED_TRANSITIONS

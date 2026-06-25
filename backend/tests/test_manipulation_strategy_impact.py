"""Tests for manipulation strategy-impact analyzer."""
import uuid

import pytest

from app.domain.strategy import StrategyV2, StrategyVersion
from app.services.manipulation.strategy_impact import compute_strategy_impact


def _make_strategy(session, name, symbols, rules, status="active"):
    strat = StrategyV2(
        id=uuid.uuid4(),
        name=name,
        strategy_type="manual",
        source_type="manual",
        status=status,
    )
    session.add(strat)
    session.flush()
    version = StrategyVersion(
        id=uuid.uuid4(),
        strategy_id=strat.id,
        version_no=1,
        status="active",
        dsl_version="2.5",
        rule_dsl={"version": "2.5", "symbols": symbols, "rules": rules},
        dsl_hash="hash-" + name,
        created_by="test",
    )
    session.add(version)
    session.commit()
    return strat


def _case(symbol="SOL/USDT", confidence=0.8, has_layers=True):
    layers = (
        {
            "A_price": {"available": True, "data_quality": 0.9, "score": 0.7, "features": []},
            "B_orderbook": {"available": True, "data_quality": 0.9, "score": 0.5, "features": []},
            "C_onchain": {"available": True, "data_quality": 0.9, "score": 0.6, "features": []},
            "D_social": {"available": True, "data_quality": 0.9, "score": 0.4, "features": []},
            "E_cross_market": {"available": True, "data_quality": 0.9, "score": 0.8, "features": []},
        }
        if has_layers
        else None
    )
    return {
        "id": str(uuid.uuid4()),
        "symbol": symbol,
        "confidence": confidence,
        "lifecycle_stage": "markup",
        "evidence_layers": layers,
    }


class TestStrategyImpact:
    def test_filter_enabled_blocks_when_confidence_exceeds_max(self, session):
        s = _make_strategy(session, "BlockingStrat", ["SOL/USDT"], [
            {"type": "manipulation_score_filter", "max_score": 0.5, "missing_data_policy": "reject"},
        ])
        result = compute_strategy_impact(_case(symbol="SOL/USDT", confidence=0.8), session)
        assert result["total_affected"] == 1
        assert result["total_protected"] == 1
        strat = result["affected_strategies"][0]
        assert strat["strategy_id"] == str(s.id)
        assert strat["manipulation_filter"]["enabled"] is True
        assert strat["manipulation_filter"]["would_block"] is True
        assert "confidence_exceeds_max_score" in strat["manipulation_filter"]["reason_codes"]

    def test_filter_disabled_does_not_block(self, session):
        _make_strategy(session, "OpenStrat", ["SOL/USDT"], [
            {"type": "indicator_threshold", "indicator": "rsi",
             "params": {"period": 14}, "operator": ">", "value": 70},
        ])
        result = compute_strategy_impact(_case(symbol="SOL/USDT", confidence=0.8), session)
        assert result["total_affected"] == 1
        assert result["total_protected"] == 0
        strat = result["affected_strategies"][0]
        assert strat["manipulation_filter"]["enabled"] is False
        assert strat["manipulation_filter"]["would_block"] is False
        assert "filter_disabled" in strat["manipulation_filter"]["reason_codes"]

    def test_symbol_mismatch_excludes_strategy(self, session):
        _make_strategy(session, "BTCOnly", ["BTC/USDT"], [
            {"type": "manipulation_score_filter", "max_score": 0.5, "missing_data_policy": "reject"},
        ])
        result = compute_strategy_impact(_case(symbol="SOL/USDT", confidence=0.8), session)
        assert result["total_affected"] == 0

    def test_inactive_strategy_excluded(self, session):
        _make_strategy(session, "PausedStrat", ["SOL/USDT"], [
            {"type": "manipulation_score_filter", "max_score": 0.5, "missing_data_policy": "reject"},
        ], status="paused")
        result = compute_strategy_impact(_case(symbol="SOL/USDT", confidence=0.8), session)
        assert result["total_affected"] == 0

    def test_missing_data_policy_reject_blocks_when_layers_missing(self, session):
        _make_strategy(session, "RejectMissing", ["SOL/USDT"], [
            {"type": "manipulation_score_filter", "max_score": 0.95, "missing_data_policy": "reject"},
        ])
        result = compute_strategy_impact(
            _case(symbol="SOL/USDT", confidence=0.4, has_layers=False), session
        )
        assert result["total_protected"] == 1
        strat = result["affected_strategies"][0]
        assert "missing_data_policy_reject" in strat["manipulation_filter"]["reason_codes"]

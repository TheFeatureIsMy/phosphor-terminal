import pytest
from datetime import datetime, timezone, timedelta
from app.services.ai_cache_evaluator import evaluate_ai_cache, AICacheEvaluation
from app.domain.dsl import DegradationPolicy

def _fresh_cache(risk=0.3):
    now = datetime.now(timezone.utc)
    return {
        "ai_risk_score": risk,
        "generated_at": now.isoformat(),
        "valid_until": (now + timedelta(minutes=15)).isoformat(),
        "trade_permission": "allow",
    }

def _expired_cache(age_s, risk=0.3):
    past = datetime.now(timezone.utc) - timedelta(seconds=age_s)
    return {
        "ai_risk_score": risk,
        "generated_at": past.isoformat(),
        "valid_until": past.isoformat(),
        "trade_permission": "allow",
    }

def test_fresh_cache_normal():
    result = evaluate_ai_cache(_fresh_cache())
    assert result.cache_state == "fresh"
    assert result.action == "normal"
    assert result.size_multiplier == 1.0

def test_missing_cache_reduces():
    result = evaluate_ai_cache(None)
    assert result.cache_state == "missing"
    assert result.action == "reduce_size"
    assert result.size_multiplier == 0.5

def test_soft_expired_reduces():
    result = evaluate_ai_cache(_expired_cache(700))
    assert result.cache_state == "soft_expired"
    assert result.action == "reduce_size"
    assert result.size_multiplier == 0.5

def test_hard_expired_blocks():
    result = evaluate_ai_cache(_expired_cache(1000))
    assert result.cache_state == "hard_expired"
    assert result.action == "block_new_entries"
    assert result.size_multiplier == 0.0

def test_policy_ignore_overrides():
    policy = DegradationPolicy(
        ai_cache_soft_expired="ignore",
        ai_cache_hard_expired="ignore",
    )
    result = evaluate_ai_cache(_expired_cache(1000), degradation_policy=policy)
    assert result.action == "ignore"
    assert result.size_multiplier == 1.0

def test_fresh_high_risk_reduces():
    result = evaluate_ai_cache(_fresh_cache(risk=0.8))
    assert result.cache_state == "fresh"
    assert result.action == "reduce_size"
    assert result.size_multiplier < 1.0

def test_hard_block_permission():
    cache = _fresh_cache()
    cache["trade_permission"] = "block_new_entries"
    result = evaluate_ai_cache(cache)
    assert result.action == "block_new_entries"
    assert result.size_multiplier == 0.0

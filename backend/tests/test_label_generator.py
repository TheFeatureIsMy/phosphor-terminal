import pytest
from app.services.label_generator import generate_labels

def test_good_structure_entry():
    snapshot = {
        "structure_context": {"sweep": {"state": "confirmed_sweep"}, "structure_score": 80},
        "ai_context": {"cache_state": "fresh"},
        "execution_plan": {}, "reason_codes": [],
    }
    labels = generate_labels("t1", profit_pct=5.0, snapshot=snapshot)
    values = [l.label_value for l in labels]
    assert "good_structure_entry" in values

def test_entered_before_reclaim():
    snapshot = {
        "structure_context": {"sweep": {"state": "sweep_candidate"}, "structure_score": 60},
        "ai_context": {"cache_state": "fresh"},
        "execution_plan": {}, "reason_codes": [],
    }
    labels = generate_labels("t2", profit_pct=-3.0, snapshot=snapshot)
    values = [l.label_value for l in labels]
    assert "entered_before_reclaim_confirmation" in values

def test_ai_cache_expired():
    snapshot = {
        "structure_context": {}, "ai_context": {"cache_state": "soft_expired"},
        "execution_plan": {}, "reason_codes": [],
    }
    labels = generate_labels("t3", profit_pct=-1.0, snapshot=snapshot)
    values = [l.label_value for l in labels]
    assert "ai_cache_expired_reduced_size" in values

def test_disconnect_label():
    snapshot = {
        "structure_context": {}, "ai_context": {"cache_state": "missing"},
        "execution_plan": {},
        "reason_codes": ["disconnect_protection_active"],
    }
    labels = generate_labels("t4", profit_pct=-2.0, snapshot=snapshot)
    values = [l.label_value for l in labels]
    assert "snapshot_disconnect_emergency_close" in values

def test_no_snapshot():
    labels = generate_labels("t5", profit_pct=-1.0, snapshot=None)
    assert isinstance(labels, list)

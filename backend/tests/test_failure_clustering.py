import pytest
from app.services.failure_clustering import cluster_failures, generate_optimization_suggestions

def test_single_cluster():
    trades = [
        {"trade_id": "t1", "profit_pct": -2.0},
        {"trade_id": "t2", "profit_pct": -1.5},
    ]
    labels = {
        "t1": ["entered_before_reclaim_confirmation"],
        "t2": ["entered_before_reclaim_confirmation"],
    }
    clusters = cluster_failures(trades, labels)
    assert len(clusters) == 1
    assert clusters[0].cluster_name == "entered_before_reclaim_confirmation"
    assert clusters[0].trade_count == 2

def test_multiple_clusters():
    trades = [
        {"trade_id": "t1", "profit_pct": -2.0},
        {"trade_id": "t2", "profit_pct": -1.0},
        {"trade_id": "t3", "profit_pct": -3.0},
    ]
    labels = {
        "t1": ["entered_before_reclaim_confirmation"],
        "t2": ["stop_too_close_to_liquidity_pool"],
        "t3": ["entered_before_reclaim_confirmation"],
    }
    clusters = cluster_failures(trades, labels)
    assert len(clusters) == 2

def test_no_losses():
    trades = [{"trade_id": "t1", "profit_pct": 5.0}]
    labels = {"t1": ["good_structure_entry"]}
    clusters = cluster_failures(trades, labels)
    assert len(clusters) == 0

def test_sorted_worst_first():
    trades = [
        {"trade_id": "t1", "profit_pct": -1.0},
        {"trade_id": "t2", "profit_pct": -5.0},
    ]
    labels = {
        "t1": ["label_a"],
        "t2": ["label_b"],
    }
    clusters = cluster_failures(trades, labels)
    assert clusters[0].total_loss < clusters[1].total_loss

def test_suggestions():
    trades = [{"trade_id": "t1", "profit_pct": -2.0}]
    labels = {"t1": ["entered_before_reclaim_confirmation"]}
    clusters = cluster_failures(trades, labels)
    suggestions = generate_optimization_suggestions(clusters)
    assert len(suggestions) == 1
    assert "reclaim" in suggestions[0].lower()

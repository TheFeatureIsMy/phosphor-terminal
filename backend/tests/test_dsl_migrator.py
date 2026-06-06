import pytest
from app.services.dsl_migrator import migrate_v25_to_v30, is_v25, is_v30
from app.domain.dsl import RulePackageV3

def _v25_dsl():
    return {
        "schema_version": "2.5",
        "timeframe": "5m",
        "symbols": ["BTC/USDT"],
        "entry": {"logic": "AND", "rules": [
            {"type": "indicator_threshold", "indicator": "rsi",
             "params": {"period": 14}, "operator": "<", "value": 30}
        ]},
        "exit": {"logic": "AND", "rules": [
            {"type": "indicator_threshold", "indicator": "rsi",
             "params": {"period": 14}, "operator": ">", "value": 70}
        ]},
        "filters": [],
        "position_sizing": {"type": "fixed_pct", "position_pct": 0.1},
        "risk": {"stoploss": -0.05, "max_open_trades": 3},
    }

def test_is_v25():
    assert is_v25(_v25_dsl()) is True
    assert is_v25({"schema_version": "3.0"}) is False

def test_is_v30():
    assert is_v30({"schema_version": "3.0"}) is True
    assert is_v30(_v25_dsl()) is False

def test_migrate_produces_valid_v30():
    v30 = migrate_v25_to_v30(_v25_dsl())
    assert v30["schema_version"] == "3.0"
    pkg = RulePackageV3.model_validate(v30)
    assert pkg.strategy.symbol == "BTC/USDT"
    assert pkg.strategy.timeframe == "5m"

def test_migrate_preserves_entry_rules():
    v30 = migrate_v25_to_v30(_v25_dsl())
    assert len(v30["entry_logic"]["rules"]) == 1
    assert v30["entry_logic"]["rules"][0]["indicator"] == "rsi"

def test_migrate_maps_stoploss():
    v30 = migrate_v25_to_v30(_v25_dsl())
    assert v30["stop_policy"]["fallback_stop_pct"] == 0.05

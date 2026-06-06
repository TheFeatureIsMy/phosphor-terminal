"""Tests for DSL diff computation."""
from app.services.strategy_diff import compute_dsl_diff


class TestDSLDiff:
    def test_identical_dsls(self):
        dsl = {"schema_version": "2.5", "timeframe": "1h"}
        diff = compute_dsl_diff(dsl, dsl)
        assert diff["added"] == {}
        assert diff["removed"] == {}
        assert diff["changed"] == {}
        assert len(diff["unchanged_keys"]) == 2

    def test_added_removed_changed(self):
        old = {"a": 1, "b": 2, "c": 3}
        new = {"b": 99, "c": 3, "d": 4}
        diff = compute_dsl_diff(old, new)
        assert diff["removed"] == {"a": 1}
        assert diff["added"] == {"d": 4}
        assert diff["changed"] == {"b": {"old": 2, "new": 99}}
        assert "c" in diff["unchanged_keys"]

    def test_nested_changes(self):
        old = {"entry": {"logic": "AND", "rules": [{"indicator": "rsi", "value": 30}]}}
        new = {"entry": {"logic": "OR",  "rules": [{"indicator": "rsi", "value": 25}]}}
        diff = compute_dsl_diff(old, new)
        assert "entry.logic" in diff["changed"]
        assert diff["changed"]["entry.logic"] == {"old": "AND", "new": "OR"}
        assert "entry.rules.0.value" in diff["changed"]
        assert "entry.rules.0.indicator" in diff["unchanged_keys"]

    def test_list_length_change(self):
        old = {"symbols": ["BTC/USDT"]}
        new = {"symbols": ["BTC/USDT", "ETH/USDT"]}
        diff = compute_dsl_diff(old, new)
        assert "symbols.1" in diff["added"]
        assert diff["added"]["symbols.1"] == "ETH/USDT"

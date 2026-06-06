"""Tests for manipulation scoring engine."""
from app.services.manipulation.scoring import compute_manipulation_scores, ManipulationResult


class TestScoring:
    def test_low_features_low_score(self):
        features = {k: 10.0 for k in [
            "wick_ratio_up", "wick_ratio_down", "volume_zscore",
            "price_range_spike", "pump_then_dump", "dump_then_recover",
            "pinbar_score", "volume_price_divergence",
        ]}
        result = compute_manipulation_scores(features, symbol="BTC/USDT")
        assert result.manipulation_score < 40
        assert result.risk_level == "low"

    def test_high_features_extreme_score(self):
        features = {k: 90.0 for k in [
            "wick_ratio_up", "wick_ratio_down", "volume_zscore",
            "price_range_spike", "pump_then_dump", "dump_then_recover",
            "pinbar_score", "volume_price_divergence",
        ]}
        result = compute_manipulation_scores(features, symbol="SHIB/USDT")
        assert result.manipulation_score >= 80
        assert result.risk_level == "extreme"

    def test_stop_hunt_elevated(self):
        features = {
            "wick_ratio_up": 90, "wick_ratio_down": 85,
            "volume_zscore": 80, "pinbar_score": 70,
            "price_range_spike": 10, "pump_then_dump": 5,
            "dump_then_recover": 5, "volume_price_divergence": 5,
        }
        result = compute_manipulation_scores(features, symbol="XXX/USDT")
        assert result.stop_hunt_score > 70
        assert "stop_hunt" in result.reasoning

    def test_pump_dump_elevated(self):
        features = {
            "wick_ratio_up": 10, "wick_ratio_down": 10,
            "volume_zscore": 80, "pinbar_score": 10,
            "price_range_spike": 10, "pump_then_dump": 90,
            "dump_then_recover": 10, "volume_price_divergence": 85,
        }
        result = compute_manipulation_scores(features, symbol="PUMP/USDT")
        assert result.pump_dump_score > 70
        assert "pump_dump" in result.reasoning

    def test_data_quality_layer_a_only(self):
        features = {k: 0.0 for k in [
            "wick_ratio_up", "wick_ratio_down", "volume_zscore",
            "price_range_spike", "pump_then_dump", "dump_then_recover",
            "pinbar_score", "volume_price_divergence",
        ]}
        result = compute_manipulation_scores(features)
        assert result.data_quality["layer_a"] is True
        assert result.data_quality["layer_b"] is False
        assert result.data_quality["layer_c"] is False
        assert result.holder_concentration_score == 0.0
        assert result.funding_squeeze_score == 0.0

    def test_result_to_scores_dict(self):
        features = {k: 50.0 for k in [
            "wick_ratio_up", "wick_ratio_down", "volume_zscore",
            "price_range_spike", "pump_then_dump", "dump_then_recover",
            "pinbar_score", "volume_price_divergence",
        ]}
        result = compute_manipulation_scores(features, symbol="ETH/USDT")
        d = result.to_scores_dict()
        assert "manipulation_score" in d
        assert "stop_hunt_score" in d
        assert len(d) == 6

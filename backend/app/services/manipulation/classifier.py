"""Manipulation pattern classifier — rules-based v1 for M1-M8 types."""
from __future__ import annotations

from dataclasses import dataclass, field


@dataclass
class PatternMatch:
    manipulation_type: str    # M1-M8
    type_label: str           # human-readable label
    confidence: float         # 0.0 - 1.0
    evidence: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "manipulation_type": self.manipulation_type,
            "type_label": self.type_label,
            "confidence": self.confidence,
            "evidence": self.evidence,
        }


# Manipulation type definitions
MANIPULATION_TYPES = {
    "M1": "Coordinated Fund Control (资金协同控盘)",
    "M2": "Market Maker Irregular Control (老庄无规律控盘)",
    "M3": "KOL Social Pump (KOL社交拉盘)",
    "M4": "Whale Wallet Control (少数钱包控盘)",
    "M5": "Cross-Market Manipulation (跨市场操纵)",
    "M6": "Wash Trading (自成交刷量)",
    "M7": "Spoofing (幽灵挂单)",
    "M8": "Liquidity Hunt (流动性猎杀)",
}


class ManipulationPatternClassifier:
    """Rules-based classifier for manipulation types M1-M8.
    Uses multi-feature thresholds. Returns all matching patterns sorted by confidence."""

    def classify(self, features: dict[str, float]) -> list[PatternMatch]:
        matches = []

        # M5: Cross-Market Manipulation (enhanced with Layer E)
        # DEX pump spot -> squeeze perp -> funding rate harvest -> crash
        pump_dump = features.get("pump_then_dump", 0)
        vol_zscore = features.get("volume_zscore", 0)
        price_spike = features.get("price_range_spike", 0)
        squeeze = features.get("cross_market_squeeze_score", 0)
        funding_z = features.get("funding_rate_zscore", 0)
        if squeeze > 50 or (pump_dump > 50 and vol_zscore > 40 and price_spike > 40):
            # If cross-market data available, use it for higher confidence
            if squeeze > 50:
                conf = min(squeeze / 100, 1.0)
                evidence = {
                    "cross_market_squeeze_score": squeeze,
                    "funding_rate_zscore": funding_z,
                    "basis_zscore": features.get("basis_zscore", 0),
                    "oi_surge_score": features.get("oi_surge_score", 0),
                }
            else:
                conf = min((pump_dump + vol_zscore + price_spike) / 300, 1.0)
                evidence = {"pump_dump": pump_dump, "volume_zscore": vol_zscore,
                            "price_range_spike": price_spike}
            matches.append(PatternMatch(
                manipulation_type="M5",
                type_label=MANIPULATION_TYPES["M5"],
                confidence=conf,
                evidence=evidence,
            ))

        # M7: Spoofing (Layer B required)
        spoof = features.get("spoof_score", 0)
        depth_imb = features.get("depth_imbalance_score", 0)
        if spoof > 50:
            conf = min(spoof / 100, 1.0)
            matches.append(PatternMatch(
                manipulation_type="M7",
                type_label=MANIPULATION_TYPES["M7"],
                confidence=conf,
                evidence={"spoof_score": spoof, "depth_imbalance": depth_imb,
                          "spread_volatility": features.get("spread_volatility", 0)},
            ))

        # M8: Liquidity Hunt (enhanced with Layer B)
        # Precise wick through key levels then reversal
        wick_up = features.get("wick_ratio_up", 0)
        wick_down = features.get("wick_ratio_down", 0)
        pinbar = features.get("pinbar_score", 0)
        max_wick = max(wick_up, wick_down)
        liq_void = features.get("liquidity_void_score", 0)
        if max_wick > 50 and pinbar > 30:
            conf = min((max_wick + pinbar) / 200, 1.0)
            if liq_void > 40:
                conf = min(conf + 0.15, 1.0)  # boost from orderbook evidence
            matches.append(PatternMatch(
                manipulation_type="M8",
                type_label=MANIPULATION_TYPES["M8"],
                confidence=conf,
                evidence={"wick_ratio": max_wick, "pinbar_score": pinbar,
                          "liquidity_void_score": liq_void, "volume_zscore": vol_zscore},
            ))

        # M2: Market Maker Irregular Control
        # Long consolidation then violent breakout, repeated pattern
        consolidation = features.get("consolidation_score", 0)
        breakout = features.get("breakout_velocity", 0)
        if consolidation > 60 and breakout > 50:
            conf = min((consolidation + breakout) / 200, 1.0)
            matches.append(PatternMatch(
                manipulation_type="M2",
                type_label=MANIPULATION_TYPES["M2"],
                confidence=conf,
                evidence={"consolidation_score": consolidation,
                          "breakout_velocity": breakout},
            ))

        # M1: Coordinated Fund Control
        # Sharp pump-dump with extreme volume (multiple actors pushing together)
        if pump_dump > 60 and vol_zscore > 60:
            conf = min((pump_dump + vol_zscore) / 200, 1.0)
            matches.append(PatternMatch(
                manipulation_type="M1",
                type_label=MANIPULATION_TYPES["M1"],
                confidence=conf,
                evidence={"pump_then_dump": pump_dump, "volume_zscore": vol_zscore},
            ))

        # M6: Wash Trading
        # High volume but minimal price movement (volume-price divergence)
        vpd = features.get("volume_price_divergence", 0)
        if vpd > 60 and vol_zscore > 40:
            conf = min((vpd + vol_zscore) / 200, 1.0)
            matches.append(PatternMatch(
                manipulation_type="M6",
                type_label=MANIPULATION_TYPES["M6"],
                confidence=conf,
                evidence={"volume_price_divergence": vpd, "volume_zscore": vol_zscore},
            ))

        # M3, M4 require Layer C/D data (not yet available from OHLCV)
        # They return empty for now — will be added when those data layers are implemented

        # Sort by confidence descending
        matches.sort(key=lambda m: m.confidence, reverse=True)
        return matches

    def get_primary_type(self, features: dict[str, float]) -> PatternMatch | None:
        """Return the highest-confidence match, or None."""
        matches = self.classify(features)
        return matches[0] if matches else None

from __future__ import annotations

from .models import SwingPoint, StructureBreak, StructureDirection


def detect_bos_choch(
    swing_highs: list[SwingPoint],
    swing_lows: list[SwingPoint],
    closes: list[float],
) -> list[StructureBreak]:
    breaks = []
    if len(swing_highs) < 2 or len(swing_lows) < 2:
        return breaks

    all_swings = sorted(
        [(s, "high") for s in swing_highs] + [(s, "low") for s in swing_lows],
        key=lambda x: x[0].index,
    )

    prev_direction = None
    prev_high = None
    prev_low = None

    for swing, swing_type in all_swings:
        if swing_type == "high":
            if prev_high is not None:
                if swing.price > prev_high.price:
                    if prev_direction == StructureDirection.BEARISH or prev_direction is None:
                        breaks.append(StructureBreak(
                            break_type="choch",
                            direction=StructureDirection.BULLISH,
                            price_level=prev_high.price,
                            broken_swing=prev_high,
                            candle_index=swing.index,
                            confirmed=True,
                        ))
                    else:
                        breaks.append(StructureBreak(
                            break_type="bos",
                            direction=StructureDirection.BULLISH,
                            price_level=prev_high.price,
                            broken_swing=prev_high,
                            candle_index=swing.index,
                            confirmed=True,
                        ))
                    prev_direction = StructureDirection.BULLISH
            prev_high = swing

        else:  # low
            if prev_low is not None:
                if swing.price < prev_low.price:
                    if prev_direction == StructureDirection.BULLISH or prev_direction is None:
                        breaks.append(StructureBreak(
                            break_type="choch",
                            direction=StructureDirection.BEARISH,
                            price_level=prev_low.price,
                            broken_swing=prev_low,
                            candle_index=swing.index,
                            confirmed=True,
                        ))
                    else:
                        breaks.append(StructureBreak(
                            break_type="bos",
                            direction=StructureDirection.BEARISH,
                            price_level=prev_low.price,
                            broken_swing=prev_low,
                            candle_index=swing.index,
                            confirmed=True,
                        ))
                    prev_direction = StructureDirection.BEARISH
            prev_low = swing

    return breaks

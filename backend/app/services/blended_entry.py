from __future__ import annotations


def calculate_blended_entry(
    old_size: float, old_entry: float,
    add_size: float, add_entry: float,
) -> float:
    total = old_size + add_size
    if total <= 0:
        return old_entry
    return (old_size * old_entry + add_size * add_entry) / total


def calculate_total_risk(
    direction: str, blended_entry: float,
    stop_price: float, total_size: float,
) -> float:
    if direction == "long":
        return (blended_entry - stop_price) * total_size
    return (stop_price - blended_entry) * total_size

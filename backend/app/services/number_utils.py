"""
Number utility functions
"""
from typing import Union


def clamp(value: float, min_val: float, max_val: float) -> float:
    """Clamp value between min and max"""
    return min(max(value, min_val), max_val)


def round_to(value: float, decimals: int = 2) -> float:
    """Round to specified decimals"""
    return round(value, decimals)


def format_currency(value: float, currency: str = 'USDT') -> str:
    """Format as currency"""
    sign = '+' if value >= 0 else ''
    return f"{sign}{value:,.2f} {currency}"


def format_percent(value: float, decimals: int = 2) -> str:
    """Format as percentage"""
    sign = '+' if value >= 0 else ''
    return f"{sign}{value:.{decimals}f}%"


def format_compact(value: float) -> str:
    """Format large numbers compactly"""
    if abs(value) >= 1e9:
        return f"{value / 1e9:.1f}B"
    if abs(value) >= 1e6:
        return f"{value / 1e6:.1f}M"
    if abs(value) >= 1e3:
        return f"{value / 1e3:.1f}K"
    return str(value)


def percentage(value: float, total: float) -> float:
    """Calculate percentage"""
    if total == 0:
        return 0.0
    return (value / total) * 100


def change_percent(old_value: float, new_value: float) -> float:
    """Calculate change percentage"""
    if old_value == 0:
        return 0.0
    return ((new_value - old_value) / old_value) * 100


def is_positive(value: float) -> bool:
    """Check if value is positive"""
    return value > 0


def is_negative(value: float) -> bool:
    """Check if value is negative"""
    return value < 0


def absolute(value: float) -> float:
    """Get absolute value"""
    return abs(value)

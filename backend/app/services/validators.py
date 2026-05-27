"""
Service-level validators
"""
from typing import Any


def validate_strategy_params(params: dict[str, Any]) -> tuple[bool, str]:
    """Validate strategy parameters"""
    if not isinstance(params, dict):
        return False, "Parameters must be a dictionary"

    # Check for required fields based on strategy type
    strategy_type = params.get('type')

    if strategy_type == 'ma_cross':
        if 'fast_period' not in params:
            return False, "MA交叉策略需要fast_period参数"
        if 'slow_period' not in params:
            return False, "MA交叉策略需要slow_period参数"
        if params.get('fast_period', 0) >= params.get('slow_period', 0):
            return False, "fast_period必须小于slow_period"

    elif strategy_type == 'breakout':
        if 'lookback_period' not in params:
            return False, "突破策略需要lookback_period参数"
        if 'breakout_threshold' not in params:
            return False, "突破策略需要breakout_threshold参数"

    elif strategy_type == 'grid':
        if 'grid_size' not in params:
            return False, "网格策略需要grid_size参数"
        if 'grid_spacing' not in params:
            return False, "网格策略需要grid_spacing参数"

    return True, ""


def validate_order_params(params: dict[str, Any]) -> tuple[bool, str]:
    """Validate order parameters"""
    if not isinstance(params, dict):
        return False, "Parameters must be a dictionary"

    if 'symbol' not in params:
        return False, "订单需要symbol参数"

    if 'side' not in params:
        return False, "订单需要side参数"

    if params.get('side') not in ['BUY', 'SELL']:
        return False, "side必须是BUY或SELL"

    if 'quantity' not in params:
        return False, "订单需要quantity参数"

    if params.get('quantity', 0) <= 0:
        return False, "quantity必须大于0"

    return True, ""


def validate_backtest_params(params: dict[str, Any]) -> tuple[bool, str]:
    """Validate backtest parameters"""
    if not isinstance(params, dict):
        return False, "Parameters must be a dictionary"

    if 'strategy_id' not in params:
        return False, "回测需要strategy_id参数"

    if 'start_date' not in params:
        return False, "回测需要start_date参数"

    if 'end_date' not in params:
        return False, "回测需要end_date参数"

    if 'initial_capital' not in params:
        return False, "回测需要initial_capital参数"

    if params.get('initial_capital', 0) <= 0:
        return False, "initial_capital必须大于0"

    return True, ""

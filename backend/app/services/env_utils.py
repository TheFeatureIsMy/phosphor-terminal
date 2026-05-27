"""
Environment utility functions
"""
import os
from typing import Optional


def get_env(key: str, default: Optional[str] = None) -> Optional[str]:
    """Get environment variable"""
    return os.environ.get(key, default)


def get_env_int(key: str, default: int = 0) -> int:
    """Get environment variable as integer"""
    value = os.environ.get(key)
    if value is None:
        return default
    try:
        return int(value)
    except ValueError:
        return default


def get_env_float(key: str, default: float = 0.0) -> float:
    """Get environment variable as float"""
    value = os.environ.get(key)
    if value is None:
        return default
    try:
        return float(value)
    except ValueError:
        return default


def get_env_bool(key: str, default: bool = False) -> bool:
    """Get environment variable as boolean"""
    value = os.environ.get(key)
    if value is None:
        return default
    return value.lower() in ('true', '1', 'yes')


def is_development() -> bool:
    """Check if running in development mode"""
    return get_env('ENVIRONMENT', 'development').lower() == 'development'


def is_production() -> bool:
    """Check if running in production mode"""
    return get_env('ENVIRONMENT', 'development').lower() == 'production'


def is_testing() -> bool:
    """Check if running in testing mode"""
    return get_env('ENVIRONMENT', 'development').lower() == 'testing'

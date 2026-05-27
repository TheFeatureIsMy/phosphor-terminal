"""
Object utility functions
"""
from typing import Any, TypeVar, Dict, Optional, Callable
from copy import deepcopy

T = TypeVar('T')


def pick(obj: Dict[str, Any], keys: list[str]) -> Dict[str, Any]:
    """Pick specified keys from dictionary"""
    return {k: obj[k] for k in keys if k in obj}


def omit(obj: Dict[str, Any], keys: list[str]) -> Dict[str, Any]:
    """Omit specified keys from dictionary"""
    return {k: v for k, v in obj.items() if k not in keys}


def is_empty(obj: Any) -> bool:
    """Check if object is empty"""
    if obj is None:
        return True
    if isinstance(obj, (str, list, tuple, dict)):
        return len(obj) == 0
    return False


def deep_clone(obj: T) -> T:
    """Deep clone an object"""
    return deepcopy(obj)


def merge(*dicts: Dict[str, Any]) -> Dict[str, Any]:
    """Merge multiple dictionaries"""
    result = {}
    for d in dicts:
        result.update(d)
    return result


def map_values(obj: Dict[str, Any], fn: Callable[[Any, str], Any]) -> Dict[str, Any]:
    """Map values in dictionary"""
    return {k: fn(v, k) for k, v in obj.items()}


def pick_by(obj: Dict[str, Any], predicate: Callable[[Any, str], bool]) -> Dict[str, Any]:
    """Pick values from dictionary by predicate"""
    return {k: v for k, v in obj.items() if predicate(v, k)}


def flatten_dict(d: Dict[str, Any], parent_key: str = '', sep: str = '.') -> Dict[str, Any]:
    """Flatten nested dictionary"""
    items: list[tuple[str, Any]] = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

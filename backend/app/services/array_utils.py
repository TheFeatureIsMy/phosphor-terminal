"""
Array/List utility functions
"""
from typing import TypeVar, List, Optional, Callable, Any
from collections import defaultdict

T = TypeVar('T')


def group_by(items: List[T], key_fn: Callable[[T], Any]) -> dict[Any, List[T]]:
    """Group items by key function"""
    groups = defaultdict(list)
    for item in items:
        groups[key_fn(item)].append(item)
    return dict(groups)


def unique(items: List[T]) -> List[T]:
    """Remove duplicates while preserving order"""
    seen = set()
    result = []
    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result


def unique_by(items: List[T], key_fn: Callable[[T], Any]) -> List[T]:
    """Remove duplicates by key function"""
    seen = set()
    result = []
    for item in items:
        key = key_fn(item)
        if key not in seen:
            seen.add(key)
            result.append(item)
    return result


def sort_by(items: List[T], key_fn: Callable[[T], Any], reverse: bool = False) -> List[T]:
    """Sort items by key function"""
    return sorted(items, key=key_fn, reverse=reverse)


def chunk(items: List[T], size: int) -> List[List[T]]:
    """Split list into chunks"""
    return [items[i:i + size] for i in range(0, len(items), size)]


def flatten(lists: List[List[T]]) -> List[T]:
    """Flatten list of lists"""
    return [item for sublist in lists for item in sublist]


def compact(items: List[Optional[T]]) -> List[T]:
    """Remove None values"""
    return [item for item in items if item is not None]


def sum_by(items: List[T], key_fn: Callable[[T], float]) -> float:
    """Sum values by key function"""
    return sum(key_fn(item) for item in items)


def average_by(items: List[T], key_fn: Callable[[T], float]) -> float:
    """Average values by key function"""
    if not items:
        return 0.0
    return sum_by(items, key_fn) / len(items)

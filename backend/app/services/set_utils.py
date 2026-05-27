"""
Set utilities
"""
from typing import TypeVar, Set, List

T = TypeVar('T')


def union(*sets: Set[T]) -> Set[T]:
    """Union of multiple sets"""
    result: Set[T] = set()
    for s in sets:
        result.update(s)
    return result


def intersection(*sets: Set[T]) -> Set[T]:
    """Intersection of multiple sets"""
    if not sets:
        return set()
    if len(sets) == 1:
        return sets[0].copy()

    result = sets[0].copy()
    for s in sets[1:]:
        result.intersection_update(s)
    return result


def difference(set_a: Set[T], set_b: Set[T]) -> Set[T]:
    """Difference of two sets"""
    return set_a - set_b


def symmetric_difference(set_a: Set[T], set_b: Set[T]) -> Set[T]:
    """Symmetric difference of two sets"""
    return set_a.symmetric_difference(set_b)


def is_subset(set_a: Set[T], set_b: Set[T]) -> bool:
    """Check if set_a is subset of set_b"""
    return set_a.issubset(set_b)


def is_superset(set_a: Set[T], set_b: Set[T]) -> bool:
    """Check if set_a is superset of set_b"""
    return set_a.issuperset(set_b)


def to_list(s: Set[T]) -> List[T]:
    """Convert set to list"""
    return list(s)


def from_list(items: List[T]) -> Set[T]:
    """Convert list to set"""
    return set(items)

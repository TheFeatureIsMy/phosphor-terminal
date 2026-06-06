"""DSL diff computation — compare two StrategyRuleDSL dicts."""
from __future__ import annotations

from typing import Any


def _flatten(obj: Any, prefix: str = "") -> dict[str, Any]:
    out: dict[str, Any] = {}
    if isinstance(obj, dict):
        for k, v in obj.items():
            key = f"{prefix}.{k}" if prefix else k
            out.update(_flatten(v, key))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            key = f"{prefix}.{i}"
            out.update(_flatten(v, key))
    else:
        out[prefix] = obj
    return out


def compute_dsl_diff(old_dsl: dict, new_dsl: dict) -> dict:
    old_flat = _flatten(old_dsl)
    new_flat = _flatten(new_dsl)
    all_keys = set(old_flat) | set(new_flat)

    added: dict[str, Any] = {}
    removed: dict[str, Any] = {}
    changed: dict[str, dict[str, Any]] = {}
    unchanged_keys: list[str] = []

    for k in sorted(all_keys):
        in_old = k in old_flat
        in_new = k in new_flat
        if in_old and not in_new:
            removed[k] = old_flat[k]
        elif in_new and not in_old:
            added[k] = new_flat[k]
        elif old_flat[k] != new_flat[k]:
            changed[k] = {"old": old_flat[k], "new": new_flat[k]}
        else:
            unchanged_keys.append(k)

    return {
        "added": added,
        "removed": removed,
        "changed": changed,
        "unchanged_keys": unchanged_keys,
    }

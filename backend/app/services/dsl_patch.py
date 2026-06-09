"""DSL Patch Service — generates and applies JSON Patch operations to strategy DSL.

Maps failure cluster patterns to concrete DSL modifications (block rules,
delay rules, size rules, exit rules, MTF rules, regime rules, liquidity
rules, AI brake rules).
"""
from __future__ import annotations

import copy
import logging
from dataclasses import dataclass, field
from typing import Any

logger = logging.getLogger(__name__)


@dataclass
class PatchValidationResult:
    compatible: bool = True
    warnings: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)


# ---------------------------------------------------------------------------
# Patch templates keyed by cluster label (mirrors CLUSTER_SUGGESTIONS in
# failure_clustering.py).  Each template is a list of JSON-Patch-like
# operations: {"op": "add"|"replace", "path": <json-pointer>, "value": ...}
# ---------------------------------------------------------------------------

PATCH_TEMPLATES: dict[str, list[dict[str, Any]]] = {
    # ── Reclaim confirmation + volume block ─────────────────────────
    "entered_before_reclaim_confirmation": [
        {
            "op": "add",
            "path": "/filters/-",
            "value": {
                "type": "custom_condition",
                "indicator": "structure_state",
                "operator": "eq",
                "value": "confirmed_sweep",
                "params": {},
                "description": "Block entry until reclaim confirmation",
                "patch_category": "block_rule",
            },
        },
        {
            "op": "add",
            "path": "/filters/-",
            "value": {
                "type": "volume_filter",
                "indicator": "volume",
                "operator": "gt",
                "value": "volume_ma_20",
                "params": {"period": 20},
                "description": "Require above-average volume on reclaim",
                "patch_category": "block_rule",
            },
        },
    ],

    # ── ATR buffer increase ─────────────────────────────────────────
    "stop_too_close_to_liquidity_pool": [
        {
            "op": "replace",
            "path": "/risk/atr_buffer_coef",
            "value": 0.5,
            "description": "Increase ATR buffer from 0.3 to 0.5 to avoid liquidity pool stops",
            "patch_category": "liquidity_rule",
        },
        {
            "op": "replace",
            "path": "/risk/stoploss_type",
            "value": "atr_based",
            "description": "Switch to ATR-based stoploss",
            "patch_category": "exit_rule",
        },
    ],

    # ── News shock — regime filter ──────────────────────────────────
    "failed_due_to_news_shock": [
        {
            "op": "add",
            "path": "/filters/-",
            "value": {
                "type": "custom_condition",
                "indicator": "news_event_active",
                "operator": "eq",
                "value": False,
                "params": {},
                "description": "Block entry during active news events",
                "patch_category": "regime_rule",
            },
        },
    ],

    # ── Panic regime filter ─────────────────────────────────────────
    "failed_due_to_panic": [
        {
            "op": "add",
            "path": "/filters/-",
            "value": {
                "type": "custom_condition",
                "indicator": "market_regime",
                "operator": "not_in",
                "value": ["panic"],
                "params": {},
                "description": "Block entry during panic regime",
                "patch_category": "regime_rule",
            },
        },
    ],

    # ── High volatility — position size reduction ───────────────────
    "failed_due_to_high_volatility": [
        {
            "op": "add",
            "path": "/position_sizing/volatility_scaling",
            "value": {
                "enabled": True,
                "high_vol_threshold": 2.0,
                "reduction_factor": 0.5,
                "indicator": "atr_14_norm",
            },
            "description": "Reduce position size by 50% during high volatility",
            "patch_category": "size_rule",
        },
    ],

    # ── AI cache expired — increase TTL ────────────────────────────
    "ai_cache_expired_reduced_size": [
        {
            "op": "replace",
            "path": "/runtime_mode/ai_cache_ttl_sec",
            "value": 3600,
            "description": "Increase AI cache TTL from default to 3600s",
            "patch_category": "ai_brake_rule",
        },
    ],

    # ── AI cache missing — require slow track ──────────────────────
    "ai_cache_missing": [
        {
            "op": "add",
            "path": "/runtime_mode/slow_track_ai_cache_required",
            "value": True,
            "description": "Require AI Slow Track cache before entry",
            "patch_category": "ai_brake_rule",
        },
    ],

    # ── Snapshot disconnect — increase tolerance ───────────────────
    "snapshot_disconnect_emergency_close": [
        {
            "op": "replace",
            "path": "/runtime_mode/max_snapshot_miss_ticks",
            "value": 10,
            "description": "Increase snapshot miss tolerance from default to 10 ticks",
            "patch_category": "block_rule",
        },
    ],

    # ── Stop too close (alias without liquidity pool suffix) ───────
    "stop_too_close": [
        {
            "op": "replace",
            "path": "/risk/atr_buffer_coef",
            "value": 0.5,
            "description": "Widen stop-loss ATR buffer coefficient",
            "patch_category": "exit_rule",
        },
    ],

    # ── Counter-trend entry ────────────────────────────────────────
    "counter_trend_entry": [
        {
            "op": "add",
            "path": "/filters/-",
            "value": {
                "type": "trend_alignment",
                "indicator": "ema_cross",
                "operator": "eq",
                "value": "aligned",
                "params": {"fast_period": 9, "slow_period": 21},
                "description": "Require EMA trend alignment before entry",
                "patch_category": "mtf_rule",
            },
        },
    ],

    # ── FVG already filled ─────────────────────────────────────────
    "fvg_already_filled": [
        {
            "op": "add",
            "path": "/filters/-",
            "value": {
                "type": "custom_condition",
                "indicator": "fvg_fill_pct",
                "operator": "lt",
                "value": 0.5,
                "params": {},
                "description": "Block entry when FVG is more than 50% filled",
                "patch_category": "liquidity_rule",
            },
        },
    ],

    # ── Overleveraged ──────────────────────────────────────────────
    "overleveraged": [
        {
            "op": "replace",
            "path": "/position_sizing/position_pct",
            "value": 0.02,
            "description": "Reduce max position size to 2%",
            "patch_category": "size_rule",
        },
        {
            "op": "replace",
            "path": "/risk/max_open_trades",
            "value": 2,
            "description": "Reduce max concurrent trades to 2",
            "patch_category": "size_rule",
        },
    ],
}


class DSLPatchService:
    """Generates, applies, and validates JSON Patch operations on strategy DSL."""

    def generate_patch(
        self,
        failure_pattern: dict[str, Any],
        target_dsl: dict[str, Any],
    ) -> list[dict[str, Any]]:
        """Generate JSON Patch operations for a given failure pattern.

        ``failure_pattern`` should contain at least a ``label`` key
        (the cluster name) and optionally ``common_features`` with extra
        context.  Falls back to a generic patch if the label is unknown.
        """
        label = failure_pattern.get("label", "")
        common_features = failure_pattern.get("common_features", {})

        # Direct template match
        if label in PATCH_TEMPLATES:
            patch = copy.deepcopy(PATCH_TEMPLATES[label])
            return self._customise_patch(patch, common_features, target_dsl)

        # Try partial matching (e.g. "stop_too_close" matches "stop_too_close_to_liquidity_pool")
        for template_key, template_ops in PATCH_TEMPLATES.items():
            if label in template_key or template_key in label:
                patch = copy.deepcopy(template_ops)
                return self._customise_patch(patch, common_features, target_dsl)

        # Fallback: suggested_fix from common_features as a comment-only patch
        suggested = common_features.get("suggested_fix", "")
        logger.warning(
            "No patch template for cluster label '%s'; creating noop annotation patch", label,
        )
        return [
            {
                "op": "add",
                "path": "/meta/shadow_annotations/-",
                "value": {
                    "source_cluster": label,
                    "suggestion": suggested or "Manual review required",
                    "patch_category": "annotation",
                },
                "description": f"No auto-patch for '{label}' — manual review needed",
            },
        ]

    def apply_patch(
        self,
        dsl: dict[str, Any],
        patch: list[dict[str, Any]],
    ) -> dict[str, Any]:
        """Apply a list of JSON Patch operations to *dsl* and return the
        modified copy.  Supports ``add`` and ``replace`` ops with
        JSON-Pointer-style paths."""
        result = copy.deepcopy(dsl)

        for op in patch:
            operation = op.get("op", "add")
            path = op.get("path", "")
            value = op.get("value")

            if not path:
                continue

            parts = [p for p in path.strip("/").split("/") if p]
            if not parts:
                continue

            if operation == "add":
                self._apply_add(result, parts, value)
            elif operation == "replace":
                self._apply_replace(result, parts, value)
            else:
                logger.warning("Unsupported patch op '%s' — skipping", operation)

        return result

    def validate_patch(
        self,
        patch: list[dict[str, Any]],
        target_dsl: dict[str, Any],
    ) -> PatchValidationResult:
        """Check that *patch* is structurally compatible with *target_dsl*.

        Does NOT validate the resulting DSL (use ``DSLValidator`` for that).
        """
        result = PatchValidationResult()

        for i, op in enumerate(patch):
            operation = op.get("op")
            path = op.get("path", "")

            if operation not in ("add", "replace"):
                result.warnings.append(
                    f"patch[{i}]: unsupported op '{operation}'"
                )

            if not path:
                result.errors.append(f"patch[{i}]: empty path")
                result.compatible = False
                continue

            # For 'replace' ops, verify that the target path exists
            if operation == "replace":
                parts = [p for p in path.strip("/").split("/") if p]
                if not self._path_exists(target_dsl, parts):
                    result.warnings.append(
                        f"patch[{i}]: replace target '{path}' does not exist in DSL "
                        f"— will be created as add",
                    )

            # For 'add' with path ending in '/-', ensure parent is a list
            if operation == "add" and path.endswith("/-"):
                parent_parts = [p for p in path.strip("/").split("/") if p][:-1]
                parent = self._resolve_path(target_dsl, parent_parts)
                if parent is not None and not isinstance(parent, list):
                    result.errors.append(
                        f"patch[{i}]: path '{path}' appends to non-list"
                    )
                    result.compatible = False

        return result

    # ── Private helpers ─────────────────────────────────────────────

    def _customise_patch(
        self,
        patch: list[dict[str, Any]],
        common_features: dict[str, Any],
        target_dsl: dict[str, Any],
    ) -> list[dict[str, Any]]:
        """Optionally adjust template values based on cluster context."""
        # Example: if common_features has a concrete atr_buffer suggestion, use it
        suggested_atr = common_features.get("atr_buffer_coef")
        if suggested_atr is not None:
            for op in patch:
                if op.get("path", "").endswith("/atr_buffer_coef"):
                    op["value"] = suggested_atr

        return patch

    def _apply_add(
        self, obj: dict, parts: list[str], value: Any,
    ) -> None:
        """Navigate *obj* via *parts* and add *value*.  If the final
        segment is ``-`` and the parent is a list, append."""
        current = obj
        for i, part in enumerate(parts[:-1]):
            if isinstance(current, dict):
                current = current.setdefault(part, {})
            elif isinstance(current, list):
                try:
                    current = current[int(part)]
                except (ValueError, IndexError):
                    return
            else:
                return

        last = parts[-1]
        if last == "-" and isinstance(current, (list,)):
            current.append(value)
        elif isinstance(current, dict):
            if last not in current:
                current[last] = value
            elif isinstance(current[last], list) and isinstance(value, dict):
                # If target already is a list and value is a dict, append
                current[last].append(value)
            else:
                current[last] = value

    def _apply_replace(
        self, obj: dict, parts: list[str], value: Any,
    ) -> None:
        """Navigate *obj* via *parts* and replace the leaf value.
        Creates intermediate dicts if missing (graceful degradation)."""
        current = obj
        for part in parts[:-1]:
            if isinstance(current, dict):
                current = current.setdefault(part, {})
            elif isinstance(current, list):
                try:
                    current = current[int(part)]
                except (ValueError, IndexError):
                    return
            else:
                return

        last = parts[-1]
        if isinstance(current, dict):
            current[last] = value

    def _path_exists(self, obj: Any, parts: list[str]) -> bool:
        current = obj
        for part in parts:
            if isinstance(current, dict):
                if part not in current:
                    return False
                current = current[part]
            elif isinstance(current, list):
                try:
                    current = current[int(part)]
                except (ValueError, IndexError):
                    return False
            else:
                return False
        return True

    def _resolve_path(self, obj: Any, parts: list[str]) -> Any:
        current = obj
        for part in parts:
            if isinstance(current, dict):
                current = current.get(part)
            elif isinstance(current, list):
                try:
                    current = current[int(part)]
                except (ValueError, IndexError):
                    return None
            else:
                return None
            if current is None:
                return None
        return current

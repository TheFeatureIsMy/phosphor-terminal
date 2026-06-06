"""DSL hash computation — canonical JSON → sha256."""
import hashlib
import json
from typing import Any


def compute_dsl_hash(dsl: dict[str, Any]) -> str:
    stripped = {k: v for k, v in dsl.items() if k not in ("dsl_hash", "strategy_version_id")}
    canonical = json.dumps(stripped, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(canonical.encode()).hexdigest()

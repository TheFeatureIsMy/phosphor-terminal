"""DeployRulesHandler — write versioned strategy_rules.json + manifest."""
from __future__ import annotations

import json
import hashlib
import logging
import os
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.domain.ledger import ExecutionLedgerEvent
from app.repositories.ledger_repository import LedgerRepository
from app.workers.handlers import CommandHandler

logger = logging.getLogger(__name__)

_BASE_DIR = Path(__file__).resolve().parent.parent.parent.parent
_DEFAULT_RULES_DIR = _BASE_DIR / "freqtrade" / "user_data" / "strategies"


def _utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _atomic_write(path: Path, content: str) -> None:
    """Write to tmp in same directory, fsync, then atomic rename."""
    dir_path = str(path.parent)
    fd, tmp_path = tempfile.mkstemp(dir=dir_path, suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(content)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp_path, str(path))
    except BaseException:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise


class DeployRulesHandler(CommandHandler):
    def __init__(self, rules_dir: Path | None = None):
        self._rules_dir = rules_dir or _DEFAULT_RULES_DIR

    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        payload = command.payload
        dsl = payload["dsl"]
        strategy_version_id = payload["strategy_version_id"]
        dsl_hash = payload.get("dsl_hash", "")

        self._rules_dir.mkdir(parents=True, exist_ok=True)

        rules_path = self._rules_dir / "strategy_rules.json"
        rules_content = json.dumps(dsl, indent=2, ensure_ascii=False)
        _atomic_write(rules_path, rules_content)

        manifest = {
            "strategy_version_id": strategy_version_id,
            "dsl_hash": dsl_hash,
            "rule_package_version": dsl.get("schema_version", "2.5"),
            "created_at": _utcnow().isoformat(),
            "validator_version": "2.5",
            "content_sha256": hashlib.sha256(rules_content.encode()).hexdigest(),
        }
        manifest_path = self._rules_dir / "strategy_rules_manifest.json"
        _atomic_write(manifest_path, json.dumps(manifest, indent=2))

        return {
            "rules_path": str(rules_path),
            "manifest_path": str(manifest_path),
            "dsl_hash": dsl_hash,
            "strategy_version_id": strategy_version_id,
        }

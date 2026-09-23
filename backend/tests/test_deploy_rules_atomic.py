"""Tests for DeployRulesHandler atomic write behavior."""
import json
import os
import uuid
from pathlib import Path
from unittest.mock import patch

import pytest
from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand
from app.workers.deploy_rules_handler import DeployRulesHandler, _atomic_write


SAMPLE_DSL = {
    "schema_version": "2.5",
    "timeframe": "1h",
    "symbols": ["BTC/USDT"],
    "entry": {"logic": "AND", "rules": []},
    "exit": {"logic": "OR", "rules": []},
    "risk": {"stoploss": -0.05, "max_open_trades": 3},
}


def _make_cmd(session: Session, dsl: dict) -> CommandBusCommand:
    cmd = CommandBusCommand(
        command_type="deploy_rules",
        aggregate_type="strategy_version",
        aggregate_id=uuid.uuid4(),
        payload={
            "dsl": dsl,
            "strategy_version_id": str(uuid.uuid4()),
            "dsl_hash": "abc123",
        },
        idempotency_key=str(uuid.uuid4()),
        requested_by="test",
        status="running",
    )
    session.add(cmd)
    session.flush()
    return cmd


class TestAtomicWrite:
    def test_writes_complete_content(self, tmp_path: Path):
        target = tmp_path / "test.json"
        content = json.dumps({"key": "value"}, indent=2)
        _atomic_write(target, content)
        assert target.read_text(encoding="utf-8") == content

    def test_no_tmp_files_remain(self, tmp_path: Path):
        target = tmp_path / "test.json"
        _atomic_write(target, "hello")
        remaining = list(tmp_path.glob("*.tmp"))
        assert remaining == []

    def test_failure_cleans_up_tmp(self, tmp_path: Path):
        target = tmp_path / "test.json"
        target.write_text("original", encoding="utf-8")

        with patch("os.replace", side_effect=OSError("disk full")):
            with pytest.raises(OSError, match="disk full"):
                _atomic_write(target, "new content")

        # Original file unchanged
        assert target.read_text(encoding="utf-8") == "original"
        # No tmp files left
        remaining = list(tmp_path.glob("*.tmp"))
        assert remaining == []

    def test_overwrites_existing_atomically(self, tmp_path: Path):
        target = tmp_path / "test.json"
        _atomic_write(target, "first")
        _atomic_write(target, "second")
        assert target.read_text(encoding="utf-8") == "second"


class TestDeployRulesHandlerAtomic:
    def test_deploy_produces_valid_files(self, session: Session, tmp_path: Path):
        handler = DeployRulesHandler(rules_dir=tmp_path)
        cmd = _make_cmd(session, SAMPLE_DSL)
        result = handler.execute(cmd, session)

        rules_path = Path(result["rules_path"])
        manifest_path = Path(result["manifest_path"])

        assert rules_path.exists()
        assert manifest_path.exists()

        rules_data = json.loads(rules_path.read_text(encoding="utf-8"))
        assert rules_data == SAMPLE_DSL

        manifest_data = json.loads(manifest_path.read_text(encoding="utf-8"))
        assert manifest_data["dsl_hash"] == "abc123"
        assert manifest_data["rule_package_version"] == "2.5"
        assert "content_sha256" in manifest_data

    def test_no_tmp_files_after_deploy(self, session: Session, tmp_path: Path):
        handler = DeployRulesHandler(rules_dir=tmp_path)
        cmd = _make_cmd(session, SAMPLE_DSL)
        handler.execute(cmd, session)

        tmp_files = list(tmp_path.glob("*.tmp"))
        assert tmp_files == []

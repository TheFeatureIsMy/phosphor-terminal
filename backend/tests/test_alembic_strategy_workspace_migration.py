"""Verify the strategy workspace migration applies and reverts cleanly."""
import subprocess
import sys
from pathlib import Path

import pytest

BACKEND = Path(__file__).resolve().parents[1]
PYTHON = sys.executable


def _alembic(*args: str) -> subprocess.CompletedProcess:
    return subprocess.run(
        [PYTHON, "-m", "alembic", *args],
        cwd=BACKEND,
        capture_output=True,
        text=True,
        check=False,
    )


@pytest.mark.skipif(
    _alembic("current").returncode != 0,
    reason="alembic not configured for this environment",
)
def test_migration_round_trip():
    upgrade = _alembic("upgrade", "head")
    assert upgrade.returncode == 0, upgrade.stderr

    downgrade = _alembic("downgrade", "-1")
    assert downgrade.returncode == 0, downgrade.stderr

    upgrade_again = _alembic("upgrade", "head")
    assert upgrade_again.returncode == 0, upgrade_again.stderr

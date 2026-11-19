"""Audit archive verifier script."""
import gzip
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location(
    "verify_audit_archive",
    Path(__file__).resolve().parents[2] / "scripts" / "verify-audit-archive.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def test_verify_ok(tmp_path):
    with gzip.open(tmp_path / "a.jsonl.gz", "wt", encoding="utf-8") as fh:
        fh.write(json.dumps({"id": 1, "action": "x"}) + "\n")
    files, records, errors = module.verify(tmp_path)
    assert (files, records, errors) == (1, 1, [])


def test_verify_corrupt(tmp_path):
    (tmp_path / "bad.jsonl.gz").write_bytes(b"not gzip")
    files, records, errors = module.verify(tmp_path)
    assert files == 1 and records == 0 and errors

#!/usr/bin/env python3
"""Verify JSONL.gz audit archives are readable and well-formed."""
from __future__ import annotations

import argparse
import gzip
import json
import sys
from pathlib import Path


def verify(directory: Path) -> tuple[int, int, list[str]]:
    files = sorted(directory.glob("*.jsonl.gz"))
    records = 0
    errors: list[str] = []
    for path in files:
        try:
            with gzip.open(path, "rt", encoding="utf-8") as fh:
                for lineno, line in enumerate(fh, 1):
                    if not line.strip():
                        continue
                    json.loads(line)
                    records += 1
        except Exception as exc:  # corrupt gzip/JSON
            errors.append(f"{path.name}:{lineno if 'lineno' in locals() else 0}: {exc}")
    return len(files), records, errors


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    if not args.directory.is_dir():
        print(f"not a directory: {args.directory}")
        return 2
    files, records, errors = verify(args.directory)
    for error in errors:
        print(f"ERROR {error}")
    print(f"archives={files} records={records} errors={len(errors)}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())

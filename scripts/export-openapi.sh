#!/usr/bin/env bash
# Export the FastAPI OpenAPI document for client codegen (Dart / TS).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON="${PYTHON:-$ROOT/.venv/bin/python}"
OUT="$ROOT/docs/api/openapi.json"
mkdir -p "$(dirname "$OUT")"
(
  cd "$ROOT/backend"
  "$PYTHON" -c 'import json; from app.main import app; print(json.dumps(app.openapi(), ensure_ascii=False, indent=2))'
) > "$OUT"
echo "wrote $OUT"

#!/usr/bin/env bash
# 用 backend/.env 里的 BINANCE_DEMO_API_KEY / BINANCE_DEMO_API_SECRET
# 生成 freqtrade/user_data/config.demo.json。没有这两个值就退出。
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT/backend/.env"
EXAMPLE="$ROOT/freqtrade/user_data/config.demo.example.json"
OUT="$ROOT/freqtrade/user_data/config.demo.json"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "还没有 $ENV_FILE。先复制 backend/.env.example 再填 Demo 密钥。" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ -z "${BINANCE_DEMO_API_KEY:-}" || -z "${BINANCE_DEMO_API_SECRET:-}" ]]; then
  echo "BINANCE_DEMO_API_KEY 和 BINANCE_DEMO_API_SECRET 还是空的。到 https://demo.binance.com/en/my/settings/api-management 创建 Demo Mode 密钥后再运行本脚本。" >&2
  exit 1
fi

python3 - "$EXAMPLE" "$OUT" "$BINANCE_DEMO_API_KEY" "$BINANCE_DEMO_API_SECRET" <<'PY'
import json, sys
example, out, key, secret = sys.argv[1:5]
cfg = json.load(open(example))
cfg["exchange"]["key"] = key
cfg["exchange"]["secret"] = secret
json.dump(cfg, open(out, "w"), indent=2)
print(out)
PY

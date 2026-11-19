#!/usr/bin/env python3
"""Generate a self-contained Freqtrade config for a tenant runtime.

Example:
  scripts/generate-tenant-config.py --tenant-id 42 --dsl dsl.json \
    --budget 10000 --position-pct 0.02 --out /data/tenants/42/config.json
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from app.schemas.live_small import CapitalPoolParams  # noqa: E402
from app.services.live_small.runtime_config import (  # noqa: E402
    build_tenant_runtime_config,
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--tenant-id", type=int, required=True)
    parser.add_argument("--dsl", required=True, help="path to rule DSL JSON")
    parser.add_argument("--budget", type=float, required=True)
    parser.add_argument("--position-pct", type=float, default=0.02)
    parser.add_argument("--max-total-exposure-pct", type=float, default=0.2)
    parser.add_argument("--daily-loss-pct", type=float, default=0.03)
    parser.add_argument("--max-drawdown-pct", type=float, default=0.1)
    parser.add_argument("--max-open-trades", type=int, default=None)
    parser.add_argument("--api-port", type=int, default=8080)
    parser.add_argument("--api-username", default="freqtrade")
    parser.add_argument("--api-password", default="freqtrade")
    parser.add_argument("--live", action="store_true", help="default is dry-run")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    if args.tenant_id < 1:
        print("--tenant-id must be >= 1", file=sys.stderr)
        return 2
    dsl = json.loads(Path(args.dsl).read_text())
    pool = CapitalPoolParams(
        total_budget=args.budget,
        max_position_pct_per_trade=args.position_pct,
        max_total_exposure_pct=args.max_total_exposure_pct,
        max_daily_loss_pct=args.daily_loss_pct,
        max_drawdown_pct=args.max_drawdown_pct,
    )
    config = build_tenant_runtime_config(
        dsl,
        pool,
        tenant_id=args.tenant_id,
        dry_run=not args.live,
        max_open_trades_cap=args.max_open_trades,
        api_port=args.api_port,
        api_username=args.api_username,
        api_password=args.api_password,
    )
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(config, indent=2, sort_keys=True))
    os.chmod(out, 0o600)
    print(f"wrote {out} (dry_run={config['dry_run']}, max_open_trades={config['max_open_trades']})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

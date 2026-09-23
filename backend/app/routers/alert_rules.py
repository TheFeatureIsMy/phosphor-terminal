"""Alert Rules API — CRUD alert rules + evaluation engine.

Rules are stored in system_settings with category="alert_rules".
Each rule defines a condition (price/risk/drawdown) and a notification action.
Evaluation runs on-demand or on a schedule, creating NotificationRecord entries.
"""
from __future__ import annotations

import json
import logging
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.strategy import NotificationRecord
from app.services.system_settings import SystemSettingsService

logger = logging.getLogger(__name__)
router = APIRouter(prefix="/api/alert-rules", tags=["alert-rules"])

_svc = SystemSettingsService()


class AlertRule(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4())[:8])
    name: str
    enabled: bool = True
    condition_type: str  # price_above | price_below | drawdown_exceeds | risk_event
    symbol: str = "BTC/USDT"
    threshold: float = Field(default=0, ge=0)  # 价格/回撤阈值必须非负
    severity: str = "medium"  # low | medium | high | critical
    message: str = ""


class AlertRulesPayload(BaseModel):
    rules: list[AlertRule] = []


def _load_rules(db: Session) -> list[dict]:
    row = _svc.get(db, "alert_rules.definitions")
    if row is None:
        return []
    value = row.value
    if isinstance(value, dict) and "rules" in value:
        return value["rules"]
    if isinstance(value, list):
        return value
    return []


def _save_rules(db: Session, rules: list[dict]) -> None:
    _svc.upsert(db, key="alert_rules.definitions", value={"rules": rules}, category="alert_rules", updated_by="api")
    db.commit()


@router.get("")
def list_rules(db: Session = Depends(get_db)):
    return {"rules": _load_rules(db)}


@router.post("", status_code=201)
def create_rule(body: AlertRule, db: Session = Depends(get_db)):
    rules = _load_rules(db)
    rule = body.model_dump()
    rules.append(rule)
    _save_rules(db, rules)
    return rule


@router.put("/{rule_id}")
def update_rule(rule_id: str, body: AlertRule, db: Session = Depends(get_db)):
    rules = _load_rules(db)
    for i, r in enumerate(rules):
        if r.get("id") == rule_id:
            rules[i] = body.model_dump()
            rules[i]["id"] = rule_id
            _save_rules(db, rules)
            return rules[i]
    raise HTTPException(status_code=404, detail="Rule not found")


@router.delete("/{rule_id}", status_code=204)
def delete_rule(rule_id: str, db: Session = Depends(get_db)):
    rules = _load_rules(db)
    rules = [r for r in rules if r.get("id") != rule_id]
    _save_rules(db, rules)


@router.post("/evaluate")
def evaluate_rules(db: Session = Depends(get_db)):
    """Manually trigger rule evaluation against current data."""
    rules = [r for r in _load_rules(db) if r.get("enabled", True)]
    if not rules:
        return {"evaluated": 0, "triggered": 0}

    # Gather current data for evaluation
    current = _gather_current_data(db)
    triggered = []

    for rule in rules:
        if _check_rule(rule, current):
            notification = NotificationRecord(
                type=f"alert_{rule.get('severity', 'medium')}",
                title=f"告警: {rule.get('name', '未命名规则')}",
                message=rule.get("message") or _default_message(rule, current),
            )
            db.add(notification)
            triggered.append(rule.get("id"))

    if triggered:
        db.commit()

    return {"evaluated": len(rules), "triggered": len(triggered), "rule_ids": triggered}


def _gather_current_data(db: Session) -> dict:
    """Gather current market/risk data for rule evaluation."""
    data: dict = {"prices": {}, "risk": {}, "timestamp": datetime.now(timezone.utc).isoformat()}

    # Try to get latest ticker prices
    try:
        from app.services.providers.realtime.ticker_cache import ticker_cache
        for symbol, ticker in ticker_cache.all().items():
            data["prices"][symbol] = {
                "last": ticker.get("last"),
                "change_pct": ticker.get("change_pct"),
            }
    except Exception:
        pass

    # Try to get risk overview
    try:
        from app.services.overview_aggregator import OverviewAggregatorService
        import asyncio
        agg = OverviewAggregatorService()
        loop = asyncio.new_event_loop()
        result = loop.run_until_complete(agg.aggregate())
        loop.close()
        data["risk"] = {
            "global_state": result.get("risk", {}).get("global_state", "unknown"),
            "daily_loss_remaining_pct": result.get("risk", {}).get("daily_loss_remaining_pct", 100),
            "max_drawdown_pct": result.get("account", {}).get("max_drawdown_pct", 0),
        }
    except Exception:
        pass

    return data


def _check_rule(rule: dict, current: dict) -> bool:
    """Check if a rule's condition is met."""
    cond = rule.get("condition_type", "")
    threshold = rule.get("threshold", 0)
    symbol = rule.get("symbol", "")

    if cond == "price_above":
        price_data = current.get("prices", {}).get(symbol, {})
        last = price_data.get("last")
        return last is not None and float(last) > threshold

    if cond == "price_below":
        price_data = current.get("prices", {}).get(symbol, {})
        last = price_data.get("last")
        return last is not None and float(last) < threshold

    if cond == "drawdown_exceeds":
        dd = current.get("risk", {}).get("max_drawdown_pct", 0)
        return float(dd) > threshold

    if cond == "risk_event":
        state = current.get("risk", {}).get("global_state", "normal")
        return state != "normal"

    return False


def _default_message(rule: dict, current: dict) -> str:
    cond = rule.get("condition_type", "")
    symbol = rule.get("symbol", "")
    threshold = rule.get("threshold", 0)

    if cond == "price_above":
        price = current.get("prices", {}).get(symbol, {}).get("last", "?")
        return f"{symbol} 价格 {price} 超过阈值 {threshold}"
    if cond == "price_below":
        price = current.get("prices", {}).get(symbol, {}).get("last", "?")
        return f"{symbol} 价格 {price} 低于阈值 {threshold}"
    if cond == "drawdown_exceeds":
        dd = current.get("risk", {}).get("max_drawdown_pct", "?")
        return f"最大回撤 {dd}% 超过阈值 {threshold}%"
    if cond == "risk_event":
        state = current.get("risk", {}).get("global_state", "?")
        return f"风险状态异常: {state}"
    return "规则触发"
from __future__ import annotations

from typing import Any, Optional


def build_risk_message(event: dict[str, Any]) -> str:
    severity = str(event.get("severity", "info")).upper()
    event_type = event.get("event_type", "risk_event")
    description = event.get("description") or "Risk event generated."
    action = event.get("action_taken") or "review_required"
    return f"[PulseDesk][{severity}] {event_type}: {description} Action: {action}"


def send_telegram_notification(
    event: dict[str, Any],
    *,
    dry_run: bool = True,
    bot_token: Optional[str] = None,
    chat_id: Optional[str] = None,
) -> dict[str, Any]:
    message = build_risk_message(event)
    if dry_run or not bot_token or not chat_id:
        return {
            "status": "dry_run",
            "message": message,
            "destination": chat_id or "not_configured",
        }

    return {
        "status": "queued",
        "message": message,
        "destination": chat_id,
    }

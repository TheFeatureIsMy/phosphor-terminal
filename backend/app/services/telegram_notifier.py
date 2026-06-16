"""telegram_notifier — thin wrapper that pulls creds from provider_configs."""
from __future__ import annotations

import logging
from typing import Any, Optional

import aiohttp

from app.services.providers.base import ProviderCategory
from app.services.providers.config_service import ProviderConfigService

logger = logging.getLogger(__name__)


def build_risk_message(event: dict[str, Any]) -> str:
    severity = str(event.get("severity", "info")).upper()
    event_type = event.get("event_type", "risk_event")
    description = event.get("description") or "Risk event generated."
    action = event.get("action_taken") or "review_required"
    return f"[PulseDesk][{severity}] {event_type}: {description} Action: {action}"


async def send_telegram_notification(
    event: dict[str, Any],
    *,
    dry_run: bool = True,
    bot_token: Optional[str] = None,
    chat_id: Optional[str] = None,
) -> dict[str, Any]:
    from app.database import SessionLocal

    message = build_risk_message(event)

    if not bot_token or not chat_id:
        try:
            svc = ProviderConfigService()
            with SessionLocal() as db:
                row = svc.get_by_identity(
                    db, category=ProviderCategory.NOTIFICATION.value,
                    provider_name="telegram",
                )
            if row and row.enabled and row.credentials_ct:
                creds = svc.decrypt_credentials(row) or {}
                bot_token = bot_token or creds.get("bot_token")
                chat_id = chat_id or creds.get("chat_id")
                cfg = row.config or {}
                if cfg.get("dry_run"):
                    dry_run = True
        except Exception:
            logger.warning("Failed to read telegram config from DB", exc_info=True)

    if dry_run or not bot_token or not chat_id:
        return {
            "status": "dry_run",
            "message": message,
            "destination": chat_id or "not_configured",
        }

    url = f"https://api.telegram.org/bot{bot_token}/sendMessage"
    try:
        timeout = aiohttp.ClientTimeout(total=10)
        async with aiohttp.ClientSession(timeout=timeout) as session:
            async with session.post(url, json={"chat_id": chat_id, "text": message}) as resp:
                if resp.status == 200:
                    return {
                        "status": "sent",
                        "message": message,
                        "destination": chat_id,
                        "telegram_response": await resp.json(),
                    }
                return {
                    "status": "error",
                    "message": message,
                    "destination": chat_id,
                    "detail": f"HTTP {resp.status}: {await resp.text()}",
                }
    except Exception as exc:
        logger.exception("Telegram send failed")
        return {
            "status": "error",
            "message": message,
            "destination": chat_id,
            "detail": str(exc),
        }

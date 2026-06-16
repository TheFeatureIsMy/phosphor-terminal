"""WebSocket route for real-time provider health updates."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.database import SessionLocal
from app.models.provider_config import ProviderConfig
from app.services.providers.config_service import ProviderConfigService
from app.services.providers.realtime.health_broadcaster import broadcaster

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/ws", tags=["providers-realtime"])


@router.websocket("/provider-health")
async def provider_health_ws(websocket: WebSocket) -> None:
    await websocket.accept()
    queue = broadcaster.subscribe()
    svc = ProviderConfigService()
    try:
        with SessionLocal() as db:
            rows = svc.list(db)
            view_list = []
            for r in rows:
                v = svc.to_view(r).model_dump(mode="json")
                v["provider_id"] = r.id
                view_list.append(v)
        await websocket.send_json({
            "type": "snapshot",
            "ts": datetime.now(timezone.utc).isoformat(),
            "providers": view_list,
        })

        while True:
            try:
                msg = await asyncio.wait_for(queue.get(), timeout=30.0)
                await websocket.send_json(msg)
            except asyncio.TimeoutError:
                await websocket.send_json({"type": "heartbeat", "ts": datetime.now(timezone.utc).isoformat()})
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.exception("WebSocket error: %s", exc)
    finally:
        broadcaster.unsubscribe(queue)

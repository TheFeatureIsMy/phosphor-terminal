"""WebSocket route for Manipulation Radar real-time events."""
from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from app.services.manipulation.pubsub import subscribe, unsubscribe

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v2/manipulation", tags=["manipulation-radar-ws"])


def _snapshot_payload() -> dict:
    try:
        from app.routers.manipulation import _get_case_repo
        repo = _get_case_repo()
        overview = repo.get_radar_overview()
        return {
            "type": "snapshot",
            "ts": datetime.now(timezone.utc).isoformat(),
            "active_cases": overview.get("active_cases", []),
        }
    except Exception as exc:
        logger.warning("Snapshot build failed: %s", exc)
        return {"type": "snapshot", "ts": datetime.now(timezone.utc).isoformat(), "active_cases": []}


@router.websocket("/stream")
async def manipulation_stream(websocket: WebSocket) -> None:
    await websocket.accept()
    queue = subscribe()
    try:
        await websocket.send_json(_snapshot_payload())
        while True:
            try:
                msg = await asyncio.wait_for(queue.get(), timeout=30.0)
                await websocket.send_json(msg)
            except asyncio.TimeoutError:
                await websocket.send_json({
                    "type": "heartbeat",
                    "ts": datetime.now(timezone.utc).isoformat(),
                })
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.exception("Manipulation WS error: %s", exc)
    finally:
        unsubscribe(queue)

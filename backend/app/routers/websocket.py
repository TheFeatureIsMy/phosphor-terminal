"""WebSocket endpoint for real-time push notifications."""

import asyncio
import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

router = APIRouter(tags=["websocket"])


class ConnectionManager:
    """Manages WebSocket connections and channel subscriptions."""

    def __init__(self):
        self._connections: dict[WebSocket, set[str]] = {}
        self._lock = asyncio.Lock()

    async def connect(self, ws: WebSocket):
        await ws.accept()
        async with self._lock:
            self._connections[ws] = set()

    async def disconnect(self, ws: WebSocket):
        async with self._lock:
            self._connections.pop(ws, None)

    async def subscribe(self, ws: WebSocket, channels: list[str]):
        async with self._lock:
            if ws in self._connections:
                self._connections[ws].update(channels)

    async def unsubscribe(self, ws: WebSocket, channels: list[str]):
        async with self._lock:
            if ws in self._connections:
                self._connections[ws] -= set(channels)

    async def broadcast(self, channel: str, data: dict):
        message = json.dumps({"channel": channel, "data": data})
        async with self._lock:
            targets = [ws for ws, chs in self._connections.items() if channel in chs]
        for ws in targets:
            try:
                await ws.send_text(message)
            except Exception:
                await self.disconnect(ws)


manager = ConnectionManager()


@router.websocket("/ws")
async def websocket_endpoint(ws: WebSocket):
    await manager.connect(ws)
    try:
        while True:
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue

            action = msg.get("action")
            channels = msg.get("channels", [])

            if action == "subscribe" and isinstance(channels, list):
                await manager.subscribe(ws, channels)
                await ws.send_text(json.dumps({"action": "subscribed", "channels": channels}))
            elif action == "unsubscribe" and isinstance(channels, list):
                await manager.unsubscribe(ws, channels)
                await ws.send_text(json.dumps({"action": "unsubscribed", "channels": channels}))
            elif action == "ping":
                await ws.send_text(json.dumps({"action": "pong"}))
    except WebSocketDisconnect:
        await manager.disconnect(ws)

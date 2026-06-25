"""In-process pub/sub for manipulation events. Fires WS push notifications."""
from __future__ import annotations

import asyncio
import logging

logger = logging.getLogger(__name__)

_subscribers: list[asyncio.Queue] = []
_QUEUE_MAXSIZE = 256


def subscribe() -> asyncio.Queue:
    q: asyncio.Queue = asyncio.Queue(maxsize=_QUEUE_MAXSIZE)
    _subscribers.append(q)
    return q


def unsubscribe(q: asyncio.Queue) -> None:
    try:
        _subscribers.remove(q)
    except ValueError:
        pass


def publish_event(event: dict) -> None:
    """Broadcast event to all subscribers. Sync-safe (drops on full queue)."""
    for q in list(_subscribers):
        try:
            q.put_nowait(event)
        except asyncio.QueueFull:
            logger.warning("Manipulation pubsub queue full; dropping event")
        except Exception as exc:
            logger.warning("Manipulation pubsub publish failed: %s", exc)

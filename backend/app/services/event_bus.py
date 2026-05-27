"""
Event bus for inter-service communication
"""
from typing import Any, Callable, Dict, List
from collections import defaultdict


class EventBus:
    def __init__(self):
        self._handlers: Dict[str, List[Callable]] = defaultdict(list)

    def subscribe(self, event: str, handler: Callable[..., Any]) -> None:
        """Subscribe to an event"""
        self._handlers[event].append(handler)

    def unsubscribe(self, event: str, handler: Callable[..., Any]) -> None:
        """Unsubscribe from an event"""
        if event in self._handlers:
            self._handlers[event] = [h for h in self._handlers[event] if h != handler]

    def emit(self, event: str, *args: Any, **kwargs: Any) -> None:
        """Emit an event"""
        for handler in self._handlers.get(event, []):
            try:
                handler(*args, **kwargs)
            except Exception as e:
                print(f"Error in event handler for {event}: {e}")

    def clear(self) -> None:
        """Clear all handlers"""
        self._handlers.clear()


# Global event bus instance
event_bus = EventBus()

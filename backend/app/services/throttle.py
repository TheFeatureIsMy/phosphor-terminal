"""
Throttle utilities
"""
import time
from typing import TypeVar, Callable, Any
from functools import wraps

T = TypeVar('T')


def throttle(limit: float):
    """Throttle decorator"""
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        last_call = 0.0

        @wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            nonlocal last_call
            now = time.time()
            if now - last_call >= limit:
                last_call = now
                return func(*args, **kwargs)
            raise ThrottledError(f"Function throttled. Try again in {limit - (now - last_call):.2f}s")

        return wrapper
    return decorator


class ThrottledError(Exception):
    """Raised when a function is throttled"""
    pass


class RateLimiter:
    """Simple rate limiter"""
    def __init__(self, max_calls: int, period: float):
        self.max_calls = max_calls
        self.period = period
        self.calls: list[float] = []

    def allow(self) -> bool:
        """Check if a call is allowed"""
        now = time.time()
        self.calls = [t for t in self.calls if now - t < self.period]
        if len(self.calls) < self.max_calls:
            self.calls.append(now)
            return True
        return False

    def wait_time(self) -> float:
        """Get time to wait before next call"""
        if not self.calls:
            return 0.0
        now = time.time()
        oldest = self.calls[0]
        return max(0.0, self.period - (now - oldest))

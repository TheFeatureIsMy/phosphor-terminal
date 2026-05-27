"""
Retry utilities
"""
import time
from typing import TypeVar, Callable, Any, Optional
from functools import wraps

T = TypeVar('T')


def retry(
    max_attempts: int = 3,
    delay: float = 1.0,
    backoff: str = 'exponential',
    exceptions: tuple = (Exception,),
):
    """Retry decorator"""
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> T:
            last_exception = None
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    last_exception = e
                    if attempt < max_attempts - 1:
                        wait_time = delay * (2 ** attempt if backoff == 'exponential' else 1)
                        time.sleep(wait_time)
            raise last_exception
        return wrapper
    return decorator


def retry_with_fallback(
    max_attempts: int = 3,
    delay: float = 1.0,
    fallback: Optional[T] = None,
):
    """Retry with fallback value"""
    def decorator(func: Callable[..., T]) -> Callable[..., Optional[T]]:
        @wraps(func)
        def wrapper(*args: Any, **kwargs: Any) -> Optional[T]:
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except Exception:
                    if attempt < max_attempts - 1:
                        time.sleep(delay)
            return fallback
        return wrapper
    return decorator

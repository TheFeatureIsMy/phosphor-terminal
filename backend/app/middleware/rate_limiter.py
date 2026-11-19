"""
Rate limiting middleware for FastAPI
"""
import time
from collections import defaultdict
from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware


class RateLimitMiddleware(BaseHTTPMiddleware):
    def __init__(
        self,
        app,
        requests_per_minute: int = 60,
        burst_size: int = 10,
    ):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.burst_size = burst_size
        self.requests: dict[str, list[float]] = defaultdict(list)

    async def dispatch(self, request: Request, call_next):
        # Skip rate limiting for health check
        if request.url.path == "/health":
            return await call_next(request)

        client_ip = request.client.host if request.client else "unknown"
        now = time.time()

        # Clean old requests; drop the key entirely so the dict cannot grow
        # without bound as clients come and go.
        recent = [t for t in self.requests.get(client_ip, []) if now - t < 60]
        if recent:
            self.requests[client_ip] = recent
        else:
            self.requests.pop(client_ip, None)

        if len(recent) >= self.requests_per_minute:
            return JSONResponse(
                status_code=429,
                content={
                    "detail": "Rate limit exceeded",
                    "retry_after": 60,
                },
                headers={"Retry-After": "60"},
            )

        # Add request timestamp
        self.requests[client_ip] = recent + [now]

        return await call_next(request)

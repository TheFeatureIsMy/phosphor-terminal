from pydantic import BaseModel


class HealthResponse(BaseModel):
    status: str
    version: str


class ReadinessResponse(BaseModel):
    status: str
    database: str
    redis: str = "unknown"
    freqtrade: str = "unknown"
    reason_codes: list[str] = []

import os
from pydantic_settings import BaseSettings

PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))


class Settings(BaseSettings):
    database_url: str = "postgresql://pulsedesk:pulsedesk@localhost:5432/pulsedesk"

    redis_url: str = "redis://localhost:6379/0"
    snapshot_ttl_seconds: int = 300

    freqtrade_url: str = "http://localhost:8080"
    freqtrade_username: str = "freqtrade"
    freqtrade_password: str = "freqtrade"
    freqtrade_db_path: str = os.path.join(PROJECT_ROOT, "freqtrade", "user_data", "tradesv3.sqlite")

    cors_origins: list[str] = ["http://localhost:5173", "http://localhost:5174"]

    secret_key: str = "pulsedesk-dev-secret-change-in-production"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    rate_limit_per_minute: int = 60
    rate_limit_burst: int = 10

    log_level: str = "INFO"
    log_format: str = "json"

    debug: bool = False

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()

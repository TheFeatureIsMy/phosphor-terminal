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

    # Provider health scheduler (sub-project 1 of provider foundation)
    # Command worker loop
    command_worker_poll_interval_s: float = 2.0
    command_worker_stale_recovery_s: float = 60.0
    command_worker_enabled: bool = True

    # Trade sync loop
    trade_sync_interval_s: float = 15.0
    trade_sync_enabled: bool = True
    trade_sync_heartbeat_stale_s: int = 30

    # Provider health scheduler (sub-project 1 of provider foundation)
    provider_health_interval_s: int = 60
    provider_health_batch_size: int = 10
    provider_health_enabled: bool = True

    # Live small execution gate — off by default (v2.5 rollout: dry-run first).
    # When false, POST /api/trading/start-live-small returns not_enabled even if
    # the full safety gate chain approves the request.
    live_small_enabled: bool = False

    log_level: str = "INFO"
    log_format: str = "json"

    debug: bool = False

    model_config = {"env_file": ".env", "extra": "ignore"}


settings = Settings()

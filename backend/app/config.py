import os
from pydantic_settings import BaseSettings

# Project root: backend/.. = cyberquant-os/
PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))


class Settings(BaseSettings):
    # Database
    database_url: str = f"sqlite:///{os.path.join(PROJECT_ROOT, 'data', 'cyberquant.db')}"

    # Freqtrade
    freqtrade_url: str = "http://localhost:8080"
    freqtrade_db_path: str = os.path.join(PROJECT_ROOT, "freqtrade", "user_data", "tradesv3.sqlite")

    # CORS
    cors_origins: list[str] = ["http://localhost:5173"]

    # Security
    secret_key: str = "cyberquant-dev-secret-change-in-production"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7

    # Rate limiting
    rate_limit_per_minute: int = 60
    rate_limit_burst: int = 10

    # Debug
    debug: bool = False

    model_config = {"env_file": ".env"}


settings = Settings()

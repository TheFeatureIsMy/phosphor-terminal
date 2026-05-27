import os
from pydantic_settings import BaseSettings

# Project root: backend/.. = cyberquant-os/
PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))


class Settings(BaseSettings):
    database_url: str = f"sqlite:///{os.path.join(PROJECT_ROOT, 'data', 'cyberquant.db')}"
    freqtrade_url: str = "http://localhost:8080"
    freqtrade_db_path: str = os.path.join(PROJECT_ROOT, "freqtrade", "user_data", "tradesv3.sqlite")
    cors_origins: list[str] = ["http://localhost:5173"]
    secret_key: str = "cyberquant-dev-secret-change-in-production"

    model_config = {"env_file": ".env"}


settings = Settings()

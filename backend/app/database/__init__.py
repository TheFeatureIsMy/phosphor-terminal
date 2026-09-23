from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.ext.compiler import compiles
from sqlalchemy.dialects.postgresql import JSONB, UUID as PG_UUID

from app.config import settings
from app.database.base import Base


# SQLite compatibility: render PostgreSQL types as their SQLite equivalents
if settings.database_url.startswith("sqlite"):
    @compiles(JSONB, "sqlite")
    def _compile_jsonb_sqlite(type_, compiler, **kw):
        return "JSON"

    @compiles(PG_UUID, "sqlite")
    def _compile_uuid_sqlite(type_, compiler, **kw):
        return "CHAR(32)"


from app.domain.activity_log import StrategyActivityLog  # noqa: F401
from app.domain.circuit_breaker import CircuitBreakerEvent  # noqa: F401
from app.domain.volatility_lock import VolatilityLock  # noqa: F401
from app.domain.stop_protection import StopProtectionSnapshot  # noqa: F401
from app.domain.live_readiness import LiveReadinessCheck  # noqa: F401

engine = create_engine(settings.database_url)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    Base.metadata.create_all(bind=engine)


def check_db() -> bool:
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False

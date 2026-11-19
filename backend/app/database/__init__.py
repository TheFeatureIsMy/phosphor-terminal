from sqlalchemy import create_engine, event, text
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
_BASE_ENGINE = engine
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Workers must not inherit the RLS-constrained API role once policies are
# enabled. Without a separate URL they share the API engine (dev/test).
worker_engine = (
    create_engine(settings.database_url_worker)
    if settings.database_url_worker
    else engine
)
WorkerSessionLocal = sessionmaker(
    autocommit=False, autoflush=False, bind=worker_engine,
)


@event.listens_for(Session, "after_begin")
def _apply_tenant_context(session, transaction, connection) -> None:
    """Expose the request tenant to PostgreSQL for RLS policies.

    ``set_config(..., true)`` is transaction-scoped and resets automatically at
    commit / rollback. SQLite and other dialects are ignored.
    """
    if connection.dialect.name != "postgresql":
        return
    from app.security.tenant_context import get_current_tenant

    tenant_id = get_current_tenant()
    if tenant_id is None:
        return
    connection.execute(
        text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
        {"tenant_id": str(tenant_id)},
    )


# Generic tenant backfill for inserts that derive ownership from a parent.
from app.database import tenant_autofill  # noqa: E402,F401


def get_db(request=None):
    db = SessionLocal()
    tenant_id = getattr(getattr(request, "state", None), "tenant_id", None)
    if tenant_id is not None and db.get_bind().dialect.name == "postgresql":
        db.execute(
            text("SELECT set_config('app.tenant_id', :tenant_id, true)"),
            {"tenant_id": str(tenant_id)},
        )
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

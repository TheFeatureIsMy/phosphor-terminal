import os
import sys

# Tests default to in-memory SQLite. Set TEST_DATABASE_URL to run the same
# fixtures against PostgreSQL (e.g. postgresql://postgres@127.0.0.1:55440/test).
TEST_DATABASE_URL = os.environ.get("TEST_DATABASE_URL")
if TEST_DATABASE_URL:
    os.environ["DATABASE_URL"] = TEST_DATABASE_URL
else:
    os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("PROVIDER_HEALTH_INTERVAL_S", "0")
# Auth middleware is exercised by tests/test_auth_middleware.py explicitly;
# the rest of the suite talks to the app without a login handshake.
os.environ.setdefault("AUTH_REQUIRED", "0")
# Deterministic test-only Fernet key so credential paths use real encryption.
os.environ.setdefault(
    "PULSEDESK_ENCRYPTION_KEY", "b2BPUaboInk_FQ-v5cTmO0SJ0uH9jXeMzfGzpsCzM18="
)

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from sqlalchemy.ext.compiler import compiles
from sqlalchemy.dialects.postgresql import JSONB


@compiles(JSONB, "sqlite")
def _compile_jsonb_sqlite(type_, compiler, **kw):
    """Render PostgreSQL JSONB as plain JSON for SQLite test engine."""
    return "JSON"


BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

from app.main import app as fastapi_app
from app.database import get_db
from app.database.base import Base

import app.models.strategy  # noqa: F401
import app.models.user  # noqa: F401
import app.models.tenant  # noqa: F401
import app.models.agent_signal  # noqa: F401
import app.models.ai_provider  # noqa: F401
import app.models.ai  # noqa: F401
import app.models.research  # noqa: F401
import app.domain.ledger  # noqa: F401
import app.domain.command  # noqa: F401
import app.models.dryrun  # noqa: F401
import app.domain.strategy  # noqa: F401
import app.models.research_v2  # noqa: F401
import app.models.provider_config  # noqa: F401
import app.domain.provider  # noqa: F401
import app.domain.risk  # noqa: F401
import app.domain.execution  # noqa: F401
import app.domain.order  # noqa: F401
import app.domain.growth  # noqa: F401
import app.domain.manipulation  # noqa: F401
import app.domain.inference  # noqa: F401
import app.domain.mcp  # noqa: F401
import app.domain.reconciliation  # noqa: F401
import app.domain.archive  # noqa: F401


@pytest.fixture(scope="session")
def test_engine():
    if TEST_DATABASE_URL:
        engine = create_engine(TEST_DATABASE_URL, pool_pre_ping=True)
        # SQLite tests do not enforce FKs; keep PostgreSQL parity for the suite.
        # Foreign-key correctness is covered by real API/integration flows.
        @event.listens_for(engine, "connect")
        def _disable_fk_checks(dbapi_connection, connection_record):
            cursor = dbapi_connection.cursor()
            cursor.execute("SET session_replication_role = replica")
            dbapi_connection.commit()
            cursor.close()

        Base.metadata.drop_all(engine)
        Base.metadata.create_all(engine)
    else:
        engine = create_engine(
            "sqlite://",
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
    yield engine
    engine.dispose()


def _is_integration_test(request):
    """Check if the test is in the integration directory."""
    return '/integration/' in str(request.fspath)

@pytest.fixture(autouse=True)
def setup_db(test_engine, request):
    if _is_integration_test(request):
        yield
        return
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture(autouse=True)
def _disable_rate_limiting():
    from app.services.account_risk_firewall import AccountRiskFirewall

    stack = getattr(fastapi_app, "middleware_stack", None)
    if stack is not None:
        _walk_and_clear(stack)
    AccountRiskFirewall.deactivate_manual_block()
    yield
    AccountRiskFirewall.deactivate_manual_block()


def _walk_and_clear(node):
    from app.middleware.rate_limiter import RateLimitMiddleware
    if isinstance(node, RateLimitMiddleware):
        node.requests.clear()
        return
    inner = getattr(node, "app", None)
    if inner:
        _walk_and_clear(inner)


@pytest.fixture
def session(test_engine):
    TestSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(autouse=True)
def _patch_init_db(monkeypatch, test_engine, request):
    """Prevent lifespan init_db from connecting to real Postgres."""
    if _is_integration_test(request):
        return
    monkeypatch.setattr('app.database.engine', test_engine)
    monkeypatch.setattr('app.database.init_db', lambda: Base.metadata.create_all(bind=test_engine))
    # Also patch SessionLocal so get_db uses the test engine
    from sqlalchemy.orm import sessionmaker as _sm
    monkeypatch.setattr('app.database.SessionLocal', _sm(autocommit=False, autoflush=False, bind=test_engine))


@pytest.fixture(autouse=True)
def _disable_db_schedulers(monkeypatch):
    """Keep maintenance schedulers from touching the test DB during HTTP tests."""
    from app.config import settings

    monkeypatch.setattr(settings, "tenant_audit_cleanup_interval_hours", 0)
    monkeypatch.setattr(settings, "tenant_quota_warn_interval_hours", 0)
    monkeypatch.setattr(settings, "subscription_expiry_interval_hours", 0)


@pytest.fixture
def client(test_engine, monkeypatch):
    # Background loops make HTTP tests nondeterministic: the worker loop can
    # steal a command before the test polls it. Disable them for this fixture.
    import asyncio

    from app.workers.trade_sync_loop import TradeSyncLoop
    from app.workers.worker_loop import CommandWorkerLoop

    async def _noop_start(self):
        return None

    async def _noop_ticker():
        await asyncio.sleep(3600)

    monkeypatch.setattr(CommandWorkerLoop, "start", _noop_start)
    monkeypatch.setattr(TradeSyncLoop, "start", _noop_start)
    monkeypatch.setattr("app.main.run_binance_ticker_stream", _noop_ticker)

    TestSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

    def override_get_db():
        db = TestSession()
        try:
            yield db
        finally:
            db.close()

    fastapi_app.dependency_overrides[get_db] = override_get_db
    with TestClient(fastapi_app, raise_server_exceptions=False) as c:
        yield c
    fastapi_app.dependency_overrides.clear()

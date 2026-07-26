import os
import sys

# Set SQLite as default DATABASE_URL for tests BEFORE any app imports.
# Integration tests can override this with their own file-based SQLite.
os.environ.setdefault("DATABASE_URL", "sqlite://")
os.environ.setdefault("PROVIDER_HEALTH_INTERVAL_S", "0")

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
    stack = getattr(fastapi_app, "middleware_stack", None)
    if stack is not None:
        _walk_and_clear(stack)


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


@pytest.fixture
def client(test_engine):
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

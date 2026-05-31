import os
import sys
import tempfile

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

BACKEND_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if BACKEND_ROOT not in sys.path:
    sys.path.insert(0, BACKEND_ROOT)

from app.main import app
from app.database import Base, get_db


@pytest.fixture(scope="session")
def test_engine():
    db_fd, db_path = tempfile.mkstemp(suffix=".db")
    os.close(db_fd)
    engine = create_engine(f"sqlite:///{db_path}", connect_args={"check_same_thread": False})
    yield engine
    engine.dispose()
    if os.path.exists(db_path):
        os.unlink(db_path)


@pytest.fixture(autouse=True)
def setup_db(test_engine):
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)


@pytest.fixture(autouse=True)
def _disable_rate_limiting():
    """Clear rate limiter state before each test to avoid 429s."""
    # Walk the middleware stack to find RateLimitMiddleware instances and clear their state
    _clear_rate_limits()
    yield
    _clear_rate_limits()


def _clear_rate_limits():
    """Find all RateLimitMiddleware instances and clear their request tracking dicts."""
    from app.middleware.rate_limiter import RateLimitMiddleware
    # The middleware stack is built lazily; access it to force construction
    stack = app.middleware_stack
    _walk_and_clear(stack, RateLimitMiddleware)


def _walk_and_clear(node, cls):
    """Recursively walk ASGI middleware chain and clear rate limiter state."""
    if isinstance(node, cls):
        node.requests.clear()
        return
    # BaseHTTPMiddleware wraps an inner 'app'
    inner = getattr(node, 'app', None)
    if inner:
        _walk_and_clear(inner, cls)


@pytest.fixture
def session(test_engine):
    TestSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture
def client(test_engine):
    TestSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

    def override_get_db():
        db = TestSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()

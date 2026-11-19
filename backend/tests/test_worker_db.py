"""Worker sessions can use a dedicated BYPASSRLS role."""
from app.database import _BASE_ENGINE, WorkerSessionLocal


def test_worker_session_falls_back_to_main_engine():
    # conftest rebinds app.database.engine/SessionLocal per test, so compare
    # against the import-time engine captured in _BASE_ENGINE.
    assert WorkerSessionLocal.kw["bind"] is _BASE_ENGINE

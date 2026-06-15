"""Tests for Dashboard BFF — OverviewAggregatorService."""
import pytest
from httpx import AsyncClient, ASGITransport

# Fix SQLite ↔ JSONB compatibility (pre-existing project issue)
from sqlalchemy.dialects.sqlite.base import SQLiteTypeCompiler
if not hasattr(SQLiteTypeCompiler, "visit_JSONB"):
    SQLiteTypeCompiler.visit_JSONB = lambda self, type_, **kw: self.visit_JSON(type_, **kw)

from app.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c


class TestDashboardBFF:
    @pytest.mark.anyio
    async def test_returns_200(self, client):
        r = await client.get("/api/overview/dashboard")
        assert r.status_code == 200

    @pytest.mark.anyio
    async def test_has_all_sections(self, client):
        data = (await client.get("/api/overview/dashboard")).json()
        for key in ("state", "reason_codes", "available_actions",
                    "account", "runtime", "risk", "system",
                    "recent_decisions", "alerts"):
            assert key in data, f"Missing key: {key}"

    @pytest.mark.anyio
    async def test_account_has_sharpe(self, client):
        data = (await client.get("/api/overview/dashboard")).json()
        assert "sharpe_ratio" in data["account"]

    @pytest.mark.anyio
    async def test_alerts_have_time(self, client):
        data = (await client.get("/api/overview/dashboard")).json()
        if data["alerts"]:
            assert "time" in data["alerts"][0]

    @pytest.mark.anyio
    async def test_state_is_valid(self, client):
        data = (await client.get("/api/overview/dashboard")).json()
        assert data["state"] in ("healthy", "warning", "blocked", "locked", "unknown")

    @pytest.mark.anyio
    async def test_reason_codes_is_list(self, client):
        data = (await client.get("/api/overview/dashboard")).json()
        assert isinstance(data["reason_codes"], list)

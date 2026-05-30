import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app


@pytest.mark.asyncio
async def test_get_dependencies_returns_200():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/system/dependencies")
    assert resp.status_code == 200
    data = resp.json()
    assert "required" in data
    assert "core_optional" in data
    assert "ml_models" in data
    assert "external_services" in data
    assert "readiness_score" in data


@pytest.mark.asyncio
async def test_readiness_score_is_float():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        resp = await client.get("/api/system/dependencies")
    data = resp.json()
    assert isinstance(data["readiness_score"], float)
    assert 0.0 <= data["readiness_score"] <= 1.0

import pytest
import json
from httpx import AsyncClient, ASGITransport
from sqlalchemy.orm import sessionmaker

from app.main import app
from app.database import get_db


@pytest.fixture
def anyio_backend():
    return "asyncio"


@pytest.fixture
async def client(test_engine):
    TestSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

    def override_get_db():
        db = TestSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


@pytest.mark.anyio
async def test_canvas_save_and_load(client):
    # Create a strategy first
    create_resp = await client.post("/api/strategies", json={
        "name": "Test Canvas Strategy",
        "type": "grid",
        "market": "crypto",
        "exchange": "binance",
        "parameters": {}
    })
    assert create_resp.status_code == 201
    strategy_id = create_resp.json()["id"]

    # Save canvas
    graph_json = '{"nodes":[{"id":"test-1","nodeType":"indicator.rsi","position":{"x":100,"y":100},"size":{"width":200,"height":120},"config":{},"widgetValues":{},"isCollapsed":false,"isDisabled":false}],"edges":[],"groups":[],"viewport":{"scale":1.0,"offset":{"x":0,"y":0}}}'
    save_resp = await client.post(f"/api/strategies/{strategy_id}/canvas", json={
        "graph_json": graph_json,
        "code_snapshot": "# test code"
    })
    assert save_resp.status_code == 201

    # Load canvas
    load_resp = await client.get(f"/api/strategies/{strategy_id}/canvas")
    assert load_resp.status_code == 200
    assert load_resp.json()["graph_json"] == graph_json

    # Clean up
    await client.delete(f"/api/strategies/{strategy_id}")


@pytest.mark.anyio
async def test_canvas_update(client):
    create_resp = await client.post("/api/strategies", json={
        "name": "Test Canvas Update",
        "type": "grid",
        "market": "crypto",
        "exchange": "binance",
        "parameters": {}
    })
    assert create_resp.status_code == 201
    strategy_id = create_resp.json()["id"]

    # Save initial
    await client.post(f"/api/strategies/{strategy_id}/canvas", json={
        "graph_json": "{}",
        "code_snapshot": ""
    })

    # Update
    update_resp = await client.put(f"/api/strategies/{strategy_id}/canvas", json={
        "graph_json": '{"nodes":[{"id":"updated","nodeType":"data.kline"}]}',
        "code_snapshot": "# updated"
    })
    assert update_resp.status_code == 200

    # Verify update
    load_resp = await client.get(f"/api/strategies/{strategy_id}/canvas")
    assert "data.kline" in load_resp.json()["graph_json"]

    await client.delete(f"/api/strategies/{strategy_id}")


@pytest.mark.anyio
async def test_canvas_large_graph_roundtrip(client):
    create_resp = await client.post("/api/strategies", json={
        "name": "Large Canvas Test",
        "type": "grid",
        "market": "crypto",
        "exchange": "binance",
        "parameters": {}
    })
    assert create_resp.status_code == 201
    strategy_id = create_resp.json()["id"]

    # Build 200 nodes
    nodes = []
    for i in range(200):
        nodes.append({
            "id": f"node-{i}",
            "nodeType": "indicator.rsi",
            "position": {"x": i * 150 % 5000, "y": i * 100 % 3000},
            "size": {"width": 200, "height": 120},
            "config": {"period": 14},
            "widgetValues": {},
            "isCollapsed": False,
            "isDisabled": False
        })

    large_graph = json.dumps({
        "nodes": nodes,
        "edges": [],
        "groups": [],
        "viewport": {"scale": 1.0, "offset": {"x": 0, "y": 0}}
    })

    save_resp = await client.post(f"/api/strategies/{strategy_id}/canvas", json={
        "graph_json": large_graph,
        "code_snapshot": ""
    })
    assert save_resp.status_code == 201

    # Load and verify
    load_resp = await client.get(f"/api/strategies/{strategy_id}/canvas")
    assert load_resp.status_code == 200
    loaded = json.loads(load_resp.json()["graph_json"])
    assert len(loaded["nodes"]) == 200

    await client.delete(f"/api/strategies/{strategy_id}")

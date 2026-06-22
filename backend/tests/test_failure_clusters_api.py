import uuid
from unittest.mock import patch
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_failure_clusters_accepts_strategy_uuid():
    u = uuid.uuid4()
    with patch("app.services.failure_clustering.load_clusters", return_value=[]):
        resp = client.get(f"/api/growth/failure-clusters?strategy_uuid={u}")
    assert resp.status_code == 200
    data = resp.json()
    assert "clusters" in data


def test_failure_clusters_strategy_uuid_passes_through():
    u = uuid.uuid4()
    captured = {}
    def fake_load(db, strategy_id=None, status="active"):
        captured["strategy_id"] = strategy_id
        return []
    with patch("app.services.failure_clustering.load_clusters", side_effect=fake_load):
        client.get(f"/api/growth/failure-clusters?strategy_uuid={u}")
    assert str(captured["strategy_id"]) == str(u)

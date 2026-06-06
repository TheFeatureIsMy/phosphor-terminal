"""Tests for Inference API."""
import uuid


class TestCreateJob:
    def test_create_returns_201(self, client):
        resp = client.post("/api/inference/jobs", json={
            "job_type": "sentiment",
            "model_name": "finbert",
            "input_payload": {"text": "Bitcoin is bullish"},
        })
        assert resp.status_code == 201
        data = resp.json()
        assert data["status"] == "queued"
        assert data["model_name"] == "finbert"
        assert data["job_type"] == "sentiment"
        assert "id" in data

    def test_create_with_timeout(self, client):
        resp = client.post("/api/inference/jobs", json={
            "job_type": "forecast",
            "model_name": "chronos",
            "input_payload": {"symbol": "BTC/USDT"},
            "timeout_sec": 600,
        })
        assert resp.status_code == 201
        data = resp.json()
        assert data["status"] == "queued"


class TestListJobs:
    def test_list_empty(self, client):
        resp = client.get("/api/inference/jobs")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_filter_by_status(self, client):
        client.post("/api/inference/jobs", json={
            "job_type": "forecast",
            "model_name": "chronos",
            "input_payload": {"symbol": "BTC/USDT"},
        })
        resp = client.get("/api/inference/jobs?status=queued")
        assert resp.status_code == 200
        data = resp.json()
        assert all(j["status"] == "queued" for j in data)

    def test_filter_by_model_name(self, client):
        client.post("/api/inference/jobs", json={
            "job_type": "sentiment",
            "model_name": "finbert",
            "input_payload": {"text": "test"},
        })
        resp = client.get("/api/inference/jobs?model_name=finbert")
        assert resp.status_code == 200
        data = resp.json()
        assert all(j["model_name"] == "finbert" for j in data)


class TestGetJob:
    def test_not_found(self, client):
        resp = client.get(f"/api/inference/jobs/{uuid.uuid4()}")
        assert resp.status_code == 404

    def test_get_created_job(self, client):
        create_resp = client.post("/api/inference/jobs", json={
            "job_type": "research",
            "model_name": "gpt-4",
            "input_payload": {"prompt": "analyze BTC"},
        })
        job_id = create_resp.json()["id"]
        resp = client.get(f"/api/inference/jobs/{job_id}")
        assert resp.status_code == 200
        assert resp.json()["id"] == job_id


class TestCancelJob:
    def test_cancel_queued_job(self, client):
        r = client.post("/api/inference/jobs", json={
            "job_type": "research",
            "model_name": "gpt-4",
            "input_payload": {"prompt": "analyze BTC"},
        })
        job_id = r.json()["id"]
        r2 = client.post(f"/api/inference/jobs/{job_id}/cancel")
        assert r2.status_code == 200
        assert r2.json()["status"] == "cancelled"

    def test_cancel_nonexistent_job(self, client):
        r = client.post(f"/api/inference/jobs/{uuid.uuid4()}/cancel")
        assert r.status_code == 409

    def test_cancel_already_cancelled(self, client):
        r = client.post("/api/inference/jobs", json={
            "job_type": "research",
            "model_name": "gpt-4",
            "input_payload": {"prompt": "analyze BTC"},
        })
        job_id = r.json()["id"]
        # Cancel once
        client.post(f"/api/inference/jobs/{job_id}/cancel")
        # Cancel again should fail
        r2 = client.post(f"/api/inference/jobs/{job_id}/cancel")
        assert r2.status_code == 409


class TestRuntimeState:
    def test_get_empty(self, client):
        resp = client.get("/api/inference/runtime-state")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

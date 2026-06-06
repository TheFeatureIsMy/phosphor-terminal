"""Tests for Admin API."""


class TestDataVacuum:
    def test_run_vacuum(self, client):
        resp = client.post("/api/admin/data-vacuum/run")
        assert resp.status_code == 202
        data = resp.json()
        assert data["status"] == "pending"
        assert "job_id" in data

    def test_list_jobs(self, client):
        resp = client.get("/api/admin/data-vacuum/jobs")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_list_jobs_after_creation(self, client):
        # Create a vacuum job first
        client.post("/api/admin/data-vacuum/run")
        resp = client.get("/api/admin/data-vacuum/jobs")
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) >= 1
        assert data[0]["status"] == "pending"

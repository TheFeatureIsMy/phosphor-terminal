"""Tests for AI provider management endpoints: /api/ai/models, /api/ai/usage."""

import pytest
from unittest.mock import patch


# ── GET /api/ai/models/status ─────────────────────────────────────────────────


class TestModelsStatus:
    def test_models_status_returns_dict(self, client):
        """Endpoint works regardless of whether ML models are installed."""
        resp = client.get("/api/ai/models/status")
        assert resp.status_code == 200
        body = resp.json()
        assert "models" in body
        assert isinstance(body["models"], dict)

    def test_models_status_has_finbert_key(self, client):
        resp = client.get("/api/ai/models/status")
        body = resp.json()
        # finbert key should be present (loaded or errored)
        assert "finbert" in body["models"]


# ── POST /api/ai/models/preload ───────────────────────────────────────────────


class TestPreloadModels:
    def test_preload_returns_triggered(self, client):
        resp = client.post("/api/ai/models/preload")
        assert resp.status_code == 200
        body = resp.json()
        assert body["status"] == "preload_triggered"
        assert "results" in body
        assert isinstance(body["results"], list)
        assert len(body["results"]) == 2


# ── GET /api/ai/usage ─────────────────────────────────────────────────────────


class TestUsageStats:
    def test_usage_returns_stats_structure(self, client):
        resp = client.get("/api/ai/usage")
        assert resp.status_code == 200
        body = resp.json()
        assert "in_memory" in body
        assert "persisted" in body
        assert "recent" in body
        assert body["in_memory"]["total_calls"] == 0
        # persisted stats from DB (empty DB = 0)
        assert body["persisted"]["total_calls"] == 0
        assert body["persisted"]["total_tokens"] == 0

"""Tests for AI provider management endpoints: /api/ai/providers, /api/ai/models, /api/ai/usage."""

import pytest
from unittest.mock import patch, AsyncMock, MagicMock

from app.services.llm_service import LLMService, OllamaProvider, OpenAIProvider, LLMResponse


# ── Helpers ───────────────────────────────────────────────────────────────────


def _make_mock_llm_service():
    """Create a mock LLMService with one fake Ollama provider."""
    svc = LLMService()
    provider = MagicMock(spec=OllamaProvider)
    provider.name = "ollama"
    provider.model_id = "qwen2.5:7b"
    provider._base_url = "http://localhost:11434"
    provider.health_check = AsyncMock(return_value=True)
    svc.providers = [provider]
    return svc


# ── GET /api/ai/providers ─────────────────────────────────────────────────────


class TestListProviders:
    @patch("app.routers.ai_providers._get_llm_service")
    def test_list_providers_returns_list(self, mock_get_svc, client):
        svc = _make_mock_llm_service()
        mock_get_svc.return_value = svc

        resp = client.get("/api/ai/providers")
        assert resp.status_code == 200
        body = resp.json()
        assert "providers" in body
        assert len(body["providers"]) == 1
        p = body["providers"][0]
        assert p["provider"] == "ollama"
        assert p["model"] == "qwen2.5:7b"
        assert p["available"] is True
        assert "base_url" in p

    @patch("app.routers.ai_providers._get_llm_service")
    def test_list_providers_empty(self, mock_get_svc, client):
        svc = LLMService()
        svc.providers = []
        mock_get_svc.return_value = svc

        resp = client.get("/api/ai/providers")
        assert resp.status_code == 200
        assert resp.json()["providers"] == []


# ── POST /api/ai/providers/test ───────────────────────────────────────────────


class TestProviderTest:
    def test_test_ollama_provider_available(self, client):
        """Ollama test with mocked health_check on the class to avoid network calls."""
        with patch.object(OllamaProvider, "health_check", new_callable=AsyncMock, return_value=True), \
             patch.object(OllamaProvider, "list_models", new_callable=AsyncMock, return_value=["qwen2.5:7b", "llama3:8b"]):
            resp = client.post(
                "/api/ai/providers/test",
                json={"provider": "ollama"},
            )
        assert resp.status_code == 200
        body = resp.json()
        assert body["provider"] == "ollama"
        assert body["available"] is True
        assert body["model"] == "qwen2.5:7b"
        assert "server_models" in body

    def test_test_ollama_provider_unavailable(self, client):
        with patch.object(OllamaProvider, "health_check", new_callable=AsyncMock, return_value=False):
            resp = client.post(
                "/api/ai/providers/test",
                json={"provider": "ollama"},
            )
        assert resp.status_code == 200
        body = resp.json()
        assert body["available"] is False
        assert "server_models" not in body

    def test_test_openai_no_api_key(self, client):
        resp = client.post(
            "/api/ai/providers/test",
            json={"provider": "openai"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["available"] is False
        assert "api_key required" in body["error"]

    def test_test_anthropic_no_api_key(self, client):
        resp = client.post(
            "/api/ai/providers/test",
            json={"provider": "anthropic"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["available"] is False
        assert "api_key required" in body["error"]

    def test_test_unknown_provider(self, client):
        resp = client.post(
            "/api/ai/providers/test",
            json={"provider": "unknown_llm"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["available"] is False
        assert "Unknown provider" in body["error"]

    def test_test_openai_with_key(self, client):
        with patch.object(OpenAIProvider, "health_check", new_callable=AsyncMock, return_value=True):
            resp = client.post(
                "/api/ai/providers/test",
                json={"provider": "openai", "api_key": "sk-test"},
            )
        assert resp.status_code == 200
        body = resp.json()
        assert body["provider"] == "openai"
        assert body["available"] is True

    def test_test_provider_health_check_exception(self, client):
        with patch.object(OllamaProvider, "health_check", new_callable=AsyncMock, side_effect=ConnectionError("refused")):
            resp = client.post(
                "/api/ai/providers/test",
                json={"provider": "ollama"},
            )
        assert resp.status_code == 200
        body = resp.json()
        assert body["available"] is False
        assert "refused" in body["error"]


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
    @patch("app.routers.ai_providers._get_llm_service")
    def test_usage_returns_stats_structure(self, mock_get_svc, client):
        svc = _make_mock_llm_service()
        mock_get_svc.return_value = svc

        resp = client.get("/api/ai/usage")
        assert resp.status_code == 200
        body = resp.json()
        assert "in_memory" in body
        assert "persisted" in body
        assert "recent" in body
        # in_memory stats from the LLM service
        assert body["in_memory"]["total_calls"] == 0
        # persisted stats from DB
        assert body["persisted"]["total_calls"] == 0
        assert body["persisted"]["total_tokens"] == 0

    @patch("app.routers.ai_providers._get_llm_service")
    def test_usage_with_in_memory_log(self, mock_get_svc, client):
        svc = _make_mock_llm_service()
        # Simulate a logged call
        svc._usage_log.append({
            "provider": "ollama",
            "model": "qwen2.5:7b",
            "tokens_used": 150,
            "latency_ms": 320.5,
        })
        mock_get_svc.return_value = svc

        resp = client.get("/api/ai/usage")
        body = resp.json()
        assert body["in_memory"]["total_calls"] == 1
        assert body["in_memory"]["total_tokens"] == 150

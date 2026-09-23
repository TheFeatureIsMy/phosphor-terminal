"""Smoke tests for the /api/ai-risk-cache router (PRD §9.1)."""


class TestAIRiskCacheRouter:
    def test_empty_cache_returns_unavailable_state(self, client, session):
        # No Redis in tests → in-memory fallback store has no cache entry
        r = client.get("/api/ai-risk-cache", params={"symbol": "BTC/USDT"})
        assert r.status_code == 200
        body = r.json()
        assert body["state"] == "data_source_unavailable"
        assert "ai_cache_empty" in body["reason_codes"]
        assert body["cache"] is None
        actions = [a["type"] for a in body["available_actions"]]
        assert "generate_cache" in actions

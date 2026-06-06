"""Tests for RAG endpoints: /rag/upload, /rag/search, /rag/generate, /rag/knowledge.
Also tests for RAG service LLM integration (generate_strategy with LLM vs template fallback).
"""

from __future__ import annotations

import io
import json
import pytest
from typing import Optional
from unittest.mock import patch, AsyncMock, MagicMock


def _make_text_file(content: str, filename: str = "strategy_doc.txt"):
    """Helper to create a file-like object for upload testing."""
    return (filename, io.BytesIO(content.encode("utf-8")), "text/plain")


# ── POST /rag/upload ──────────────────────────────────────────────────────────


class TestUploadDocument:
    def test_upload_creates_document_and_chunks(self, client):
        content = (
            "This is a strategy line about trading signals and indicators for risk management.\n"
            "Another strategy line about position sizing and signal confirmation.\n"
            "Short\n"
            "A third strategy line about risk management in trading systems.\n"
        )
        resp = client.post(
            "/rag/upload",
            files={"file": _make_text_file(content)},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["persisted"] is True
        assert body["chunks_created"] >= 1
        assert "duplicate" not in body  # first upload has no duplicate key

    def test_upload_duplicate_file_returns_existing(self, client):
        content = "This is a strategy document about trading signals and risk indicators.\n"
        resp1 = client.post("/rag/upload", files={"file": _make_text_file(content)})
        resp2 = client.post("/rag/upload", files={"file": _make_text_file(content)})
        assert resp2.status_code == 200
        assert resp2.json()["duplicate"] is True
        assert resp2.json()["doc_id"] == resp1.json()["doc_id"]

    def test_upload_no_filename_rejected(self, client):
        resp = client.post(
            "/rag/upload",
            files={"file": ("", io.BytesIO(b"content"), "text/plain")},
        )
        assert resp.status_code in (400, 422)  # FastAPI rejects empty filename


# ── POST /rag/search ──────────────────────────────────────────────────────────


class TestSearch:
    def _seed_document(self, client):
        content = (
            "This is a strategy document about trading signals and indicators for crypto.\n"
            "Another strategy line about position sizing and signal confirmation.\n"
            "A third line about risk management in trading systems and indicators.\n"
        )
        client.post("/rag/upload", files={"file": _make_text_file(content)})

    def test_search_returns_relevant_chunks(self, client):
        self._seed_document(client)
        resp = client.post("/rag/search", json={"query": "strategy trading signals", "top_k": 5})
        assert resp.status_code == 200
        body = resp.json()
        assert "results" in body
        assert body["total"] >= 1
        for result in body["results"]:
            assert "relevance" in result
            assert "content" in result
            assert "doc_id" in result
            assert result["persisted"] is True

    def test_search_no_results_for_unrelated_query(self, client):
        self._seed_document(client)
        resp = client.post("/rag/search", json={"query": "zzzzzzzz nonexistent", "top_k": 5})
        assert resp.status_code == 200
        assert resp.json()["total"] == 0

    def test_search_respects_top_k(self, client):
        self._seed_document(client)
        resp = client.post("/rag/search", json={"query": "strategy trading", "top_k": 1})
        assert resp.status_code == 200
        assert len(resp.json()["results"]) <= 1


# ── POST /rag/generate ─────────────────────────────────────────────────────────


class TestGenerate:
    def test_generate_returns_strategy(self, client):
        resp = client.post(
            "/rag/generate",
            json={"prompt": "Create a momentum strategy for crypto", "risk_level": "low", "market": "crypto"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert "id" in body
        assert "strategy" in body
        assert "code" in body
        assert "safety_status" in body
        assert "explanation" in body
        assert body["strategy"]["name"]
        assert "IStrategy" in body["code"] or "def " in body["code"]

    def test_generate_with_knowledge_context(self, client):
        # Seed some knowledge first
        content = (
            "This is a strategy document about trading signals and indicators.\n"
            "A line about risk management and position sizing in trading.\n"
            "Another strategy line about signal confirmation and risk control.\n"
        )
        client.post("/rag/upload", files={"file": _make_text_file(content)})

        resp = client.post(
            "/rag/generate",
            json={"prompt": "strategy trading signals", "risk_level": "medium", "market": "crypto"},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["context_used"] is not None

    def test_generate_empty_prompt_rejected(self, client):
        resp = client.post("/rag/generate", json={"prompt": "   "})
        assert resp.status_code == 400


# ── GET /rag/knowledge ─────────────────────────────────────────────────────────


class TestKnowledge:
    def test_knowledge_empty_when_no_docs(self, client):
        resp = client.get("/rag/knowledge")
        assert resp.status_code == 200
        assert resp.json()["documents"] == []

    def test_knowledge_lists_uploaded_documents(self, client):
        content1 = (
            "This is a strategy document about trading signals and indicators.\n"
            "A line about risk management and position sizing in trading.\n"
        )
        content2 = (
            "Another strategy guide about breakout patterns and signal confirmation.\n"
            "A paragraph about position sizing for crypto risk management.\n"
        )
        client.post("/rag/upload", files={"file": _make_text_file(content1, "doc1.txt")})
        client.post("/rag/upload", files={"file": _make_text_file(content2, "doc2.txt")})
        resp = client.get("/rag/knowledge")
        assert resp.status_code == 200
        docs = resp.json()["documents"]
        assert len(docs) == 2
        filenames = {d["filename"] for d in docs}
        assert "doc1.txt" in filenames
        assert "doc2.txt" in filenames
        for doc in docs:
            assert doc["persisted"] is True
            assert doc["chunks"] >= 1


# ── RAG Service LLM Integration Tests ─────────────────────────────────────────


class TestGenerateStrategyLLMIntegration:
    """Test generate_strategy() LLM-first with template fallback."""

    def _make_mock_llm(self, response_content: str | None = None, raise_error: bool = False):
        """Create a mock LLM service that optionally raises on chat()."""
        from app.services.llm_service import LLMService, LLMResponse

        svc = LLMService()
        provider = MagicMock()
        provider.name = "ollama"
        provider.model_id = "qwen2.5:7b"
        provider.health_check = AsyncMock(return_value=True)

        if raise_error:
            provider.chat = AsyncMock(side_effect=RuntimeError("LLM unavailable"))
        else:
            content = response_content or json.dumps({
                "name": "LLM动量策略",
                "type": "ma_cross",
                "parameters": {"fast_period": 12, "slow_period": 26},
                "explanation": "LLM generated momentum strategy.",
            })
            provider.chat = AsyncMock(return_value=LLMResponse(
                content=content,
                model="qwen2.5:7b",
                provider="ollama",
                tokens_used=200,
                latency_ms=450.0,
            ))

        svc.providers = [provider]
        return svc

    def test_llm_available_returns_llm_generated_source(self):
        """When LLM is available and returns valid JSON, source should be llm_generated."""
        from app.services.rag_service import generate_strategy, _reset_llm_service

        mock_svc = self._make_mock_llm()

        with patch("app.services.rag_service._get_llm_service", return_value=mock_svc):
            import asyncio
            result = asyncio.run(
                generate_strategy("momentum strategy for crypto", "medium", "crypto")
            )

        assert result["strategy"]["source"] == "llm_generated"
        assert result["strategy"]["name"] == "LLM动量策略"
        assert result["strategy"]["model"] == "qwen2.5:7b"
        assert result["strategy"]["provider"] == "ollama"
        assert "IStrategy" in result["code"]

    def test_llm_unavailable_falls_back_to_template(self):
        """When _get_llm_service returns None, source should be rag_generated."""
        from app.services.rag_service import generate_strategy

        with patch("app.services.rag_service._get_llm_service", return_value=None):
            import asyncio
            result = asyncio.run(
                generate_strategy("a simple moving average strategy", "low", "crypto")
            )

        assert result["strategy"]["source"] == "rag_generated"
        assert result["strategy"]["name"]  # template provides a name
        assert "IStrategy" in result["code"]
        assert "model" not in result["strategy"]

    def test_llm_error_falls_back_to_template(self):
        """When LLM chat() raises, generate_strategy should fall back to template."""
        from app.services.rag_service import generate_strategy

        mock_svc = self._make_mock_llm(raise_error=True)

        with patch("app.services.rag_service._get_llm_service", return_value=mock_svc):
            import asyncio
            result = asyncio.run(
                generate_strategy("breakout strategy", "high", "crypto")
            )

        assert result["strategy"]["source"] == "rag_generated"
        assert result["strategy"]["type"]  # template still provides a type

    def test_template_selects_breakout_on_keyword(self):
        """Template fallback should select breakout template when 'break' is in prompt."""
        from app.services.rag_service import generate_strategy

        with patch("app.services.rag_service._get_llm_service", return_value=None):
            import asyncio
            result = asyncio.run(
                generate_strategy("breakout above resistance", "medium", "crypto")
            )

        assert result["strategy"]["source"] == "rag_generated"
        assert result["strategy"]["type"] == "breakout"

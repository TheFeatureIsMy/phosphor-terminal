"""AI provider management and ML model status endpoints."""
from __future__ import annotations

import asyncio
from typing import Any, Optional

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.ai_provider import AIProviderConfig, AIUsageLog
from app.services.llm_service import (
    AnthropicProvider,
    LLMService,
    OllamaProvider,
    OpenAIProvider,
    create_llm_service_from_env,
)

router = APIRouter(prefix="/api/ai", tags=["ai-providers"])

# Module-level singleton (created once on first request)
_llm_service: LLMService | None = None


def _get_llm_service() -> LLMService:
    global _llm_service
    if _llm_service is None:
        _llm_service = create_llm_service_from_env()
    return _llm_service


# ── Request / Response models ─────────────────────────────────────────


class ProviderConfigRequest(BaseModel):
    provider: str  # openai, anthropic, ollama
    api_key: Optional[str] = None
    base_url: Optional[str] = None
    model: str = "gpt-4o"
    is_active: bool = True
    priority: int = 0


class ProviderTestRequest(BaseModel):
    provider: str  # openai, anthropic, ollama
    api_key: Optional[str] = None
    base_url: Optional[str] = None
    model: Optional[str] = None


# ── Endpoints ─────────────────────────────────────────────────────────


@router.get("/providers")
async def list_providers():
    """List all configured LLM providers and their availability."""
    svc = _get_llm_service()
    providers = await svc.list_available()
    # Enrich with base_url info from the service internals
    enriched: list[dict[str, Any]] = []
    for p, info in zip(svc.providers, providers):
        base_url = ""
        if isinstance(p, OpenAIProvider):
            base_url = p._base_url
        elif isinstance(p, OllamaProvider):
            base_url = p._base_url
        elif isinstance(p, AnthropicProvider):
            base_url = "https://api.anthropic.com"
        info["base_url"] = base_url
        enriched.append(info)
    return {"providers": enriched}


@router.post("/providers/config")
def update_provider_config(body: ProviderConfigRequest, db: Session = Depends(get_db)):
    """Create or update an AI provider configuration."""
    existing = (
        db.query(AIProviderConfig)
        .filter(AIProviderConfig.provider == body.provider)
        .first()
    )
    if existing:
        existing.model = body.model
        existing.base_url = body.base_url
        existing.is_active = body.is_active
        existing.priority = body.priority
        if body.api_key:
            existing.api_key_encrypted = body.api_key  # TODO: real encryption
        db.commit()
        db.refresh(existing)
        return {"status": "updated", "id": existing.id}

    config = AIProviderConfig(
        provider=body.provider,
        api_key_encrypted=body.api_key,
        base_url=body.base_url,
        model=body.model,
        is_active=body.is_active,
        priority=body.priority,
    )
    db.add(config)
    db.commit()
    db.refresh(config)
    return {"status": "created", "id": config.id}


@router.post("/providers/test")
async def test_provider(body: ProviderTestRequest):
    """Test connectivity for a specific LLM provider."""
    provider_name = body.provider.lower()

    if provider_name == "openai":
        if not body.api_key:
            return {"provider": provider_name, "available": False, "error": "api_key required"}
        provider = OpenAIProvider(
            api_key=body.api_key,
            model=body.model or "gpt-4o",
            base_url=body.base_url or "https://api.openai.com/v1",
        )
    elif provider_name == "anthropic":
        if not body.api_key:
            return {"provider": provider_name, "available": False, "error": "api_key required"}
        provider = AnthropicProvider(
            api_key=body.api_key,
            model=body.model or "claude-sonnet-4-20250514",
        )
    elif provider_name == "ollama":
        provider = OllamaProvider(
            base_url=body.base_url or "http://localhost:11434",
            model=body.model or "qwen2.5:7b",
        )
    else:
        return {"provider": provider_name, "available": False, "error": f"Unknown provider: {provider_name}"}

    try:
        available = await provider.health_check()
    except Exception as exc:
        return {"provider": provider_name, "available": False, "error": str(exc)}

    result: dict[str, Any] = {
        "provider": provider_name,
        "model": provider.model_id,
        "available": available,
    }

    # For Ollama, also list available models on the server
    if available and isinstance(provider, OllamaProvider):
        try:
            result["server_models"] = await provider.list_models()
        except Exception:
            pass

    return result


@router.get("/models/status")
async def models_status():
    """Check which ML models are loaded / available."""
    statuses: dict[str, Any] = {}

    # FinBERT
    try:
        from app.services.sentiment_finbert import FinBERTAdapter

        finbert = FinBERTAdapter()
        statuses["finbert"] = {
            "loaded": finbert.model_loaded,
            "available": True,
            "model_id": "ProsusAI/finbert",
        }
    except Exception as exc:
        statuses["finbert"] = {"loaded": False, "available": False, "error": str(exc)}

    # Chronos
    try:
        from app.services.forecast_adapters import ChronosAdapter

        chronos = ChronosAdapter()
        statuses["chronos"] = {
            "loaded": chronos._model is not None,
            "available": chronos.available,
            "model_id": "amazon/chronos-t5-tiny",
        }
    except Exception as exc:
        statuses["chronos"] = {"loaded": False, "available": False, "error": str(exc)}

    # TimesFM
    try:
        from app.services.forecast_adapters import TimesFMAdapter

        timesfm = TimesFMAdapter()
        statuses["timesfm"] = {
            "loaded": timesfm._model is not None,
            "available": timesfm.available,
            "model_id": "google/timesfm",
        }
    except Exception as exc:
        statuses["timesfm"] = {"loaded": False, "available": False, "error": str(exc)}

    # SHAP / LightGBM
    try:
        from app.services.shap_service import shap_service

        statuses["shap"] = {
            "loaded": shap_service._model is not None,
            "available": shap_service.available,
            "model_id": "lightgbm+shap",
        }
    except Exception as exc:
        statuses["shap"] = {"loaded": False, "available": False, "error": str(exc)}

    # Market data (CCXT)
    try:
        from app.services.market_data import market_data_service

        statuses["market_data"] = {
            "loaded": True,
            "available": market_data_service.available,
            "model_id": "ccxt-binance",
        }
    except Exception as exc:
        statuses["market_data"] = {"loaded": False, "available": False, "error": str(exc)}

    return {"models": statuses}


@router.post("/models/preload")
async def preload_models():
    """Trigger background model loading for heavy ML models."""

    async def _load_finbert():
        try:
            from app.services.sentiment_finbert import FinBERTAdapter

            finbert = FinBERTAdapter()
            finbert._get_pipeline()  # Force load
            return {"finbert": "loaded"}
        except Exception as exc:
            return {"finbert": f"error: {exc}"}

    async def _load_chronos():
        try:
            from app.services.forecast_adapters import ChronosAdapter

            chronos = ChronosAdapter()
            if chronos.available:
                chronos._get_model()  # Force load
                return {"chronos": "loaded"}
            return {"chronos": "unavailable (not installed)"}
        except Exception as exc:
            return {"chronos": f"error: {exc}"}

    results = await asyncio.gather(_load_finbert(), _load_chronos(), return_exceptions=True)
    return {"status": "preload_triggered", "results": results}


@router.get("/usage")
def usage_stats(db: Session = Depends(get_db)):
    """Return LLM usage statistics from in-memory log and persisted records."""
    svc = _get_llm_service()
    memory_stats = svc.get_usage_stats()

    # Aggregate from persisted AIUsageLog
    logs = db.query(AIUsageLog).order_by(AIUsageLog.created_at.desc()).limit(100).all()
    persisted_calls = len(logs)
    persisted_tokens = sum(log.tokens_used for log in logs)
    avg_latency = sum(log.latency_ms for log in logs) / persisted_calls if persisted_calls else 0

    by_provider: dict[str, dict[str, Any]] = {}
    for log in logs:
        key = log.provider
        if key not in by_provider:
            by_provider[key] = {"calls": 0, "tokens": 0}
        by_provider[key]["calls"] += 1
        by_provider[key]["tokens"] += log.tokens_used

    return {
        "in_memory": memory_stats,
        "persisted": {
            "total_calls": persisted_calls,
            "total_tokens": persisted_tokens,
            "avg_latency_ms": round(avg_latency, 1),
            "by_provider": by_provider,
        },
        "recent": [
            {
                "provider": log.provider,
                "model": log.model,
                "service": log.service,
                "tokens_used": log.tokens_used,
                "latency_ms": log.latency_ms,
                "created_at": log.created_at.isoformat() if log.created_at else None,
            }
            for log in logs[:20]
        ],
    }

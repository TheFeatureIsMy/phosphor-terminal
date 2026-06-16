"""Detects availability of all external dependencies and ML models."""

from __future__ import annotations

import importlib
import os
from datetime import datetime, timezone


def _check_package(package_name: str) -> dict:
    """Check if a Python package is installed."""
    try:
        mod = importlib.import_module(package_name)
        version = getattr(mod, "__version__", "unknown")
        return {"status": "installed", "version": version}
    except ImportError:
        return {"status": "not_installed", "install_cmd": f"pip install {package_name}"}


def _check_ml_model(module_name: str, class_name: str | None = None) -> dict:
    """Check if an ML model module is available and loadable."""
    try:
        mod = importlib.import_module(module_name)
        if class_name:
            getattr(mod, class_name)
        return {"status": "loaded"}
    except ImportError:
        return {"status": "not_loaded", "fallback": "unavailable"}
    except Exception:
        return {"status": "not_loaded", "fallback": "unavailable"}


def _check_freqtrade_api() -> dict:
    """Check if Freqtrade API is reachable."""
    try:
        import aiohttp
        import asyncio
        from app.config import settings

        async def _ping():
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(
                        f"{settings.freqtrade_url}/api/v1/ping",
                        auth=aiohttp.BasicAuth(settings.freqtrade_username, settings.freqtrade_password),
                        timeout=aiohttp.ClientTimeout(total=3),
                    ) as resp:
                        if resp.status == 200:
                            return {"status": "connected", "url": settings.freqtrade_url}
            except Exception:
                pass
            return {"status": "disconnected", "url": settings.freqtrade_url}

        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop and loop.is_running():
            return {"status": "unknown", "url": settings.freqtrade_url, "detail": "cannot check from async context"}

        return asyncio.run(_ping())
    except Exception:
        return {"status": "disconnected"}


def _check_ollama() -> dict:
    """Check if Ollama is reachable."""
    try:
        import aiohttp
        import asyncio

        ollama_url = os.environ.get("OLLAMA_URL", "http://localhost:11434")

        async def _ping():
            try:
                async with aiohttp.ClientSession() as session:
                    async with session.get(
                        f"{ollama_url}/api/tags",
                        timeout=aiohttp.ClientTimeout(total=3),
                    ) as resp:
                        if resp.status == 200:
                            data = await resp.json()
                            models = [m.get("name", "") for m in data.get("models", [])]
                            return {"status": "connected", "url": ollama_url, "models": models[:5]}
            except Exception:
                pass
            return {"status": "disconnected", "url": ollama_url}

        try:
            loop = asyncio.get_running_loop()
        except RuntimeError:
            loop = None

        if loop and loop.is_running():
            return {"status": "unknown", "url": ollama_url}

        return asyncio.run(_ping())
    except Exception:
        return {"status": "disconnected"}


def _check_llm_provider(env_key: str, provider_name: str) -> dict:
    """Check if an LLM provider API key is configured."""
    key = os.environ.get(env_key, "")
    if key:
        return {"status": "configured", "requires": env_key}
    return {"status": "not_configured", "requires": env_key}


def _llm_provider_db_status(provider_name: str, instance_name: str = "default") -> dict:
    """Check LLM provider status via DB (provider_configs table)."""
    try:
        from app.services.providers.config_service import ProviderConfigService
        from app.services.providers.base import ProviderCategory
        from app.database import SessionLocal
        svc = ProviderConfigService()
        with SessionLocal() as db:
            row = svc.get_by_identity(
                db, category=ProviderCategory.LLM.value,
                provider_name=provider_name, instance_name=instance_name,
            )
        if row and row.enabled and row.credential_status == "configured":
            return {"status": "configured", "source": "db", "is_active": row.is_active}
        if row:
            return {"status": "configured", "source": "db", "missing_credentials": True}
        return {"status": "not_configured", "source": "db"}
    except Exception:
        return {"status": "unknown", "source": "db", "detail": "db_unavailable"}


def check_all_dependencies() -> dict:
    """Return full dependency status report."""
    required = {
        "database": {"status": "ok", "detail": "SQLite (auto-created)"},
    }

    core_optional = {
        "ccxt": _check_package("ccxt"),
        "lightgbm": _check_package("lightgbm"),
        "transformers": _check_package("transformers"),
        "torch": _check_package("torch"),
    }

    ml_models = {
        "finbert": _check_ml_model("transformers", "pipeline"),
        "chronos": _check_ml_model("chronos", "ChronosPipeline"),
        "timesfm": _check_ml_model("timesfm", "TimesFm"),
        "shap": _check_ml_model("shap", "TreeExplainer"),
    }

    external_services = {
        "freqtrade_api": _check_freqtrade_api(),
        "freqtrade_db": {
            "status": "available" if os.path.exists(
                os.environ.get("FREQTRADE_DB_PATH", "")
            ) else "not_found",
        },
        "ollama": _check_ollama(),
        "openai": _llm_provider_db_status("openai"),
        "anthropic": _llm_provider_db_status("anthropic"),
        "deepseek": _llm_provider_db_status("deepseek"),
        "qwen": _llm_provider_db_status("qwen"),
        "zhipu": _llm_provider_db_status("zhipu"),
        "moonshot": _llm_provider_db_status("moonshot"),
        "mimo": _llm_provider_db_status("mimo"),
        "gemini": _llm_provider_db_status("gemini"),
        "groq": _llm_provider_db_status("groq"),
        "azure_openai": _llm_provider_db_status("azure_openai"),
        "telegram": {
            "status": "dry_run",
            "detail": "Configure TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID to enable",
        },
    }

    total = 0
    scored = 0
    for group in [required, core_optional, ml_models, external_services]:
        for key, val in group.items():
            total += 1
            if isinstance(val, dict):
                s = val.get("status", "")
                if s in ("ok", "installed", "loaded", "connected", "configured", "available"):
                    scored += 1
                elif s == "dry_run":
                    scored += 0.5

    readiness_score = round(scored / max(total, 1), 2)

    return {
        "required": required,
        "core_optional": core_optional,
        "ml_models": ml_models,
        "external_services": external_services,
        "readiness_score": readiness_score,
        "checked_at": datetime.now(timezone.utc).isoformat(),
    }

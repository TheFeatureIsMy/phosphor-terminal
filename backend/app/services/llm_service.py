"""Unified LLM service supporting multiple providers.

Supports: OpenAI-compatible (OpenAI, DeepSeek, vLLM, LM Studio), Anthropic, Ollama (local).
Provider fallback chain: try each provider in order until one works.
"""
from __future__ import annotations

import asyncio
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any


@dataclass
class LLMResponse:
    content: str
    model: str
    provider: str
    tokens_used: int = 0
    latency_ms: float = 0


class LLMProvider(ABC):
    @abstractmethod
    async def chat(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> LLMResponse:
        ...

    @abstractmethod
    async def health_check(self) -> bool:
        ...

    @property
    @abstractmethod
    def name(self) -> str:
        ...

    @property
    @abstractmethod
    def model_id(self) -> str:
        ...


class OpenAIProvider(LLMProvider):
    """OpenAI-compatible API provider. Works with OpenAI, DeepSeek, vLLM, LM Studio via base_url."""

    def __init__(
        self,
        api_key: str,
        model: str = "gpt-4o",
        base_url: str = "https://api.openai.com/v1",
    ) -> None:
        self._api_key = api_key
        self._model = model
        self._base_url = base_url.rstrip("/")

    @property
    def name(self) -> str:
        return "openai"

    @property
    def model_id(self) -> str:
        return self._model

    async def health_check(self) -> bool:
        try:
            import httpx
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.get(
                    f"{self._base_url}/models",
                    headers={"Authorization": f"Bearer {self._api_key}"},
                )
                return resp.status_code == 200
        except Exception:
            return False

    async def chat(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> LLMResponse:
        import httpx

        start = time.monotonic()
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                f"{self._base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self._api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self._model,
                    "messages": messages,
                    "temperature": temperature,
                    "max_tokens": max_tokens,
                },
            )
            resp.raise_for_status()
            data = resp.json()

        elapsed = (time.monotonic() - start) * 1000
        choice = data["choices"][0]
        usage = data.get("usage", {})

        return LLMResponse(
            content=choice["message"]["content"],
            model=self._model,
            provider="openai",
            tokens_used=usage.get("total_tokens", 0),
            latency_ms=round(elapsed, 1),
        )


class AnthropicProvider(LLMProvider):
    """Anthropic Claude API provider."""

    def __init__(
        self,
        api_key: str,
        model: str = "claude-sonnet-4-20250514",
    ) -> None:
        self._api_key = api_key
        self._model = model

    @property
    def name(self) -> str:
        return "anthropic"

    @property
    def model_id(self) -> str:
        return self._model

    async def health_check(self) -> bool:
        try:
            import httpx
            async with httpx.AsyncClient(timeout=10) as client:
                resp = await client.post(
                    "https://api.anthropic.com/v1/messages",
                    headers={
                        "x-api-key": self._api_key,
                        "anthropic-version": "2023-06-01",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": self._model,
                        "max_tokens": 1,
                        "messages": [{"role": "user", "content": "hi"}],
                    },
                )
                return resp.status_code == 200
        except Exception:
            return False

    async def chat(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> LLMResponse:
        import httpx

        start = time.monotonic()
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": self._api_key,
                    "anthropic-version": "2023-06-01",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self._model,
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                    "messages": messages,
                },
            )
            resp.raise_for_status()
            data = resp.json()

        elapsed = (time.monotonic() - start) * 1000
        content = data["content"][0]["text"] if data.get("content") else ""
        usage = data.get("usage", {})

        return LLMResponse(
            content=content,
            model=self._model,
            provider="anthropic",
            tokens_used=usage.get("input_tokens", 0) + usage.get("output_tokens", 0),
            latency_ms=round(elapsed, 1),
        )


class OllamaProvider(LLMProvider):
    """Ollama local LLM provider. No API key needed."""

    def __init__(
        self,
        base_url: str = "http://localhost:11434",
        model: str = "qwen2.5:7b",
    ) -> None:
        self._base_url = base_url.rstrip("/")
        self._model = model

    @property
    def name(self) -> str:
        return "ollama"

    @property
    def model_id(self) -> str:
        return self._model

    async def health_check(self) -> bool:
        try:
            import httpx
            async with httpx.AsyncClient(timeout=5) as client:
                resp = await client.get(f"{self._base_url}/api/tags")
                return resp.status_code == 200
        except Exception:
            return False

    async def chat(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> LLMResponse:
        import httpx

        start = time.monotonic()
        async with httpx.AsyncClient(timeout=300) as client:
            resp = await client.post(
                f"{self._base_url}/api/chat",
                json={
                    "model": self._model,
                    "messages": messages,
                    "stream": False,
                    "options": {
                        "temperature": temperature,
                        "num_predict": max_tokens,
                    },
                },
            )
            resp.raise_for_status()
            data = resp.json()

        elapsed = (time.monotonic() - start) * 1000
        content = data.get("message", {}).get("content", "")

        return LLMResponse(
            content=content,
            model=self._model,
            provider="ollama",
            tokens_used=data.get("eval_count", 0),
            latency_ms=round(elapsed, 1),
        )

    async def list_models(self) -> list[str]:
        """List available models on the Ollama server."""
        import httpx
        try:
            async with httpx.AsyncClient(timeout=5) as client:
                resp = await client.get(f"{self._base_url}/api/tags")
                if resp.status_code == 200:
                    data = resp.json()
                    return [m["name"] for m in data.get("models", [])]
        except Exception:
            pass
        return []


class LLMService:
    """Unified LLM service with provider fallback chain."""

    def __init__(self, config: dict[str, Any] | None = None) -> None:
        self.providers: list[LLMProvider] = []
        self._usage_log: list[dict] = []
        if config:
            self._load_providers(config)

    def _load_providers(self, config: dict[str, Any]) -> None:
        # Priority: first configured = first tried
        if config.get("openai_api_key"):
            self.providers.append(
                OpenAIProvider(
                    api_key=config["openai_api_key"],
                    model=config.get("openai_model", "gpt-4o"),
                    base_url=config.get("openai_base_url", "https://api.openai.com/v1"),
                )
            )

        if config.get("anthropic_api_key"):
            self.providers.append(
                AnthropicProvider(
                    api_key=config["anthropic_api_key"],
                    model=config.get("anthropic_model", "claude-sonnet-4-20250514"),
                )
            )

        if config.get("ollama_enabled", True):
            self.providers.append(
                OllamaProvider(
                    base_url=config.get("ollama_url", "http://localhost:11434"),
                    model=config.get("ollama_model", "qwen2.5:7b"),
                )
            )

    def add_provider(self, provider: LLMProvider) -> None:
        self.providers.append(provider)

    async def chat(
        self,
        messages: list[dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> LLMResponse:
        """Try each provider in order until one succeeds."""
        last_error = None
        for provider in self.providers:
            try:
                if await provider.health_check():
                    response = await provider.chat(messages, temperature, max_tokens)
                    self._log_usage(response)
                    return response
            except Exception as exc:
                last_error = exc
                continue

        raise RuntimeError(
            f"No LLM provider available. Last error: {last_error}"
        )

    async def list_available(self) -> list[dict[str, Any]]:
        """Return status of all configured providers."""
        results = []
        for p in self.providers:
            available = await p.health_check()
            results.append({
                "provider": p.name,
                "model": p.model_id,
                "available": available,
            })
        return results

    def _log_usage(self, response: LLMResponse) -> None:
        self._usage_log.append({
            "provider": response.provider,
            "model": response.model,
            "tokens_used": response.tokens_used,
            "latency_ms": response.latency_ms,
        })

    def get_usage_stats(self) -> dict[str, Any]:
        if not self._usage_log:
            return {"total_calls": 0, "total_tokens": 0, "avg_latency_ms": 0}

        total_tokens = sum(u["tokens_used"] for u in self._usage_log)
        avg_latency = sum(u["latency_ms"] for u in self._usage_log) / len(self._usage_log)

        return {
            "total_calls": len(self._usage_log),
            "total_tokens": total_tokens,
            "avg_latency_ms": round(avg_latency, 1),
        }


def create_llm_service_from_env() -> LLMService:
    """Create LLMService from environment variables."""
    import os

    config = {
        "openai_api_key": os.getenv("OPENAI_API_KEY", ""),
        "openai_model": os.getenv("OPENAI_MODEL", "gpt-4o"),
        "openai_base_url": os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1"),
        "anthropic_api_key": os.getenv("ANTHROPIC_API_KEY", ""),
        "anthropic_model": os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-20250514"),
        "ollama_enabled": os.getenv("OLLAMA_ENABLED", "true").lower() == "true",
        "ollama_url": os.getenv("OLLAMA_URL", "http://localhost:11434"),
        "ollama_model": os.getenv("OLLAMA_MODEL", "qwen2.5:7b"),
    }

    return LLMService(config)

"""LLM provider registrations."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

from app.services.providers.categories.llm.openai import OpenAIProvider
from app.services.providers.categories.llm.anthropic import AnthropicProvider
from app.services.providers.categories.llm.ollama import OllamaProvider


def _make_stub(provider_name: str):
    cls = type(
        f"{provider_name.title()}Provider",
        (ProviderStubBase,),
        {
            "category": ProviderCategory.LLM,
            "provider_name": provider_name,
            "is_multi_instance": True,
        },
    )
    return cls


for _name in ("deepseek", "qwen", "zhipu", "moonshot", "gemini", "groq", "azure_openai"):
    registry.register(_make_stub(_name))

for _cls in (OpenAIProvider, AnthropicProvider, OllamaProvider):
    registry.register(_cls)

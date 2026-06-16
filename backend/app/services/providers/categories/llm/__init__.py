"""LLM provider registrations."""
from app.services.providers.base import ProviderCategory, ProviderStubBase
from app.services.providers.registry import registry

from app.services.providers.categories.llm.openai import OpenAIProvider
from app.services.providers.categories.llm.anthropic import AnthropicProvider
from app.services.providers.categories.llm.ollama import OllamaProvider
from app.services.providers.categories.llm.deepseek import DeepSeekProvider
from app.services.providers.categories.llm.qwen import QwenProvider
from app.services.providers.categories.llm.zhipu import ZhipuProvider
from app.services.providers.categories.llm.moonshot import MoonshotProvider
from app.services.providers.categories.llm.gemini import GeminiProvider
from app.services.providers.categories.llm.groq import GroqProvider
from app.services.providers.categories.llm.azure_openai import AzureOpenAIProvider


for _cls in (
    OpenAIProvider, AnthropicProvider, OllamaProvider,
    DeepSeekProvider, QwenProvider, ZhipuProvider, MoonshotProvider,
    GeminiProvider, GroqProvider, AzureOpenAIProvider,
):
    registry.register(_cls)

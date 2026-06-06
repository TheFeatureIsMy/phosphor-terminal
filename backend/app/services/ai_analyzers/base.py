from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class AnalyzerResult:
    analyzer_name: str
    risk_score: float
    risk_flags: list[str]
    summary: str
    confidence: float = 0.5
    raw_data: dict = field(default_factory=dict)


class BaseAnalyzer(ABC):
    def __init__(self, llm_service=None):
        self._llm = llm_service

    @abstractmethod
    async def analyze(self, symbol: str, context: dict) -> AnalyzerResult:
        ...

from __future__ import annotations

import json
import logging

from .base import BaseAnalyzer, AnalyzerResult

logger = logging.getLogger(__name__)

NEWS_PROMPT = """Analyze the current market risk for {symbol} based on available news context.

Context: {context}

Return a JSON object with exactly these fields:
- risk_score: float 0.0 to 1.0 (0=low risk, 1=extreme risk)
- risk_flags: list of strings (e.g. ["regulatory_news", "exchange_hack"])
- summary: one-sentence summary

Respond ONLY with the JSON object, no other text."""


class NewsRiskAnalyzer(BaseAnalyzer):
    async def analyze(self, symbol: str, context: dict) -> AnalyzerResult:
        if not self._llm:
            return self._default_result(symbol)

        try:
            prompt = NEWS_PROMPT.format(symbol=symbol, context=json.dumps(context.get("news", {})))
            response = await self._llm.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=200,
            )
            data = json.loads(response.content)
            return AnalyzerResult(
                analyzer_name="news_risk",
                risk_score=min(1.0, max(0.0, float(data.get("risk_score", 0.3)))),
                risk_flags=data.get("risk_flags", []),
                summary=data.get("summary", ""),
                confidence=0.6,
            )
        except Exception:
            logger.warning("news risk analysis failed for %s, using defaults", symbol)
            return self._default_result(symbol)

    def _default_result(self, symbol: str) -> AnalyzerResult:
        return AnalyzerResult(
            analyzer_name="news_risk",
            risk_score=0.3,
            risk_flags=[],
            summary=f"No news data available for {symbol}",
            confidence=0.2,
        )

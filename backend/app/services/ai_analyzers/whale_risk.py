from __future__ import annotations

import json
import logging

from .base import BaseAnalyzer, AnalyzerResult

logger = logging.getLogger(__name__)

WHALE_PROMPT = """Analyze whale/institutional activity risk for {symbol}.

Context: {context}

Return a JSON object with:
- risk_score: float 0.0 to 1.0
- risk_flags: list of strings (e.g. ["large_exchange_inflow", "whale_dump"])
- summary: one-sentence summary

Respond ONLY with the JSON object."""


class WhaleRiskAnalyzer(BaseAnalyzer):
    async def analyze(self, symbol: str, context: dict) -> AnalyzerResult:
        if not self._llm:
            return self._default_result(symbol)

        try:
            prompt = WHALE_PROMPT.format(symbol=symbol, context=json.dumps(context.get("whale", {})))
            response = await self._llm.chat(
                messages=[{"role": "user", "content": prompt}],
                temperature=0.2,
                max_tokens=200,
            )
            data = json.loads(response.content)
            return AnalyzerResult(
                analyzer_name="whale_risk",
                risk_score=min(1.0, max(0.0, float(data.get("risk_score", 0.2)))),
                risk_flags=data.get("risk_flags", []),
                summary=data.get("summary", ""),
                confidence=0.5,
            )
        except Exception:
            logger.warning("whale risk analysis failed for %s", symbol)
            return self._default_result(symbol)

    def _default_result(self, symbol: str) -> AnalyzerResult:
        return AnalyzerResult(
            analyzer_name="whale_risk",
            risk_score=0.2,
            risk_flags=[],
            summary=f"No whale data available for {symbol}",
            confidence=0.2,
        )

from __future__ import annotations

import asyncio
import logging
from datetime import datetime, timezone, timedelta

from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.ai_analyzers.base import AnalyzerResult
from app.services.ai_analyzers.news_risk import NewsRiskAnalyzer
from app.services.ai_analyzers.whale_risk import WhaleRiskAnalyzer
from app.services.ai_analyzers.conflict_analysis import ConflictAnalyzer

logger = logging.getLogger(__name__)


class AIRiskCacheService:
    def __init__(self, redis_store: RuntimeRedisStore, llm_service=None,
                 refresh_interval_s: int = 300, cache_ttl_s: int = 900):
        self._store = redis_store
        self._llm = llm_service
        self._refresh_interval = refresh_interval_s
        self._cache_ttl = cache_ttl_s
        self._analyzers = [
            NewsRiskAnalyzer(llm_service),
            WhaleRiskAnalyzer(llm_service),
        ]
        self._conflict_analyzer = ConflictAnalyzer()
        self._running = False

    async def refresh(self, symbol: str, context: dict | None = None) -> dict:
        ctx = context or {}
        results: list[AnalyzerResult] = []

        tasks = [a.analyze(symbol, ctx) for a in self._analyzers]
        raw_results = await asyncio.gather(*tasks, return_exceptions=True)

        for r in raw_results:
            if isinstance(r, AnalyzerResult):
                results.append(r)
            else:
                logger.warning("analyzer failed: %s", r)

        # Run conflict analysis
        conflict_ctx = {
            "structure_direction": ctx.get("structure_direction"),
            "news_bias": next((r.summary for r in results if r.analyzer_name == "news_risk"), None),
            "whale_risk_score": max((r.risk_score for r in results if r.analyzer_name == "whale_risk"), default=0),
            "analyzer_count": len(results),
        }
        conflict = await self._conflict_analyzer.analyze(symbol, conflict_ctx)
        results.append(conflict)

        # Aggregate
        max_score = max((r.risk_score for r in results), default=0.0)
        all_flags = []
        for r in results:
            all_flags.extend(r.risk_flags)
        summaries = [r.summary for r in results if r.summary]

        now = datetime.now(timezone.utc)
        cache = {
            "symbol": symbol,
            "ai_risk_score": round(max_score, 4),
            "risk_flags": list(set(all_flags)),
            "summary": " | ".join(summaries),
            "trade_permission": "block_new_entries" if max_score > 0.8 else (
                "reduce_size" if max_score > 0.5 else "allow"
            ),
            "generated_at": now.isoformat(),
            "valid_until": (now + timedelta(seconds=self._cache_ttl)).isoformat(),
            "analyzer_results": {r.analyzer_name: {
                "risk_score": r.risk_score,
                "risk_flags": r.risk_flags,
                "confidence": r.confidence,
            } for r in results},
        }

        await self._store.write_ai_cache(symbol, cache, ttl=self._cache_ttl)
        logger.info("AI cache refreshed for %s: risk=%.2f flags=%s", symbol, max_score, all_flags)
        return cache

    async def get_cached(self, symbol: str) -> dict | None:
        return await self._store.read_ai_cache(symbol)

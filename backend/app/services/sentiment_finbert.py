from __future__ import annotations

from typing import Any


class FinBERTAdapter:
    """FinBERT sentiment analysis with lazy model loading and keyword fallback."""

    _pipeline = None
    _load_failed = False

    POSITIVE_WORDS = {"profit", "gain", "bullish", "upgrade", "growth", "positive", "outperform", "beat"}
    NEGATIVE_WORDS = {"loss", "decline", "bearish", "downgrade", "risk", "negative", "underperform", "miss"}

    def _get_pipeline(self):
        if self._pipeline is None and not self._load_failed:
            try:
                from transformers import pipeline as hf_pipeline
                self._pipeline = hf_pipeline(
                    "sentiment-analysis",
                    model="ProsusAI/finbert",
                    top_k=None,  # return all 3 labels (positive, negative, neutral)
                    device=-1,   # CPU
                )
            except Exception:
                self._load_failed = True
        return self._pipeline

    @property
    def model_loaded(self) -> bool:
        return self._pipeline is not None

    def analyze_text(self, text: str) -> dict[str, Any]:
        pipe = self._get_pipeline()
        if pipe is None:
            return self._keyword_fallback(text)

        try:
            # Truncate to 512 tokens (FinBERT max)
            results = pipe(text[:512])[0]
            scores = {r["label"]: r["score"] for r in results}
            score = scores.get("positive", 0) - scores.get("negative", 0)
            label = "positive" if score > 0.2 else "negative" if score < -0.2 else "neutral"
            return {
                "label": label,
                "score": round(score, 4),
                "confidence": round(max(scores.values()), 4),
                "model": "finbert",
            }
        except Exception:
            return self._keyword_fallback(text)

    def _keyword_fallback(self, text: str) -> dict[str, Any]:
        tokens = set(text.lower().split())
        pos_count = len(tokens & self.POSITIVE_WORDS)
        neg_count = len(tokens & self.NEGATIVE_WORDS)
        total = pos_count + neg_count
        if total == 0:
            score = 0.0
            label = "neutral"
        else:
            score = (pos_count - neg_count) / total
            label = "positive" if score > 0.2 else "negative" if score < -0.2 else "neutral"
        return {"label": label, "score": round(score, 4), "confidence": 0.5, "model": "keyword_fallback"}

    async def analyze_batch(self, texts: list[str]) -> list[dict[str, Any]]:
        pipe = self._get_pipeline()
        if pipe is None:
            return [self._keyword_fallback(t) for t in texts]
        try:
            results = pipe([t[:512] for t in texts], batch_size=8)
            output = []
            for result_set in results:
                scores = {r["label"]: r["score"] for r in result_set}
                score = scores.get("positive", 0) - scores.get("negative", 0)
                label = "positive" if score > 0.2 else "negative" if score < -0.2 else "neutral"
                output.append({
                    "label": label,
                    "score": round(score, 4),
                    "confidence": round(max(scores.values()), 4),
                    "model": "finbert",
                })
            return output
        except Exception:
            return [self._keyword_fallback(t) for t in texts]

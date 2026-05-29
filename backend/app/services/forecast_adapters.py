from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

import numpy as np


class TimesFMAdapter:
    """Google TimesFM time-series forecasting.

    Lazy-loads a `timesfm.TimesFm` model on first forecast call (CPU backend).
    """

    def __init__(self) -> None:
        self._model = None
        self._horizon: int | None = None

    @property
    def available(self) -> bool:
        try:
            import timesfm  # type: ignore  # noqa: F401
            return True
        except ImportError:
            return False

    def _get_model(self, history_len: int = 128, horizon: int = 7):
        if self._model is None or self._horizon != horizon:
            import timesfm
            self._model = timesfm.TimesFm(
                context_len=min(history_len * 2, 512),
                horizon_len=horizon,
                backend="cpu",
            )
            self._horizon = horizon
        return self._model

    async def forecast(self, history: list[float], horizon: int = 7) -> dict[str, Any]:
        if not self.available:
            return {
                "status": "unavailable",
                "detail": "TimesFM is not installed.",
                "points": [],
                "confidence": 0.0,
            }
        if len(history) < 4:
            return {"status": "error", "detail": "Need at least 4 history points", "points": [], "confidence": 0.0}
        model = self._get_model(len(history), horizon)
        arr = np.array(history, dtype=np.float64)
        forecast = model.forecast(inputs=[arr], freq=[0])
        means = forecast.mean[0].tolist() if hasattr(forecast, "mean") else forecast[0].tolist()
        stds = forecast.std[0].tolist() if hasattr(forecast, "std") else [0.02] * horizon
        now = datetime.now(timezone.utc)
        points: list[dict[str, Any]] = []
        for i in range(min(horizon, len(means))):
            points.append({
                "date": now.replace(hour=0, minute=0, second=0, microsecond=0).isoformat(),
                "value": round(float(means[i]), 4),
            })
        avg_std = float(np.mean(stds[:horizon])) if stds else 0.02
        confidence = max(0, min(0.99, 1.0 - avg_std / (abs(np.mean(history)) + 1e-8)))
        return {
            "status": "ok",
            "points": points[:horizon],
            "confidence": round(confidence, 3),
            "model": "timesfm",
        }


class ChronosAdapter:
    """Amazon Chronos zero-shot time-series forecasting.

    Lazy-loads `amazon/chronos-t5-tiny` on first forecast call.
    Tiny variant runs on CPU with ~8M parameters.
    """

    def __init__(self) -> None:
        self._model = None

    @property
    def available(self) -> bool:
        try:
            import chronos  # type: ignore  # noqa: F401
            return True
        except ImportError:
            return False

    def _get_model(self):
        if self._model is None:
            from chronos import ChronosPipeline
            import torch
            self._model = ChronosPipeline.from_pretrained(
                "amazon/chronos-t5-tiny",
                device_map="cpu",
                torch_dtype=torch.float32,
            )
        return self._model

    async def forecast(self, history: list[float], horizon: int = 7) -> dict[str, Any]:
        if not self.available:
            return {
                "status": "unavailable",
                "detail": "Chronos is not installed.",
                "points": [],
                "confidence": 0.0,
            }
        if len(history) < 4:
            return {"status": "error", "detail": "Need at least 4 history points", "points": [], "confidence": 0.0}
        import torch
        model = self._get_model()
        context = torch.tensor(history, dtype=torch.float32)
        with torch.no_grad():
            forecast_samples = model.predict(
                context=context,
                prediction_length=horizon,
                num_samples=5,
            )
        samples = forecast_samples.numpy() if hasattr(forecast_samples, "numpy") else forecast_samples
        mean_forecast = np.mean(samples, axis=0) if samples.ndim > 1 else samples
        std_forecast = np.std(samples, axis=0) if samples.ndim > 1 else np.full_like(mean_forecast, 0.02)
        now = datetime.now(timezone.utc)
        points: list[dict[str, Any]] = []
        for i in range(min(horizon, len(mean_forecast))):
            points.append({
                "date": now.replace(hour=0, minute=0, second=0, microsecond=0).isoformat(),
                "value": round(float(mean_forecast[i]), 4),
            })
        avg_std = float(np.mean(std_forecast[:horizon]))
        confidence = max(0, min(0.99, 1.0 - avg_std / (abs(np.mean(history)) + 1e-8)))
        return {
            "status": "ok",
            "points": points[:horizon],
            "confidence": round(confidence, 3),
            "model": "chronos-t5-tiny",
        }

"""Manipulation ML training pipeline — extract samples from confirmed cases, manage training set."""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from typing import Any

logger = logging.getLogger(__name__)


@dataclass
class TrainingSample:
    """One training sample extracted from a confirmed manipulation case."""
    case_id: str
    symbol: str
    market: str
    manipulation_type: str           # M1-M8 label
    lifecycle_stage: str             # stage label at this time step
    next_stage: str = ""             # next stage (supervision signal)
    feature_vector: dict[str, float] = field(default_factory=dict)
    available_layers: list[str] = field(default_factory=list)
    outcome: dict[str, Any] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "case_id": self.case_id,
            "symbol": self.symbol,
            "market": self.market,
            "manipulation_type": self.manipulation_type,
            "lifecycle_stage": self.lifecycle_stage,
            "next_stage": self.next_stage,
            "feature_vector": self.feature_vector,
            "available_layers": self.available_layers,
            "outcome": self.outcome,
        }


class TrainingDataset:
    """In-memory training dataset. Stores samples and provides access for model training."""

    def __init__(self):
        self._samples: list[TrainingSample] = []
        self._version: int = 0

    @property
    def size(self) -> int:
        return len(self._samples)

    @property
    def version(self) -> int:
        return self._version

    def add_samples(self, samples: list[TrainingSample]):
        self._samples.extend(samples)
        self._version += 1
        logger.info("Training set updated: +%d samples, total=%d, version=%d",
                     len(samples), self.size, self._version)

    def get_samples(self, manipulation_type: str | None = None,
                    stage: str | None = None) -> list[TrainingSample]:
        result = self._samples
        if manipulation_type:
            result = [s for s in result if s.manipulation_type == manipulation_type]
        if stage:
            result = [s for s in result if s.lifecycle_stage == stage]
        return result

    def get_feature_matrix(self) -> tuple[list[dict], list[str]]:
        """Return (feature_vectors, labels) for model training."""
        features = [s.feature_vector for s in self._samples]
        labels = [s.manipulation_type for s in self._samples]
        return features, labels

    def get_stage_matrix(self) -> tuple[list[dict], list[str]]:
        """Return (feature_vectors, stage_labels) for stage prediction training."""
        features = [s.feature_vector for s in self._samples]
        labels = [s.lifecycle_stage for s in self._samples]
        return features, labels

    def stats(self) -> dict:
        by_type: dict[str, int] = {}
        by_stage: dict[str, int] = {}
        for s in self._samples:
            by_type[s.manipulation_type] = by_type.get(s.manipulation_type, 0) + 1
            by_stage[s.lifecycle_stage] = by_stage.get(s.lifecycle_stage, 0) + 1
        return {
            "total_samples": self.size,
            "version": self._version,
            "by_type": by_type,
            "by_stage": by_stage,
            "symbols": list(set(s.symbol for s in self._samples)),
        }

    def clear(self):
        self._samples.clear()
        self._version += 1


class ManipulationTrainingPipeline:
    """Extracts training samples from confirmed cases and manages the training lifecycle."""

    RETRAIN_THRESHOLD = 50  # retrain after this many new cases

    def __init__(self):
        self.dataset = TrainingDataset()
        self._cases_since_last_train = 0

    def extract_samples_from_case(self, case: dict) -> list[TrainingSample]:
        """Extract training samples from a completed manipulation case.
        Each stage in the timeline becomes a separate training sample."""
        samples = []
        timeline = case.get("timeline", [])
        outcome = case.get("outcome", {})

        for i, entry in enumerate(timeline):
            next_stage = timeline[i + 1]["stage"] if i + 1 < len(timeline) else "completed"
            features = entry.get("features_snapshot", entry.get("features", {}))

            # Determine which data layers contributed
            layers = ["A"]  # OHLCV always present
            if any(k.startswith("funding") or k.startswith("basis") or k.startswith("oi_") or k.startswith("cross_market") for k in features):
                layers.append("E")
            if any(k.startswith("spoof") or k.startswith("depth") or k.startswith("liquidity_void") or k.startswith("large_order") or k.startswith("spread") for k in features):
                layers.append("B")
            if any(k.startswith("holder") or k.startswith("exchange_inflow") or k.startswith("whale") or k.startswith("new_holder") for k in features):
                layers.append("C")
            if any(k.startswith("social") or k.startswith("kol") or k.startswith("sentiment") or k.startswith("retail") for k in features):
                layers.append("D")

            sample = TrainingSample(
                case_id=case.get("id", ""),
                symbol=case.get("symbol", ""),
                market=case.get("market", "crypto"),
                manipulation_type=case.get("manipulation_type", ""),
                lifecycle_stage=entry.get("stage", ""),
                next_stage=next_stage,
                feature_vector=features,
                available_layers=layers,
                outcome=outcome,
            )
            samples.append(sample)

        return samples

    async def on_case_completed(self, case: dict):
        """Called when a manipulation case completes its full lifecycle.
        Extracts samples and checks if retraining is needed."""
        samples = self.extract_samples_from_case(case)
        if samples:
            self.dataset.add_samples(samples)
            self._cases_since_last_train += 1
            logger.info("Case %s: extracted %d training samples (total=%d)",
                        case.get("id", "?"), len(samples), self.dataset.size)

            if self._cases_since_last_train >= self.RETRAIN_THRESHOLD:
                await self._trigger_retrain()

    async def _trigger_retrain(self):
        """Trigger model retraining with current dataset.
        v1: Just log stats. v2: Actually train XGBoost. v3: Transformer."""
        stats = self.dataset.stats()
        logger.info("Retrain triggered: %d samples, %d types, %d stages",
                     stats["total_samples"], len(stats["by_type"]), len(stats["by_stage"]))
        self._cases_since_last_train = 0
        # Future: train model here
        # model = train_xgboost(self.dataset.get_feature_matrix())
        # evaluate and swap if better

    def get_stats(self) -> dict:
        return {
            **self.dataset.stats(),
            "cases_since_last_train": self._cases_since_last_train,
            "retrain_threshold": self.RETRAIN_THRESHOLD,
        }

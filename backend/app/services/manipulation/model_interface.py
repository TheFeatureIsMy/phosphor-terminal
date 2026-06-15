"""Model interface for manipulation detection — swappable between rules and ML."""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class ModelPrediction:
    manipulation_type: str        # M1-M8 or "none"
    confidence: float             # 0-1
    type_probabilities: dict[str, float] = field(default_factory=dict)
    stage_prediction: str = ""    # lifecycle stage
    stage_confidence: float = 0.0
    feature_importance: dict[str, float] = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "manipulation_type": self.manipulation_type,
            "confidence": self.confidence,
            "type_probabilities": self.type_probabilities,
            "stage_prediction": self.stage_prediction,
            "stage_confidence": self.stage_confidence,
            "feature_importance": self.feature_importance,
        }


class ManipulationModel(ABC):
    """Abstract model interface. Swap implementations without changing callers."""

    @property
    @abstractmethod
    def model_version(self) -> str: ...

    @property
    @abstractmethod
    def model_type(self) -> str: ...

    @abstractmethod
    def predict(self, features: dict[str, float]) -> ModelPrediction: ...

    @abstractmethod
    def predict_batch(self, feature_list: list[dict[str, float]]) -> list[ModelPrediction]: ...


class RulesBasedModel(ManipulationModel):
    """v1: Wraps the existing ManipulationPatternClassifier as a model."""

    @property
    def model_version(self) -> str:
        return "rules-v1"

    @property
    def model_type(self) -> str:
        return "rules"

    def predict(self, features: dict[str, float]) -> ModelPrediction:
        from app.services.manipulation.classifier import ManipulationPatternClassifier
        clf = ManipulationPatternClassifier()
        matches = clf.classify(features)

        if not matches:
            return ModelPrediction(manipulation_type="none", confidence=0.0)

        primary = matches[0]
        type_probs = {m.manipulation_type: m.confidence for m in matches}

        # Feature importance: which features contributed most
        importance = {}
        for key, val in primary.evidence.items():
            if isinstance(val, (int, float)):
                importance[key] = val / 100.0

        return ModelPrediction(
            manipulation_type=primary.manipulation_type,
            confidence=primary.confidence,
            type_probabilities=type_probs,
            feature_importance=importance,
        )

    def predict_batch(self, feature_list: list[dict[str, float]]) -> list[ModelPrediction]:
        return [self.predict(f) for f in feature_list]


# Future implementations:
# class XGBoostModel(ManipulationModel): ...
# class TransformerModel(ManipulationModel): ...

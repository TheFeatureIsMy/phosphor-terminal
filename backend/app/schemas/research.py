from datetime import date, datetime
from typing import Any, Optional

from pydantic import BaseModel, ConfigDict, Field


class AIResearchRunCreate(BaseModel):
    symbol: str = Field(..., min_length=1, max_length=64)
    asset_type: str = "stock"
    analysis_date: date
    selected_analysts: list[str] = ["market", "social", "news", "fundamentals"]
    llm_provider: str = "openai"
    deep_think_llm: str = "gpt-5.4"
    quick_think_llm: str = "gpt-5.4-mini"
    max_debate_rounds: int = 1
    max_risk_rounds: int = 1


class AIResearchRunResponse(BaseModel):
    id: int
    symbol: str
    asset_type: str
    analysis_date: date
    provider: str
    runtime_config: dict[str, Any]
    status: str
    rating: Optional[str] = None
    confidence: Optional[float] = None
    final_decision: Optional[str] = None
    market_report: Optional[str] = None
    sentiment_report: Optional[str] = None
    news_report: Optional[str] = None
    fundamentals_report: Optional[str] = None
    investment_debate: dict[str, Any] = {}
    risk_debate: dict[str, Any] = {}
    error_message: Optional[str] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

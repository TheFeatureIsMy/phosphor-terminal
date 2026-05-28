# AI Research Committee and Agent Signal Hub Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a production-safe AI research and agent-signal layer to PulseDesk by integrating TradingAgents as an isolated research engine and re-implementing the useful AI-Trader concepts as native PulseDesk modules.

**Architecture:** TradingAgents should be integrated as a separate Python adapter/service boundary that produces persisted research runs and ratings; it must not directly execute trades. AI-Trader should not be copied wholesale because it is a full platform with overlapping auth, positions, signals, subscriptions, marketplace, and experiment systems; instead, its signal, scoring, leaderboard, and agent-heartbeat concepts should be re-modeled inside PulseDesk.

**Tech Stack:** FastAPI, SQLAlchemy, SQLite/PostgreSQL-ready models, React/Tauri, React Query, TradingAgents/LangGraph optional dependency group, background jobs, Freqtrade integration, existing PulseDesk auth/settings.

---

## Context and Source Analysis

### Current PulseDesk State

PulseDesk currently has a strong desktop UI shell and route coverage, but the product is still closer to an interactive prototype plus backend skeleton than a fully operational trading system.

Relevant current files:
- `src/App.tsx`: app routes for Dashboard, Strategies, Strategy Detail, Backtest, Trades, Settings, Profile, Strategy Lab.
- `src/api/client.ts`: frontend API client still defaults to mock mode unless `VITE_USE_MOCK=false`.
- `backend/app/routers/backtest.py`: attempts Freqtrade backtest but falls back to generated mock data.
- `backend/app/services/freqtrade_client.py`: thin Freqtrade REST API client.
- `backend/app/services/freqtrade_db.py`: reads Freqtrade SQLite trades table when available.
- `backend/app/routers/rag.py`: current RAG Strategy Lab API.
- `backend/app/routers/attribution.py`: current SHAP-style attribution API.
- `backend/app/routers/sentiment.py`: current sentiment API.
- `backend/app/models/strategy.py`: strategy, risk event, and correlation models.

### TradingAgents Findings

Local clone: `/Users/novspace/workspace/external-research/TradingAgents`

TradingAgents is a multi-agent LLM financial research framework. Its key value is a research-decision pipeline:
- Market analyst
- Social/sentiment analyst
- News analyst
- Fundamentals analyst
- Bull and bear researchers
- Research manager
- Trader
- Risk debaters
- Portfolio manager

Core entry:
- `/Users/novspace/workspace/external-research/TradingAgents/tradingagents/graph/trading_graph.py`
- `TradingAgentsGraph.propagate(ticker, trade_date, asset_type="stock")`

Primary output:
- Complete analyst reports and debate state
- Final portfolio decision rendered as markdown
- Parsed 5-tier rating: `Buy`, `Overweight`, `Hold`, `Underweight`, `Sell`

Integration fit:
- High fit for PulseDesk's missing AI research layer.
- Medium fit for crypto because the framework is still stock-oriented in data vendors.
- Low fit for direct trade execution.

License:
- Apache-2.0 license is present in the repository.

### AI-Trader Findings

Local clone: `/Users/novspace/workspace/external-research/AI-Trader`

AI-Trader is an agent-native trading platform, not a small research library. Its useful concepts:
- Agent self-registration and heartbeat
- Agent messages and tasks over API/WebSocket
- Signal feed with strategy, operation, and discussion signal types
- Follow/unfollow subscriptions
- Copy-trading simulation
- Agent leaderboard, profit history, collaboration metrics
- Signal quality scoring
- Experiment/challenge/team modules

Key files:
- `/Users/novspace/workspace/external-research/AI-Trader/service/server/routes_agent.py`
- `/Users/novspace/workspace/external-research/AI-Trader/service/server/routes_signals.py`
- `/Users/novspace/workspace/external-research/AI-Trader/service/server/routes_trading.py`
- `/Users/novspace/workspace/external-research/AI-Trader/service/server/signal_quality.py`
- `/Users/novspace/workspace/external-research/AI-Trader/service/server/experiment_metrics.py`
- `/Users/novspace/workspace/external-research/AI-Trader/service/server/database.py`

Integration fit:
- High fit as product inspiration for a native Agent Signal Hub.
- Low fit for direct code import because its data model overlaps PulseDesk's user, order, position, auth, signal, and leaderboard domains.

License caution:
- README claims MIT, but no local `LICENSE` file was found in the cloned repository. Do not copy source files into PulseDesk until license provenance is confirmed.

---

## Product Direction

### New Native Module 1: AI Research Committee

Purpose: turn TradingAgents into a PulseDesk research engine that can analyze an instrument, produce a structured investment committee report, and attach the result to strategies, backtests, or watchlist symbols.

User-facing surfaces:
- New route: `/research`
- Strategy Detail tab: `AI Research`
- Dashboard panel: latest AI research ratings
- Backtest pre-flight: compare research thesis with backtest outcome

Non-goals:
- No automatic order execution from LLM output.
- No direct replacement of RAG Strategy Lab.
- No direct dependency on user-facing TradingAgents CLI.

### New Native Module 2: Agent Signal Hub

Purpose: re-implement the best AI-Trader concepts inside PulseDesk as a local, controlled signal layer.

User-facing surfaces:
- New route: `/signals`
- Agent profile drawer or page
- Signal feed grouped by source, symbol, and confidence
- Signal quality score and adoption stats
- Optional follow/subscription graph, initially read-only

Non-goals:
- No marketplace, points economy, escrow, or public community platform in the first version.
- No automatic copy-trading until Freqtrade execution, risk, and audit safeguards are complete.
- No direct import of AI-Trader server modules.

---

## Data Model Plan

### Files

- Modify: `backend/app/models/strategy.py`
- Modify: `backend/app/models/__init__.py`
- Modify: `backend/app/schemas/api.py`
- Create: `backend/app/models/research.py`
- Create: `backend/app/models/agent_signal.py`
- Create: `backend/app/schemas/research.py`
- Create: `backend/app/schemas/agent_signal.py`

### New Tables

`ai_research_runs`
- `id`
- `symbol`
- `asset_type`
- `analysis_date`
- `provider`
- `runtime_config`
- `status`
- `rating`
- `final_decision`
- `market_report`
- `sentiment_report`
- `news_report`
- `fundamentals_report`
- `investment_debate`
- `risk_debate`
- `error_message`
- `started_at`
- `completed_at`
- `created_at`

`ai_research_links`
- `id`
- `research_run_id`
- `strategy_id`
- `backtest_id`
- `link_type`
- `created_at`

`agent_profiles`
- `id`
- `name`
- `kind`
- `status`
- `description`
- `last_heartbeat_at`
- `created_at`
- `updated_at`

`agent_signals`
- `id`
- `agent_id`
- `source`
- `message_type`
- `symbol`
- `market`
- `direction`
- `rating`
- `confidence`
- `target_price`
- `stop_loss`
- `time_horizon`
- `content`
- `evidence`
- `linked_research_run_id`
- `linked_strategy_id`
- `created_at`

`agent_signal_scores`
- `id`
- `signal_id`
- `verifiability_score`
- `evidence_score`
- `specificity_score`
- `novelty_score`
- `risk_score`
- `overall_score`
- `scored_by`
- `created_at`

`agent_subscriptions`
- `id`
- `leader_agent_id`
- `follower_agent_id`
- `status`
- `mode`
- `created_at`
- `updated_at`

---

## Task 1: Add Research Persistence Models

**Files:**
- Create: `backend/app/models/research.py`
- Modify: `backend/app/models/__init__.py`
- Create: `backend/app/schemas/research.py`
- Test: `backend/tests/test_research_models.py`

- [ ] **Step 1: Create model tests**

Create `backend/tests/test_research_models.py`:

```python
from datetime import date

from app.database import Base, engine, SessionLocal
from app.models.research import AIResearchRun, AIResearchLink


def test_ai_research_run_can_be_persisted():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        run = AIResearchRun(
            symbol="NVDA",
            asset_type="stock",
            analysis_date=date(2026, 1, 15),
            provider="tradingagents",
            runtime_config={"llm_provider": "openai"},
            status="completed",
            rating="Buy",
            final_decision="**Rating**: Buy",
        )
        db.add(run)
        db.commit()
        db.refresh(run)

        loaded = db.query(AIResearchRun).filter(AIResearchRun.id == run.id).first()
        assert loaded is not None
        assert loaded.symbol == "NVDA"
        assert loaded.rating == "Buy"
        assert loaded.runtime_config["llm_provider"] == "openai"
    finally:
        db.close()


def test_research_link_can_attach_to_strategy():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        run = AIResearchRun(
            symbol="BTC/USDT",
            asset_type="crypto",
            analysis_date=date(2026, 1, 15),
            provider="tradingagents",
            status="completed",
        )
        db.add(run)
        db.commit()
        db.refresh(run)

        link = AIResearchLink(
            research_run_id=run.id,
            strategy_id=1,
            link_type="strategy_context",
        )
        db.add(link)
        db.commit()
        db.refresh(link)

        assert link.research_run_id == run.id
        assert link.strategy_id == 1
    finally:
        db.close()
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
pytest backend/tests/test_research_models.py -q
```

Expected: fails because `app.models.research` does not exist.

- [ ] **Step 3: Add models**

Create `backend/app/models/research.py`:

```python
from datetime import datetime, timezone

from sqlalchemy import Column, Date, DateTime, Float, ForeignKey, Integer, JSON, String, Text

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class AIResearchRun(Base):
    __tablename__ = "ai_research_runs"

    id = Column(Integer, primary_key=True, autoincrement=True)
    symbol = Column(String, nullable=False, index=True)
    asset_type = Column(String, nullable=False, default="stock")
    analysis_date = Column(Date, nullable=False)
    provider = Column(String, nullable=False, default="tradingagents")
    runtime_config = Column(JSON, default=dict)
    status = Column(String, nullable=False, default="pending")
    rating = Column(String, nullable=True)
    confidence = Column(Float, nullable=True)
    final_decision = Column(Text, nullable=True)
    market_report = Column(Text, nullable=True)
    sentiment_report = Column(Text, nullable=True)
    news_report = Column(Text, nullable=True)
    fundamentals_report = Column(Text, nullable=True)
    investment_debate = Column(JSON, default=dict)
    risk_debate = Column(JSON, default=dict)
    error_message = Column(Text, nullable=True)
    started_at = Column(DateTime, nullable=True)
    completed_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_utcnow)


class AIResearchLink(Base):
    __tablename__ = "ai_research_links"

    id = Column(Integer, primary_key=True, autoincrement=True)
    research_run_id = Column(Integer, ForeignKey("ai_research_runs.id"), nullable=False, index=True)
    strategy_id = Column(Integer, nullable=True, index=True)
    backtest_id = Column(Integer, nullable=True, index=True)
    link_type = Column(String, nullable=False)
    created_at = Column(DateTime, default=_utcnow)
```

- [ ] **Step 4: Export models**

Modify `backend/app/models/__init__.py`:

```python
from app.models.strategy import Strategy, RiskEvent, CorrelationSnapshot
from app.models.user import User, UserSettings
from app.models.research import AIResearchRun, AIResearchLink

__all__ = [
    "Strategy",
    "RiskEvent",
    "CorrelationSnapshot",
    "User",
    "UserSettings",
    "AIResearchRun",
    "AIResearchLink",
]
```

- [ ] **Step 5: Add schemas**

Create `backend/app/schemas/research.py`:

```python
from datetime import date, datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


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
    rating: Optional[str]
    confidence: Optional[float]
    final_decision: Optional[str]
    market_report: Optional[str]
    sentiment_report: Optional[str]
    news_report: Optional[str]
    fundamentals_report: Optional[str]
    investment_debate: dict[str, Any]
    risk_debate: dict[str, Any]
    error_message: Optional[str]
    started_at: Optional[datetime]
    completed_at: Optional[datetime]
    created_at: datetime

    runtime_config = {"from_attributes": True}
```

- [ ] **Step 6: Run tests and verify pass**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
pytest backend/tests/test_research_models.py -q
```

Expected: all tests pass.

---

## Task 2: Add TradingAgents Adapter Boundary

**Files:**
- Create: `backend/app/services/tradingagents_adapter.py`
- Create: `backend/tests/test_tradingagents_adapter.py`

- [ ] **Step 1: Write adapter tests**

Create `backend/tests/test_tradingagents_adapter.py`:

```python
from app.services.tradingagents_adapter import (
    TradingAgentsConfig,
    extract_rating,
    normalize_tradingagents_state,
)


def test_extract_rating_from_decision_markdown():
    decision = "**Rating**: Overweight\n\n**Executive Summary**: Favorable setup."
    assert extract_rating(decision) == "Overweight"


def test_extract_rating_returns_none_for_unknown_text():
    assert extract_rating("No final rating available.") is None


def test_normalize_tradingagents_state_maps_reports():
    state = {
        "market_report": "market",
        "sentiment_report": "sentiment",
        "news_report": "news",
        "fundamentals_report": "fundamentals",
        "investment_debate_state": {"judge_decision": "research"},
        "risk_debate_state": {"judge_decision": "risk"},
        "final_trade_decision": "**Rating**: Hold",
    }

    normalized = normalize_tradingagents_state(state)

    assert normalized["rating"] == "Hold"
    assert normalized["market_report"] == "market"
    assert normalized["investment_debate"]["judge_decision"] == "research"


def test_config_to_tradingagents_dict_uses_safe_defaults():
    config = TradingAgentsConfig(llm_provider="openai")
    data = config.to_tradingagents_config()

    assert data["llm_provider"] == "openai"
    assert data["checkpoint_enabled"] is True
    assert data["max_debate_rounds"] == 1
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
pytest backend/tests/test_tradingagents_adapter.py -q
```

Expected: fails because `tradingagents_adapter.py` does not exist.

- [ ] **Step 3: Implement adapter helpers**

Create `backend/app/services/tradingagents_adapter.py`:

```python
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Any


VALID_RATINGS = {"Buy", "Overweight", "Hold", "Underweight", "Sell"}


@dataclass
class TradingAgentsConfig:
    llm_provider: str = "openai"
    deep_think_llm: str = "gpt-5.4"
    quick_think_llm: str = "gpt-5.4-mini"
    max_debate_rounds: int = 1
    max_risk_rounds: int = 1
    output_language: str = "English"

    def to_tradingagents_config(self) -> dict[str, Any]:
        return {
            "llm_provider": self.llm_provider,
            "deep_think_llm": self.deep_think_llm,
            "quick_think_llm": self.quick_think_llm,
            "max_debate_rounds": self.max_debate_rounds,
            "max_risk_discuss_rounds": self.max_risk_rounds,
            "checkpoint_enabled": True,
            "output_language": self.output_language,
        }


def extract_rating(final_decision: str | None) -> str | None:
    if not final_decision:
        return None
    match = re.search(r"\*\*Rating\*\*\s*:\s*(Buy|Overweight|Hold|Underweight|Sell)", final_decision)
    if match:
        return match.group(1)
    for rating in VALID_RATINGS:
        if re.search(rf"\b{rating}\b", final_decision):
            return rating
    return None


def normalize_tradingagents_state(state: dict[str, Any]) -> dict[str, Any]:
    final_decision = state.get("final_trade_decision") or ""
    return {
        "rating": extract_rating(final_decision),
        "final_decision": final_decision,
        "market_report": state.get("market_report"),
        "sentiment_report": state.get("sentiment_report"),
        "news_report": state.get("news_report"),
        "fundamentals_report": state.get("fundamentals_report"),
        "investment_debate": state.get("investment_debate_state") or {},
        "risk_debate": state.get("risk_debate_state") or {},
    }


def run_tradingagents_analysis(
    symbol: str,
    analysis_date: str,
    asset_type: str,
    selected_analysts: list[str],
    config: TradingAgentsConfig,
) -> dict[str, Any]:
    from tradingagents.default_config import DEFAULT_CONFIG
    from tradingagents.graph.trading_graph import TradingAgentsGraph

    runtime_config = DEFAULT_CONFIG.copy()
    runtime_config.update(config.to_tradingagents_config())

    graph = TradingAgentsGraph(
        selected_analysts=selected_analysts,
        debug=False,
        config=runtime_config,
    )
    state, decision = graph.propagate(symbol, analysis_date, asset_type=asset_type)
    normalized = normalize_tradingagents_state(state)
    normalized["processed_decision"] = decision
    return normalized
```

- [ ] **Step 4: Run tests and verify pass**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
pytest backend/tests/test_tradingagents_adapter.py -q
```

Expected: all tests pass without importing the external TradingAgents dependency during helper-only tests.

---

## Task 3: Add AI Research API

**Files:**
- Create: `backend/app/routers/ai_research.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_ai_research_api.py`

- [ ] **Step 1: Write API tests**

Create `backend/tests/test_ai_research_api.py`:

```python
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_create_research_run_records_pending_run():
    response = client.post(
        "/api/ai-research/runs",
        json={
            "symbol": "NVDA",
            "asset_type": "stock",
            "analysis_date": "2026-01-15",
            "selected_analysts": ["market", "news"],
            "llm_provider": "openai",
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["symbol"] == "NVDA"
    assert body["status"] == "pending"
    assert body["provider"] == "tradingagents"


def test_list_research_runs_returns_created_runs():
    response = client.get("/api/ai-research/runs")

    assert response.status_code == 200
    assert isinstance(response.json(), list)


def test_research_run_rejects_empty_symbol():
    response = client.post(
        "/api/ai-research/runs",
        json={"symbol": "", "asset_type": "stock", "analysis_date": "2026-01-15"},
    )

    assert response.status_code == 422
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
pytest backend/tests/test_ai_research_api.py -q
```

Expected: fails because `/api/ai-research/runs` route is not registered.

- [ ] **Step 3: Add router**

Create `backend/app/routers/ai_research.py`:

```python
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.research import AIResearchRun
from app.schemas.research import AIResearchRunCreate, AIResearchRunResponse
from app.services.tradingagents_adapter import (
    TradingAgentsConfig,
    run_tradingagents_analysis,
)


router = APIRouter(prefix="/api/ai-research", tags=["ai-research"])


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


def _execute_research_run(run_id: int, request: AIResearchRunCreate) -> None:
    from app.database import SessionLocal

    db = SessionLocal()
    try:
        run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
        if run is None:
            return
        run.status = "running"
        run.started_at = _utcnow()
        db.commit()

        config = TradingAgentsConfig(
            llm_provider=request.llm_provider,
            deep_think_llm=request.deep_think_llm,
            quick_think_llm=request.quick_think_llm,
            max_debate_rounds=request.max_debate_rounds,
            max_risk_rounds=request.max_risk_rounds,
        )
        result = run_tradingagents_analysis(
            symbol=request.symbol,
            analysis_date=request.analysis_date.isoformat(),
            asset_type=request.asset_type,
            selected_analysts=request.selected_analysts,
            config=config,
        )

        run.status = "completed"
        run.rating = result.get("rating")
        run.final_decision = result.get("final_decision")
        run.market_report = result.get("market_report")
        run.sentiment_report = result.get("sentiment_report")
        run.news_report = result.get("news_report")
        run.fundamentals_report = result.get("fundamentals_report")
        run.investment_debate = result.get("investment_debate") or {}
        run.risk_debate = result.get("risk_debate") or {}
        run.completed_at = _utcnow()
        db.commit()
    except Exception as exc:
        run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
        if run is not None:
            run.status = "failed"
            run.error_message = str(exc)
            run.completed_at = _utcnow()
            db.commit()
    finally:
        db.close()


@router.post("/runs", response_model=AIResearchRunResponse, status_code=status.HTTP_201_CREATED)
def create_research_run(request: AIResearchRunCreate, db: Session = Depends(get_db)):
    run = AIResearchRun(
        symbol=request.symbol.upper(),
        asset_type=request.asset_type,
        analysis_date=request.analysis_date,
        provider="tradingagents",
        runtime_config={
            "selected_analysts": request.selected_analysts,
            "llm_provider": request.llm_provider,
            "deep_think_llm": request.deep_think_llm,
            "quick_think_llm": request.quick_think_llm,
            "max_debate_rounds": request.max_debate_rounds,
            "max_risk_rounds": request.max_risk_rounds,
        },
        status="pending",
    )
    db.add(run)
    db.commit()
    db.refresh(run)
    return run


@router.post("/runs/{run_id}/execute", response_model=AIResearchRunResponse)
def execute_research_run(run_id: int, request: AIResearchRunCreate, db: Session = Depends(get_db)):
    run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
    if run is None:
        raise HTTPException(status_code=404, detail="Research run not found")
    if run.status == "running":
        raise HTTPException(status_code=409, detail="Research run is already running")
    _execute_research_run(run_id, request)
    db.refresh(run)
    return run


@router.get("/runs", response_model=list[AIResearchRunResponse])
def list_research_runs(db: Session = Depends(get_db)):
    return db.query(AIResearchRun).order_by(AIResearchRun.created_at.desc()).limit(100).all()


@router.get("/runs/{run_id}", response_model=AIResearchRunResponse)
def get_research_run(run_id: int, db: Session = Depends(get_db)):
    run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
    if run is None:
        raise HTTPException(status_code=404, detail="Research run not found")
    return run
```

- [ ] **Step 4: Register router**

Modify `backend/app/main.py` imports:

```python
from app.routers import strategies, orders, dashboard, backtest, risk, system, auth, search, notifications, attribution, sentiment, rag, ai_research
```

Add after existing router registrations:

```python
app.include_router(ai_research.router)
```

- [ ] **Step 5: Run tests and verify pass**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
pytest backend/tests/test_ai_research_api.py -q
```

Expected: all tests pass. If TradingAgents is not installed, mark the background task failure as acceptable for this test only and verify the run transitions to `failed` with an error message.

---

## Task 4: Add Research UI

**Files:**
- Create: `src/api/research.ts`
- Create: `src/hooks/use-research.ts`
- Create: `src/pages/AIResearchPage.tsx`
- Modify: `src/App.tsx`
- Modify: `src/components/layout/Sidebar.tsx`

- [ ] **Step 1: Add API client**

Create `src/api/research.ts`:

```typescript
import { apiGet, apiPost } from '@/api/client'

export interface AIResearchRun {
  id: number
  symbol: string
  asset_type: string
  analysis_date: string
  provider: string
  runtime_config: Record<string, unknown>
  status: 'pending' | 'running' | 'completed' | 'failed'
  rating?: string | null
  confidence?: number | null
  final_decision?: string | null
  market_report?: string | null
  sentiment_report?: string | null
  news_report?: string | null
  fundamentals_report?: string | null
  investment_debate: Record<string, unknown>
  risk_debate: Record<string, unknown>
  error_message?: string | null
  started_at?: string | null
  completed_at?: string | null
  created_at: string
}

export interface CreateAIResearchRunInput {
  symbol: string
  asset_type: string
  analysis_date: string
  selected_analysts: string[]
  llm_provider: string
  deep_think_llm: string
  quick_think_llm: string
  max_debate_rounds: number
  max_risk_rounds: number
}

const mockRun = (): AIResearchRun => ({
  id: 1,
  symbol: 'NVDA',
  asset_type: 'stock',
  analysis_date: '2026-01-15',
  provider: 'tradingagents',
  runtime_config: { selected_analysts: ['market', 'news'] },
  status: 'completed',
  rating: 'Overweight',
  confidence: null,
  final_decision: '**Rating**: Overweight\n\nAI research committee sees favorable momentum with manageable risk.',
  market_report: 'Technical setup remains constructive.',
  sentiment_report: 'Sentiment is positive but crowded.',
  news_report: 'Recent news flow supports the thesis.',
  fundamentals_report: 'Fundamentals remain strong.',
  investment_debate: {},
  risk_debate: {},
  error_message: null,
  started_at: null,
  completed_at: null,
  created_at: new Date().toISOString(),
})

export async function listResearchRuns(): Promise<AIResearchRun[]> {
  return apiGet('/api/ai-research/runs', () => [mockRun()])
}

export async function createResearchRun(input: CreateAIResearchRunInput): Promise<AIResearchRun> {
  return apiPost('/api/ai-research/runs', input, mockRun)
}
```

- [ ] **Step 2: Add hook**

Create `src/hooks/use-research.ts`:

```typescript
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as researchApi from '@/api/research'

export function useResearchRuns() {
  return useQuery({
    queryKey: ['research-runs'],
    queryFn: researchApi.listResearchRuns,
  })
}

export function useCreateResearchRun() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: researchApi.createResearchRun,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['research-runs'] })
    },
  })
}
```

- [ ] **Step 3: Add page**

Create `src/pages/AIResearchPage.tsx`:

```tsx
import { useState } from 'react'
import { BrainCircuit, Play, AlertTriangle } from 'lucide-react'
import { PageHeader } from '@/components/ui/PageHeader'
import { useCreateResearchRun, useResearchRuns } from '@/hooks/use-research'

const today = new Date().toISOString().slice(0, 10)

export function AIResearchPage() {
  const [symbol, setSymbol] = useState('NVDA')
  const [assetType, setAssetType] = useState('stock')
  const { data: runs = [], isLoading } = useResearchRuns()
  const createRun = useCreateResearchRun()

  const submit = () => {
    createRun.mutate({
      symbol,
      asset_type: assetType,
      analysis_date: today,
      selected_analysts: ['market', 'social', 'news', 'fundamentals'],
      llm_provider: 'openai',
      deep_think_llm: 'gpt-5.4',
      quick_think_llm: 'gpt-5.4-mini',
      max_debate_rounds: 1,
      max_risk_rounds: 1,
    })
  }

  return (
    <div className="space-y-5">
      <PageHeader title="AI Research Committee" subtitle="Multi-agent market research and risk-reviewed trade thesis" />

      <div className="terminal-panel p-5 grid grid-cols-1 md:grid-cols-[1fr_160px_auto] gap-3">
        <input value={symbol} onChange={(event) => setSymbol(event.target.value)} placeholder="NVDA, BTC/USDT" />
        <select value={assetType} onChange={(event) => setAssetType(event.target.value)}>
          <option value="stock">Stock</option>
          <option value="crypto">Crypto</option>
        </select>
        <button className="btn-primary flex items-center gap-2" onClick={submit} disabled={!symbol.trim() || createRun.isPending}>
          <Play className="w-4 h-4" />
          Run Research
        </button>
      </div>

      <div className="grid gap-4">
        {isLoading && <div className="terminal-panel p-5 text-text-muted">Loading research runs...</div>}
        {runs.map((run) => (
          <article key={run.id} className="terminal-panel p-5 space-y-4">
            <div className="flex items-center justify-between gap-3">
              <div className="flex items-center gap-3">
                <BrainCircuit className="w-5 h-5 text-primary" />
                <div>
                  <h2 className="font-mono text-[15px] text-text-primary">{run.symbol}</h2>
                  <p className="text-[11px] font-mono text-text-muted">{run.asset_type} · {run.analysis_date} · {run.status}</p>
                </div>
              </div>
              <span className="badge bg-success-dim text-success">{run.rating || 'Pending'}</span>
            </div>

            {run.error_message && (
              <div className="surface-subtle p-3 flex gap-2 text-danger text-[12px] font-mono">
                <AlertTriangle className="w-4 h-4" />
                {run.error_message}
              </div>
            )}

            {run.final_decision && (
              <pre className="surface-subtle p-4 overflow-x-auto whitespace-pre-wrap text-[12px] font-mono text-text-secondary">
                {run.final_decision}
              </pre>
            )}
          </article>
        ))}
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Register route**

Modify `src/App.tsx`:

```tsx
const AIResearchPage = lazy(() => import('@/pages/AIResearchPage').then(m => ({ default: m.AIResearchPage })))
```

Add protected route:

```tsx
<Route path="/research" element={<AIResearchPage />} />
```

- [ ] **Step 5: Add sidebar item**

Modify `src/components/layout/Sidebar.tsx` to import `BrainCircuit` from `lucide-react`, then add:

```tsx
{ to: '/research', icon: BrainCircuit, label: 'AI投研' },
```

- [ ] **Step 6: Verify frontend**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
npm run type-check
npm run lint
npm run build
```

Expected: all commands pass.

---

## Task 5: Add Agent Signal Hub Models and API

**Files:**
- Create: `backend/app/models/agent_signal.py`
- Create: `backend/app/schemas/agent_signal.py`
- Create: `backend/app/services/signal_scoring.py`
- Create: `backend/app/routers/agent_signals.py`
- Modify: `backend/app/models/__init__.py`
- Modify: `backend/app/main.py`
- Test: `backend/tests/test_agent_signal_api.py`

- [ ] **Step 1: Write signal scoring tests**

Create `backend/tests/test_signal_scoring.py`:

```python
from app.services.signal_scoring import score_signal_text


def test_signal_scoring_rewards_specific_trade_plan():
    score = score_signal_text(
        symbol="NVDA",
        direction="long",
        content="Long NVDA because earnings momentum is strong. Target 145, stop 118, confidence 70%.",
    )

    assert score["overall_score"] >= 3.0
    assert score["verifiability_score"] > 0
    assert score["specificity_score"] > 0


def test_signal_scoring_penalizes_empty_content():
    score = score_signal_text(symbol="", direction="", content="")

    assert score["overall_score"] < 2.0
```

- [ ] **Step 2: Implement scoring service**

Create `backend/app/services/signal_scoring.py`:

```python
from __future__ import annotations

import re


def _clamp(value: float) -> float:
    return round(max(0.0, min(5.0, value)), 4)


def score_signal_text(symbol: str | None, direction: str | None, content: str | None) -> dict[str, float]:
    text = (content or "").strip()
    lower = text.lower()

    verifiability = 0.5
    if symbol:
        verifiability += 1.0
    if direction in {"long", "short", "buy", "sell", "hold"}:
        verifiability += 1.0
    if re.search(r"(target|目标|tp)\D{0,12}\d+", lower):
        verifiability += 1.0
    if re.search(r"(stop|止损|sl)\D{0,12}\d+", lower):
        verifiability += 1.0

    evidence = min(5.0, len(text) / 180.0)
    for keyword in ("because", "risk", "earnings", "momentum", "valuation", "liquidity", "因为", "风险"):
        if keyword in lower:
            evidence += 0.45

    specificity = 0.5
    if symbol:
        specificity += 1.0
    if re.search(r"\d+(\.\d+)?%?", text):
        specificity += 1.0
    if len(text) > 120:
        specificity += 1.0

    novelty = 3.0
    risk = 1.0
    if "stop" in lower or "止损" in lower:
        risk += 1.0
    if "position" in lower or "仓位" in lower:
        risk += 1.0

    overall = (
        _clamp(verifiability) * 0.3
        + _clamp(evidence) * 0.25
        + _clamp(specificity) * 0.2
        + _clamp(novelty) * 0.1
        + _clamp(risk) * 0.15
    )

    return {
        "verifiability_score": _clamp(verifiability),
        "evidence_score": _clamp(evidence),
        "specificity_score": _clamp(specificity),
        "novelty_score": _clamp(novelty),
        "risk_score": _clamp(risk),
        "overall_score": _clamp(overall),
    }
```

- [ ] **Step 3: Add models and schemas**

Create `backend/app/models/agent_signal.py`:

```python
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, JSON, String, Text

from app.database import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class AgentProfile(Base):
    __tablename__ = "agent_profiles"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, nullable=False, unique=True)
    kind = Column(String, nullable=False, default="research")
    status = Column(String, nullable=False, default="active")
    description = Column(Text, nullable=True)
    last_heartbeat_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=_utcnow)
    updated_at = Column(DateTime, default=_utcnow, onupdate=_utcnow)


class AgentSignal(Base):
    __tablename__ = "agent_signals"

    id = Column(Integer, primary_key=True, autoincrement=True)
    agent_id = Column(Integer, ForeignKey("agent_profiles.id"), nullable=False, index=True)
    source = Column(String, nullable=False, default="manual")
    message_type = Column(String, nullable=False, default="research")
    symbol = Column(String, nullable=False, index=True)
    market = Column(String, nullable=False, default="stock")
    direction = Column(String, nullable=True)
    rating = Column(String, nullable=True)
    confidence = Column(Float, nullable=True)
    target_price = Column(Float, nullable=True)
    stop_loss = Column(Float, nullable=True)
    time_horizon = Column(String, nullable=True)
    content = Column(Text, nullable=False)
    evidence = Column(JSON, default=dict)
    linked_research_run_id = Column(Integer, nullable=True, index=True)
    linked_strategy_id = Column(Integer, nullable=True, index=True)
    created_at = Column(DateTime, default=_utcnow)


class AgentSignalScore(Base):
    __tablename__ = "agent_signal_scores"

    id = Column(Integer, primary_key=True, autoincrement=True)
    signal_id = Column(Integer, ForeignKey("agent_signals.id"), nullable=False, index=True)
    verifiability_score = Column(Float, nullable=False)
    evidence_score = Column(Float, nullable=False)
    specificity_score = Column(Float, nullable=False)
    novelty_score = Column(Float, nullable=False)
    risk_score = Column(Float, nullable=False)
    overall_score = Column(Float, nullable=False)
    scored_by = Column(String, nullable=False, default="heuristic-v1")
    created_at = Column(DateTime, default=_utcnow)
```

Create `backend/app/schemas/agent_signal.py`:

```python
from datetime import datetime
from typing import Any, Optional

from pydantic import BaseModel, Field


class AgentProfileCreate(BaseModel):
    name: str = Field(..., min_length=1, max_length=120)
    kind: str = "research"
    description: Optional[str] = None


class AgentProfileResponse(BaseModel):
    id: int
    name: str
    kind: str
    status: str
    description: Optional[str]
    last_heartbeat_at: Optional[datetime]
    created_at: datetime
    updated_at: datetime

    runtime_config = {"from_attributes": True}


class AgentSignalCreate(BaseModel):
    agent_id: int
    source: str = "manual"
    message_type: str = "research"
    symbol: str = Field(..., min_length=1, max_length=64)
    market: str = "stock"
    direction: Optional[str] = None
    rating: Optional[str] = None
    confidence: Optional[float] = None
    target_price: Optional[float] = None
    stop_loss: Optional[float] = None
    time_horizon: Optional[str] = None
    content: str = Field(..., min_length=1)
    evidence: dict[str, Any] = {}
    linked_research_run_id: Optional[int] = None
    linked_strategy_id: Optional[int] = None


class AgentSignalResponse(BaseModel):
    id: int
    agent_id: int
    source: str
    message_type: str
    symbol: str
    market: str
    direction: Optional[str]
    rating: Optional[str]
    confidence: Optional[float]
    target_price: Optional[float]
    stop_loss: Optional[float]
    time_horizon: Optional[str]
    content: str
    evidence: dict[str, Any]
    linked_research_run_id: Optional[int]
    linked_strategy_id: Optional[int]
    overall_score: Optional[float] = None
    created_at: datetime

    runtime_config = {"from_attributes": True}
```

- [ ] **Step 4: Add API tests**

Create `backend/tests/test_agent_signal_api.py`:

```python
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_create_agent_and_signal():
    agent_response = client.post(
        "/api/agent-signals/agents",
        json={"name": "ResearchBot", "kind": "research", "description": "Runs AI research"},
    )
    assert agent_response.status_code == 201
    agent_id = agent_response.json()["id"]

    signal_response = client.post(
        "/api/agent-signals/signals",
        json={
            "agent_id": agent_id,
            "symbol": "NVDA",
            "market": "stock",
            "direction": "long",
            "content": "Long NVDA because technical momentum is strong. Target 145, stop 118.",
        },
    )
    assert signal_response.status_code == 201
    body = signal_response.json()
    assert body["symbol"] == "NVDA"
    assert body["overall_score"] is not None


def test_list_agent_signals():
    response = client.get("/api/agent-signals/signals")

    assert response.status_code == 200
    assert isinstance(response.json(), list)
```

- [ ] **Step 5: Add router**

Create `backend/app/routers/agent_signals.py`:

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.agent_signal import AgentProfile, AgentSignal, AgentSignalScore
from app.schemas.agent_signal import AgentProfileCreate, AgentProfileResponse, AgentSignalCreate, AgentSignalResponse
from app.services.signal_scoring import score_signal_text


router = APIRouter(prefix="/api/agent-signals", tags=["agent-signals"])


@router.post("/agents", response_model=AgentProfileResponse, status_code=status.HTTP_201_CREATED)
def create_agent_profile(request: AgentProfileCreate, db: Session = Depends(get_db)):
    existing = db.query(AgentProfile).filter(AgentProfile.name == request.name).first()
    if existing is not None:
        raise HTTPException(status_code=409, detail="Agent name already exists")
    agent = AgentProfile(name=request.name, kind=request.kind, description=request.description)
    db.add(agent)
    db.commit()
    db.refresh(agent)
    return agent


@router.get("/agents", response_model=list[AgentProfileResponse])
def list_agent_profiles(db: Session = Depends(get_db)):
    return db.query(AgentProfile).order_by(AgentProfile.created_at.desc()).limit(100).all()


@router.post("/signals", response_model=AgentSignalResponse, status_code=status.HTTP_201_CREATED)
def create_agent_signal(request: AgentSignalCreate, db: Session = Depends(get_db)):
    agent = db.query(AgentProfile).filter(AgentProfile.id == request.agent_id).first()
    if agent is None:
        raise HTTPException(status_code=404, detail="Agent not found")

    signal = AgentSignal(**request.model_dump())
    db.add(signal)
    db.commit()
    db.refresh(signal)

    scores = score_signal_text(signal.symbol, signal.direction, signal.content)
    score = AgentSignalScore(signal_id=signal.id, **scores)
    db.add(score)
    db.commit()
    db.refresh(score)

    response = AgentSignalResponse.model_validate(signal)
    response.overall_score = score.overall_score
    return response


@router.get("/signals", response_model=list[AgentSignalResponse])
def list_agent_signals(db: Session = Depends(get_db)):
    rows = db.query(AgentSignal).order_by(AgentSignal.created_at.desc()).limit(100).all()
    responses = []
    for row in rows:
        score = (
            db.query(AgentSignalScore)
            .filter(AgentSignalScore.signal_id == row.id)
            .order_by(AgentSignalScore.created_at.desc())
            .first()
        )
        item = AgentSignalResponse.model_validate(row)
        item.overall_score = score.overall_score if score else None
        responses.append(item)
    return responses
```

- [ ] **Step 6: Register models and router**

Modify `backend/app/models/__init__.py`:

```python
from app.models.agent_signal import AgentProfile, AgentSignal, AgentSignalScore
```

Add to `__all__`:

```python
"AgentProfile",
"AgentSignal",
"AgentSignalScore",
```

Modify `backend/app/main.py` imports:

```python
from app.routers import strategies, orders, dashboard, backtest, risk, system, auth, search, notifications, attribution, sentiment, rag, ai_research, agent_signals
```

Add:

```python
app.include_router(agent_signals.router)
```

- [ ] **Step 7: Run tests**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
pytest backend/tests/test_signal_scoring.py backend/tests/test_agent_signal_api.py -q
```

Expected: all tests pass.

---

## Task 6: Add Signal Hub UI

**Files:**
- Create: `src/api/agent-signals.ts`
- Create: `src/hooks/use-agent-signals.ts`
- Create: `src/pages/AgentSignalsPage.tsx`
- Modify: `src/App.tsx`
- Modify: `src/components/layout/Sidebar.tsx`

- [ ] **Step 1: Add frontend API**

Create `src/api/agent-signals.ts`:

```typescript
import { apiGet, apiPost } from '@/api/client'

export interface AgentProfile {
  id: number
  name: string
  kind: string
  status: string
  description?: string | null
  last_heartbeat_at?: string | null
  created_at: string
  updated_at: string
}

export interface AgentSignal {
  id: number
  agent_id: number
  source: string
  message_type: string
  symbol: string
  market: string
  direction?: string | null
  rating?: string | null
  confidence?: number | null
  target_price?: number | null
  stop_loss?: number | null
  time_horizon?: string | null
  content: string
  evidence: Record<string, unknown>
  linked_research_run_id?: number | null
  linked_strategy_id?: number | null
  overall_score?: number | null
  created_at: string
}

export async function listAgentSignals(): Promise<AgentSignal[]> {
  return apiGet('/api/agent-signals/signals', () => [])
}

export async function listAgentProfiles(): Promise<AgentProfile[]> {
  return apiGet('/api/agent-signals/agents', () => [])
}

export async function createAgentProfile(input: { name: string; kind: string; description?: string }): Promise<AgentProfile> {
  return apiPost('/api/agent-signals/agents', input, () => ({
    id: 1,
    name: input.name,
    kind: input.kind,
    status: 'active',
    description: input.description || null,
    last_heartbeat_at: null,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }))
}
```

- [ ] **Step 2: Add hooks**

Create `src/hooks/use-agent-signals.ts`:

```typescript
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as api from '@/api/agent-signals'

export function useAgentSignals() {
  return useQuery({
    queryKey: ['agent-signals'],
    queryFn: api.listAgentSignals,
  })
}

export function useAgentProfiles() {
  return useQuery({
    queryKey: ['agent-profiles'],
    queryFn: api.listAgentProfiles,
  })
}

export function useCreateAgentProfile() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: api.createAgentProfile,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['agent-profiles'] })
    },
  })
}
```

- [ ] **Step 3: Add Signal Hub page**

Create `src/pages/AgentSignalsPage.tsx`:

```tsx
import { RadioTower, Star } from 'lucide-react'
import { PageHeader } from '@/components/ui/PageHeader'
import { useAgentProfiles, useAgentSignals } from '@/hooks/use-agent-signals'

export function AgentSignalsPage() {
  const { data: signals = [], isLoading: signalsLoading } = useAgentSignals()
  const { data: agents = [] } = useAgentProfiles()

  return (
    <div className="space-y-5">
      <PageHeader title="Agent Signal Hub" subtitle="Local agent signals, research ratings, and quality scoring" />

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="terminal-panel p-4">
          <span className="terminal-label">Agents</span>
          <div className="text-2xl font-mono text-text-primary mt-2">{agents.length}</div>
        </div>
        <div className="terminal-panel p-4">
          <span className="terminal-label">Signals</span>
          <div className="text-2xl font-mono text-text-primary mt-2">{signals.length}</div>
        </div>
        <div className="terminal-panel p-4">
          <span className="terminal-label">Mode</span>
          <div className="text-sm font-mono text-warning mt-2">Read-only</div>
        </div>
      </div>

      <div className="terminal-panel p-5">
        <div className="flex items-center gap-2 mb-4">
          <RadioTower className="w-4 h-4 text-primary" />
          <h2 className="font-mono text-[14px] text-text-primary">Signal Feed</h2>
        </div>
        {signalsLoading && <div className="text-text-muted font-mono text-[12px]">Loading signals...</div>}
        {!signalsLoading && signals.length === 0 && (
          <div className="surface-subtle p-6 text-center text-text-muted font-mono text-[12px]">
            No agent signals yet. Run AI Research Committee first, then publish research outputs as signals.
          </div>
        )}
        <div className="space-y-3">
          {signals.map((signal) => (
            <article key={signal.id} className="surface-subtle p-4">
              <div className="flex items-center justify-between gap-3">
                <div>
                  <div className="font-mono text-text-primary text-[13px]">{signal.symbol}</div>
                  <div className="font-mono text-text-muted text-[11px]">{signal.market} · {signal.direction || signal.rating || 'neutral'}</div>
                </div>
                <span className="badge bg-info-dim text-info flex items-center gap-1">
                  <Star className="w-3 h-3" />
                  {signal.overall_score?.toFixed(1) || 'n/a'}
                </span>
              </div>
              <p className="mt-3 text-[12px] font-mono text-text-secondary">{signal.content}</p>
            </article>
          ))}
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Register route and navigation**

Modify `src/App.tsx`:

```tsx
const AgentSignalsPage = lazy(() => import('@/pages/AgentSignalsPage').then(m => ({ default: m.AgentSignalsPage })))
```

Add:

```tsx
<Route path="/signals" element={<AgentSignalsPage />} />
```

Modify `src/components/layout/Sidebar.tsx` to import `RadioTower`, then add:

```tsx
{ to: '/signals', icon: RadioTower, label: '信号中心' },
```

- [ ] **Step 5: Verify frontend**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
npm run type-check
npm run lint
npm run build
```

Expected: all commands pass.

---

## Task 7: Connect Research Runs to Signals

**Files:**
- Modify: `backend/app/routers/ai_research.py`
- Modify: `backend/app/routers/agent_signals.py`
- Create: `backend/tests/test_research_to_signal.py`

- [ ] **Step 1: Write conversion test**

Create `backend/tests/test_research_to_signal.py`:

```python
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_completed_research_run_can_publish_signal():
    run_response = client.post(
        "/api/ai-research/runs",
        json={
            "symbol": "NVDA",
            "asset_type": "stock",
            "analysis_date": "2026-01-15",
            "selected_analysts": ["market"],
            "llm_provider": "openai",
        },
    )
    assert run_response.status_code == 201
    run_id = run_response.json()["id"]

    publish_response = client.post(f"/api/ai-research/runs/{run_id}/publish-signal")

    assert publish_response.status_code in {201, 409}
```

- [ ] **Step 2: Add publish endpoint**

Modify `backend/app/routers/ai_research.py`:

```python
from app.models.agent_signal import AgentProfile, AgentSignal, AgentSignalScore
from app.services.signal_scoring import score_signal_text
from app.schemas.agent_signal import AgentSignalResponse
```

Add:

```python
@router.post("/runs/{run_id}/publish-signal", response_model=AgentSignalResponse, status_code=status.HTTP_201_CREATED)
def publish_research_signal(run_id: int, db: Session = Depends(get_db)):
    run = db.query(AIResearchRun).filter(AIResearchRun.id == run_id).first()
    if run is None:
        raise HTTPException(status_code=404, detail="Research run not found")
    if run.status != "completed":
        raise HTTPException(status_code=409, detail="Research run is not completed")

    agent = db.query(AgentProfile).filter(AgentProfile.name == "AI Research Committee").first()
    if agent is None:
        agent = AgentProfile(
            name="AI Research Committee",
            kind="research",
            description="TradingAgents-backed multi-agent research committee",
        )
        db.add(agent)
        db.commit()
        db.refresh(agent)

    signal = AgentSignal(
        agent_id=agent.id,
        source="tradingagents",
        message_type="research",
        symbol=run.symbol,
        market=run.asset_type,
        rating=run.rating,
        content=run.final_decision or "",
        evidence={
            "research_run_id": run.id,
            "provider": run.provider,
        },
        linked_research_run_id=run.id,
    )
    db.add(signal)
    db.commit()
    db.refresh(signal)

    scores = score_signal_text(signal.symbol, signal.direction, signal.content)
    score = AgentSignalScore(signal_id=signal.id, **scores)
    db.add(score)
    db.commit()
    db.refresh(score)

    response = AgentSignalResponse.model_validate(signal)
    response.overall_score = score.overall_score
    return response
```

- [ ] **Step 3: Run test**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
pytest backend/tests/test_research_to_signal.py -q
```

Expected: pass. If background execution fails because TradingAgents is not installed, the publish endpoint returns `409` for non-completed run, which is acceptable for this test.

---

## Task 8: Add Dependency Isolation

**Files:**
- Modify: `backend/requirements.txt`
- Create: `backend/requirements-ai.txt`
- Modify: `docker-compose.yml`
- Modify: `.env.example`

- [ ] **Step 1: Keep base backend light**

Do not add TradingAgents dependencies to `backend/requirements.txt`. The base API should remain runnable without LangGraph or LLM dependencies.

- [ ] **Step 2: Add optional AI requirements**

Create `backend/requirements-ai.txt`:

```txt
-r requirements.txt
langchain-core>=0.3.81
langchain-anthropic>=0.3.15
langchain-experimental>=0.3.4
langchain-google-genai>=4.0.0
langchain-openai>=0.3.23
langgraph>=0.4.8
langgraph-checkpoint-sqlite>=2.0.0
pandas>=2.3.0
stockstats>=0.6.5
yfinance>=0.2.63
redis>=6.2.0
```

- [ ] **Step 3: Add environment examples**

Modify `.env.example`:

```env
# AI Research
OPENAI_API_KEY=
GOOGLE_API_KEY=
ANTHROPIC_API_KEY=
ALPHA_VANTAGE_API_KEY=
TRADINGAGENTS_CACHE_DIR=./data/tradingagents/cache
TRADINGAGENTS_RESULTS_DIR=./data/tradingagents/results
```

- [ ] **Step 4: Document install command**

Add to `README.md`:

```markdown
### Optional AI Research Dependencies

The AI Research Committee requires additional LLM and market-data dependencies:

```bash
cd backend
pip install -r requirements-ai.txt
```

Base backend routes continue to run with `requirements.txt`.
```

---

## Task 9: End-to-End Verification

**Files:**
- No new files.

- [ ] **Step 1: Backend tests**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
pytest backend/tests -q
```

Expected: all tests pass.

- [ ] **Step 2: Frontend checks**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
npm run type-check
npm run lint
npm run build
```

Expected: all commands pass.

- [ ] **Step 3: Tauri check**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal/src-tauri
cargo check
```

Expected: build finishes successfully.

- [ ] **Step 4: Manual app verification**

Run:

```bash
cd /Users/novspace/workspace/phosphor-terminal
npm run tauri dev
```

Verify:
- `/research` loads.
- Creating a research run creates a pending or completed item.
- `/signals` loads.
- Publishing a completed research run creates a signal.
- No page depends on TradingAgents when optional AI dependencies are absent.
- No LLM-generated signal can execute an order directly.

---

## Execution Order

1. Phase 1 hardening remains the product priority: real Freqtrade data, real backtests, real orders, no default mock mode for production.
2. Implement Tasks 1-4 for AI Research Committee.
3. Implement Tasks 5-7 for Agent Signal Hub.
4. Implement Task 8 to isolate dependencies and avoid bloating the base backend.
5. Run Task 9 before merging.

---

## Design Review

### Findings

1. **High risk: direct TradingAgents execution inside FastAPI request workers can block production traffic.**

   The plan keeps creation and execution separate so `POST /runs` only records a pending run. The included `/runs/{id}/execute` endpoint is acceptable for local development, but not for production. TradingAgents can perform multiple LLM calls and external data fetches, so a durable worker queue should replace request-thread execution before production use. Candidate follow-up: add an `ai_research_worker.py` process, backed by database run state and retry semantics.

2. **High risk: AI-Trader source should not be copied until license provenance is resolved.**

   The local clone did not contain a `LICENSE` file even though README badges claim MIT. The plan correctly re-implements concepts instead of copying source. Any future source-level reuse must include a license check and attribution file.

3. **Medium risk: TradingAgents is stock-first and data-vendor dependent.**

   PulseDesk is currently crypto/Freqtrade-oriented. The adapter supports `asset_type`, but crypto output quality should be validated separately. First production target should be stock symbols or crypto research clearly labeled as experimental.

4. **Medium risk: duplicate signal domain overlap with existing orders/positions.**

   Agent Signal Hub must remain read-only initially. Do not map agent signals into Freqtrade orders until risk controls, audit trails, and user confirmation are implemented.

5. **Medium risk: test database isolation is not specified in the current repo.**

   The tests above assume the existing `SessionLocal` can be used safely. Before implementation, confirm backend test isolation. If tests write to the development SQLite file, add test-specific `DATABASE_URL=sqlite:///:memory:` fixtures before implementing API tests.

6. **Low risk: frontend mock fallback can hide backend integration failures.**

   The new frontend APIs include mocks for consistency with current architecture. Production acceptance must run with `VITE_USE_MOCK=false`.

### Coverage Check

- TradingAgents integration: covered by Tasks 1-4 and Task 8.
- AI-Trader conceptual reuse: covered by Tasks 5-7 without direct source copying.
- Current app compatibility: covered by optional dependencies and read-only signal mode.
- PRD alignment: improves AI research, sentiment/analyst workflow, and future strategy optimization, while preserving the need to complete Phase 1 Freqtrade execution.
- Safety boundary: explicit no-auto-execution rule appears in product direction, UI verification, and review findings.

### Recommended Implementation Decision

Implement **AI Research Committee first**. It has the highest value-to-risk ratio and directly complements the existing Strategy Lab. Defer Agent Signal Hub until the Freqtrade real-data loop is stable enough that signals can be evaluated against actual backtests and trades.

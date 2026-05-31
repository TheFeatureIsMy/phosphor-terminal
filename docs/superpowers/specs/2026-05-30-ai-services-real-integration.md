# AI/ML Services Real Integration — Design Spec

**Date:** 2026-05-30
**Status:** Draft
**Goal:** Replace all deterministic simulation adapters with real AI/ML implementations. Support multiple AI providers (local + cloud) with a unified management interface.

---

## 1. Design Principles

1. **Direct run first**: `python run.py` is the primary way to start. Docker is optional for deployment.
2. **Multi-provider LLM**: Support OpenAI, Anthropic, DeepSeek, Ollama (local), vLLM (local) — user chooses in settings.
3. **Lazy model loading**: ML models (FinBERT, Chronos, etc.) download/load on first request, not at startup.
4. **Graceful degradation**: If model fails to load, fall back to heuristic with clear UI indicator.
5. **Progressive enhancement**: Deterministic → Heuristic → ML Model → LLM (each upgrade is optional).
6. **No mandatory API keys**: Core functionality works without any API keys. LLM features are opt-in.
7. **Adapter boundary preserved**: Existing class interfaces stay the same, only implementations change.

---

## 1.1 Deployment Options

| Method | Command | When to use |
|--------|---------|-------------|
| **Direct run** | `pip install -r requirements.txt && python run.py` | Development, local use |
| **Docker** | `docker compose up` | Production, CI/CD, reproducible environment |
| **macOS App** | `swift run` (calls backend API) | Desktop users |

**Ollama (local LLM):** Install with `brew install ollama && ollama pull qwen2.5:7b`, or use Docker: `docker run -d -p 11434:11434 ollama/ollama`.

---

## 2. Service Tiers

### Tier 1: Quick Wins (1-2 files each, swap body only)

| Service | Current | Target | Effort |
|---------|---------|--------|--------|
| FinBERT Sentiment | Keyword matching | HuggingFace pipeline | Low |
| Chronos Forecast | "unavailable" fallback | Already functional, fix orchestrator | Low |
| TimesFM Forecast | context_len bug | Fix bug, real forecast | Low |
| Forecast Orchestrator | Synthetic fallback | Real data source + remove fallback | Low |
| Signal Scoring | Heuristic (keep) | Optional LLM upgrade | Low |

### Tier 2: Medium Effort (new dependencies, moderate refactoring)

| Service | Current | Target | Effort |
|---------|---------|--------|--------|
| SHAP Attribution | Seeded random | shap lib + trained LightGBM model | Medium |
| FreqAI Training | Simulated loop | Real LightGBM/XGBoost training | Medium-High |
| Market Data Feed | Random fallback | CCXT real-time + SQLite cache | Medium |

### Tier 3: Heavy Lift (significant new infrastructure)

| Service | Current | Target | Effort |
|---------|---------|--------|--------|
| RAG Strategy Gen | Template matching | Ollama + ChromaDB + pdfplumber | High |
| Factor Research (multi-market) | CN stock mismatch | Market-aware backends (crypto/A-share/US) | High |
| TradingAgents | ImportError | Optional OpenAI integration | Medium |

---

## 3. Detailed Implementation Plan

### 3.1 FinBERT Sentiment (Tier 1)

**File:** `backend/app/services/sentiment_finbert.py`

**Current:** `FinBERTAdapter.analyze_text()` uses keyword matching with 16 words.

**Change:**
```python
class FinBERTAdapter:
    _pipeline = None
    _load_failed = False

    def _get_pipeline(self):
        if self._pipeline is None and not self._load_failed:
            try:
                from transformers import pipeline
                self._pipeline = pipeline(
                    "sentiment-analysis",
                    model="ProsusAI/finbert",
                    top_k=None  # return all 3 labels
                )
            except Exception:
                self._load_failed = True
        return self._pipeline

    def analyze_text(self, text: str) -> dict:
        pipe = self._get_pipeline()
        if pipe is None:
            return self._keyword_fallback(text)

        results = pipe(text[:512])[0]  # truncate to 512 tokens
        scores = {r["label"]: r["score"] for r in results}
        score = scores.get("positive", 0) - scores.get("negative", 0)
        label = "positive" if score > 0.2 else "negative" if score < -0.2 else "neutral"
        return {"score": round(score, 4), "label": label, "confidence": round(max(scores.values()), 4), "model": "finbert"}

    def _keyword_fallback(self, text: str) -> dict:
        # existing keyword logic, add model: "keyword_fallback"
        ...
```

**Dependencies:** Already in requirements.txt (`transformers`, `torch`)
**Model:** ~440MB, downloads on first use via HuggingFace cache
**First-request latency:** ~30s (download) + ~2s (load) + ~0.5s (inference)
**Subsequent requests:** ~0.3-0.5s each

---

### 3.2 Chronos Forecast (Tier 1)

**File:** `backend/app/services/forecast_adapters.py`

**Current:** Already functional, loads `amazon/chronos-t5-tiny`. Just needs orchestrator to stop falling through.

**Change:** In `forecasting.py`, remove `_deterministic_fallback` path when Chronos is available. The Chronos adapter itself needs no changes.

**Fix in orchestrator:**
```python
async def generate_forecast(symbol, model="chronos", horizon=7):
    adapter = _chronos if model == "chronos" else _timesfm
    if not adapter.available:
        return {"status": "unavailable", "message": f"{model} not installed"}

    history = await _fetch_recent_prices(symbol, limit=100)
    if not history:
        return {"status": "error", "message": "No price data available"}

    result = await adapter.forecast(history, horizon)
    return result
```

---

### 3.3 TimesFM Forecast (Tier 1)

**File:** `backend/app/services/forecast_adapters.py`

**Bug:** Line 30: `context_len=min(len([1.0]) * 2, 128)` always = 2.

**Fix:**
```python
context_len = min(len(history) * 2, 512)
```

Also ensure `horizon_len` matches the requested horizon parameter.

---

### 3.4 Market Data Feed (Tier 2, prerequisite for forecasts)

**New file:** `backend/app/services/market_data.py`

**Purpose:** Real OHLCV data from Binance (no API key needed for public endpoints).

```python
import ccxt
import sqlite3
from datetime import datetime, timedelta

class MarketDataService:
    """Real-time + cached market data from Binance public API."""

    def __init__(self, db_path: str = "data/market_data.db"):
        self.exchange = ccxt.binance({"enableRateLimit": True})
        self.db_path = db_path
        self._init_db()

    def _init_db(self):
        # SQLite cache table for OHLCV data
        ...

    async def get_recent_prices(self, symbol: str, limit: int = 100) -> list[float]:
        """Get recent close prices. Try cache first, then fetch from exchange."""
        cached = self._get_cached(symbol, limit)
        if cached and len(cached) >= limit:
            return cached

        try:
            ohlcv = self.exchange.fetch_ohlcv(symbol, "1h", limit=limit)
            prices = [candle[4] for candle in ohlcv]  # close prices
            self._cache(symbol, ohlcv)
            return prices
        except Exception:
            return cached or []

    async def get_ohlcv(self, symbol: str, timeframe: str = "1h", limit: int = 100) -> list[dict]:
        """Full OHLCV data for indicators and backtesting."""
        ...
```

**Dependencies:** Add `ccxt` to requirements.txt
**No API key needed:** Binance public endpoints are free
**SQLite cache:** Avoids hitting rate limits on repeated requests

---

### 3.5 SHAP Attribution (Tier 2)

**File:** `backend/app/services/shap_service.py`

**Strategy:** Train a lightweight LightGBM model on recent trade data to predict trade outcome (profit/loss) from features. Use SHAP TreeExplainer to explain predictions.

**Changes:**
```python
import shap
import lightgbm as lgb
import numpy as np

class SHAPService:
    _model = None
    _explainer = None

    def _get_or_train_model(self, trades_df):
        if self._model is not None:
            return self._model

        # Features: entry_price, volume, rsi, macd, etc.
        # Target: profitable (1) / unprofitable (0)
        features = self._extract_features(trades_df)
        labels = (trades_df["profit"] > 0).astype(int)

        dataset = lgb.Dataset(features, label=labels)
        params = {"objective": "binary", "metric": "auc", "verbosity": -1, "num_leaves": 31}
        self._model = lgb.train(params, dataset, num_boost_round=100)
        self._explainer = shap.TreeExplainer(self._model)
        return self._model

    def calculate_feature_importance(self, features: list[str], values: list[float]) -> dict:
        if self._explainer is None:
            return self._fallback_importance(features)

        import pandas as pd
        df = pd.DataFrame([values], columns=features)
        shap_values = self._explainer.shap_values(df)
        # shap_values[1] for positive class
        importance = dict(zip(features, abs(shap_values[1][0])))
        total = sum(importance.values())
        return {k: round(v / total, 4) for k, v in importance.items()}
```

**Dependencies:** Add `shap`, `lightgbm` to requirements.txt
**Training:** On first SHAP request, trains on trade history from FreqtradeDB (~1-2s for 1000 trades)
**No GPU needed:** TreeExplainer is CPU-only and fast

---

### 3.6 FreqAI Training (Tier 2)

**File:** `backend/app/services/freqai_worker.py`

**Strategy:** Replace simulated training with real LightGBM/XGBoost training on OHLCV features.

**Changes:**
```python
async def _real_training(run: FreqAIRun, db: Session, total_steps: int):
    import lightgbm as lgb
    import pandas as pd
    import numpy as np

    # 1. Fetch training data from market data service
    market_data = MarketDataService()
    ohlcv = await market_data.get_ohlcv(run.symbol, run.timeframe, limit=run.training_candles)

    # 2. Engineer features
    df = pd.DataFrame(ohlcv)
    features = engineer_features(df)  # RSI, MACD, BB, returns, volatility, etc.
    labels = (df["close"].shift(-1) > df["close"]).astype(int)  # next-candle direction

    # 3. Train with progress reporting
    for step in range(total_steps):
        # ... train in chunks or use callbacks
        progress = int((step + 1) / total_steps * 100)
        update_progress(run.id, db, progress)

    # 4. Final metrics
    model = lgb.train(params, train_data, num_boost_round=run.epochs)
    predictions = model.predict(X_test)
    accuracy = ((predictions > 0.5) == y_test).mean()
    # ... save model, report metrics
```

**Dependencies:** Add `lightgbm`, `xgboost`, `catboost` to requirements.txt (optional, pick one)
**Training time:** ~5-30s for 1000 candles on CPU
**Model storage:** Save to `data/freqai_models/{run_id}.pkl`

---

### 3.7 Multi-Provider LLM Service (Tier 3)

**New file:** `backend/app/services/llm_service.py`

**Purpose:** Unified LLM interface supporting multiple providers. Used by RAG, TradingAgents, signal scoring, and any future AI features.

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass

@dataclass
class LLMResponse:
    content: str
    model: str
    provider: str
    tokens_used: int = 0
    latency_ms: float = 0

class LLMProvider(ABC):
    @abstractmethod
    async def chat(self, messages: list[dict], temperature: float = 0.7, max_tokens: int = 2048) -> LLMResponse:
        ...

    @abstractmethod
    async def health_check(self) -> bool:
        ...

class OpenAIProvider(LLMProvider):
    def __init__(self, api_key: str, model: str = "gpt-4o", base_url: str = None):
        self.api_key = api_key
        self.model = model
        self.base_url = base_url or "https://api.openai.com/v1"
        # Works with any OpenAI-compatible API (DeepSeek, vLLM, etc.)

class AnthropicProvider(LLMProvider):
    def __init__(self, api_key: str, model: str = "claude-sonnet-4-20250514"):
        self.api_key = api_key
        self.model = model

class OllamaProvider(LLMProvider):
    def __init__(self, base_url: str = "http://localhost:11434", model: str = "qwen2.5:7b"):
        self.base_url = base_url
        self.model = model

class LLMService:
    """Unified LLM service with provider fallback chain."""

    def __init__(self, config: dict):
        self.providers: list[LLMProvider] = []
        self._load_providers(config)

    def _load_providers(self, config):
        # Priority order: user-configured provider first, then fallbacks
        if config.get("openai_api_key"):
            self.providers.append(OpenAIProvider(
                api_key=config["openai_api_key"],
                model=config.get("openai_model", "gpt-4o"),
                base_url=config.get("openai_base_url"),  # for DeepSeek/vLLM
            ))
        if config.get("anthropic_api_key"):
            self.providers.append(AnthropicProvider(
                api_key=config["anthropic_api_key"],
                model=config.get("anthropic_model", "claude-sonnet-4-20250514"),
            ))
        if config.get("ollama_enabled", True):
            self.providers.append(OllamaProvider(
                base_url=config.get("ollama_url", "http://localhost:11434"),
                model=config.get("ollama_model", "qwen2.5:7b"),
            ))

    async def chat(self, messages: list[dict], **kwargs) -> LLMResponse:
        for provider in self.providers:
            try:
                if await provider.health_check():
                    return await provider.chat(messages, **kwargs)
            except Exception:
                continue
        raise RuntimeError("No LLM provider available")

    async def list_available(self) -> list[dict]:
        """Return status of all configured providers."""
        results = []
        for p in self.providers:
            results.append({
                "provider": type(p).__name__,
                "model": p.model,
                "available": await p.health_check(),
            })
        return results
```

**Key features:**
- OpenAI provider works with ANY OpenAI-compatible API (DeepSeek, vLLM, LM Studio, etc.) via `base_url`
- Provider fallback chain: try each provider in order until one works
- Health check before use (Ollama might not be running, API key might be invalid)
- All providers share the same `chat()` interface

**Dependencies:** `httpx` (already in requirements.txt via FastAPI)

---

### 3.8 RAG Strategy Generation (Tier 3, uses LLM service)

**File:** `backend/app/services/rag_service.py`

**Strategy:** Use LLMService (any provider) + ChromaDB (vector store) + pdfplumber (PDF parsing).

**Architecture:**
```
PDF Upload → pdfplumber extract → chunk text → embed → store in ChromaDB
Strategy Request → embed query → search ChromaDB → build RAG prompt → call LLMService → parse response
```

**Fallback chain:**
1. Try LLMService + ChromaDB → real RAG
2. If no LLM provider available → template-based generation with keyword context
3. If ChromaDB empty → template-only generation

**Embeddings:** Use `sentence-transformers` for local embeddings (no API key needed). Falls back to TF-IDF if not installed.

---

### 3.8 Market-Aware Factor Research (Tier 3)

**New file:** `backend/app/services/factor_research.py` (replaces `factor_qlib.py`)

**Problem:** App supports 3 markets (crypto, US stock, A-share). Each needs its own data source and factor backend. Qlib only works for A-shares.

**Architecture:**
```
FactorResearchService (orchestrator)
├── CryptoFactorBackend    — CCXT data + pandas IC calculation
├── QlibFactorBackend      — qlib for A-shares (保留已有代码)
├── AlpacaFactorBackend    — Alpaca API data for US stocks
└── StubFactorBackend      — deterministic fallback
```

**Common interface:**
```python
class FactorBackend(ABC):
    async def available(self) -> bool: ...
    async def research(self, universe: list[str], factor_name: str) -> FactorResult: ...

@dataclass
class FactorResult:
    status: str           # ok, unavailable, error
    factor_name: str
    market: str
    metrics: dict         # ic_mean, ic_std, rank_ic, turnover, sharpe_long_short
    details: dict         # per-symbol breakdown
```

**Crypto backend:** Uses MarketDataService (CCXT) for OHLCV data. Calculates IC, Rank IC, turnover with pandas. Built-in factors: momentum, volatility, volume_momentum, rsi, mean_reversion, funding_rate.

**A-share backend:** Keeps existing QlibAdapter, fixes `_init_qlib` to use `REG_CN` correctly.

**US Stock backend:** Uses Alpaca API for market data. Same IC calculation logic as crypto.

**Dependencies:** Only `pandas` (already present). Qlib optional for A-shares. Alpaca optional for US stocks.

---

### 3.9 TradingAgents (Tier 3, uses LLM service)

**File:** `backend/app/services/tradingagents_adapter.py`

**Strategy:** Refactor to use `LLMService` instead of hardcoding OpenAI. The multi-agent debate graph calls the LLM through our unified service, so it works with any provider.

**Change:** Replace direct `tradingagents` library dependency with our own multi-agent loop that uses `LLMService.chat()`. This removes the external dependency and lets users choose their provider.

---

## 4. AI Provider Settings Page (macOS App)

### 4.1 New View: `Views/Settings/AIProviderSettingsView.swift`

A settings page where users configure their AI providers. Accessible from Settings → AI Provider.

```
┌─ AI Provider 设置 ────────────────────────────────────────────┐
│                                                                │
│  ┌─ LLM 服务提供商 ─────────────────────────────────────────┐ │
│  │                                                           │ │
│  │  ○ OpenAI 兼容    [gpt-4o ▾]                             │ │
│  │    API Key: [sk-•••••••••••••••••]  [显示] [测试连接]     │ │
│  │    Base URL: [https://api.openai.com/v1         ]        │ │
│  │    💡 支持 DeepSeek、vLLM、LM Studio 等兼容 API          │ │
│  │                                                           │ │
│  │  ○ Anthropic      [claude-sonnet-4-20250514 ▾]            │ │
│  │    API Key: [sk-ant-••••••••••••••]  [显示] [测试连接]    │ │
│  │                                                           │ │
│  │  ○ Ollama (本地)  [qwen2.5:7b ▾]                         │ │
│  │    URL: [http://localhost:11434            ]              │ │
│  │    状态: ● 已连接 (3 模型可用)  [刷新]                    │ │
│  │    可用模型: qwen2.5:7b, llama3.2:3b, deepseek-r1:7b     │ │
│  │                                                           │ │
│  │  [测试所有连接]                       [保存配置]           │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌─ ML 模型状态 ─────────────────────────────────────────────┐ │
│  │                                                           │ │
│  │  情绪分析    FinBERT     ● 就绪    (本地, ~440MB)         │ │
│  │  预测模型    Chronos     ● 就绪    (本地, ~30MB)          │ │
│  │  预测模型    TimesFM     ○ 未加载  (本地, ~2GB)           │ │
│  │  归因分析    SHAP+LGBM   ○ 未加载  (本地, ~10MB)          │ │
│  │  市场数据    Binance     ● 已连接  (公开API, 无需Key)     │ │
│  │                                                           │ │
│  │  [全部预加载]  [清除缓存]                                 │ │
│  └───────────────────────────────────────────────────────────┘ │
│                                                                │
│  ┌─ 用量统计 ───────────────────────────────────────────────┐ │
│  │                                                           │ │
│  │  今日 LLM 调用: 23 次    Tokens: 45,230                  │ │
│  │  今日 ML 推理:  156 次   平均延迟: 320ms                 │ │
│  │  缓存命中率:   78%                                       │ │
│  └───────────────────────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────┘
```

### 4.2 Backend API: `routers/ai_providers.py`

```python
# GET  /api/ai/providers          — List all configured providers + status
# POST /api/ai/providers/config   — Update provider configuration
# POST /api/ai/providers/test     — Test connection for a specific provider
# GET  /api/ai/models/status      — ML model loading status
# POST /api/ai/models/preload     — Pre-download all ML models
# GET  /api/ai/usage              — Usage statistics
```

### 4.3 Data Model

```python
# backend/app/models/ai_provider.py

class AIProviderConfig(Base):
    __tablename__ = "ai_provider_configs"

    id = Column(Integer, primary_key=True)
    provider = Column(String)  # openai, anthropic, ollama
    api_key_encrypted = Column(String, nullable=True)
    base_url = Column(String, nullable=True)
    model = Column(String)
    is_active = Column(Boolean, default=True)
    priority = Column(Integer, default=0)  # lower = higher priority
    created_at = Column(DateTime)
    updated_at = Column(DateTime)

class AIUsageLog(Base):
    __tablename__ = "ai_usage_logs"

    id = Column(Integer, primary_key=True)
    provider = Column(String)
    model = Column(String)
    service = Column(String)  # rag, sentiment, forecast, etc.
    tokens_used = Column(Integer)
    latency_ms = Column(Float)
    created_at = Column(DateTime)
```

### 4.4 macOS App Types

```swift
// Types.swift additions

struct AIProviderInfo: Codable, Identifiable {
    let id: String  // provider name
    let name: String
    let type: AIProviderType
    var model: String
    var baseUrl: String?
    var isAvailable: Bool
    var availableModels: [String]
    var lastChecked: Date?
}

enum AIProviderType: String, Codable {
    case openai, anthropic, ollama
}

struct AIModelStatus: Codable {
    let name: String
    let type: String  // sentiment, forecast, attribution, etc.
    let status: ModelLoadStatus
    let sizeMB: Int
    let isLocal: Bool
}

enum ModelLoadStatus: String, Codable {
    case ready, loading, notLoaded, error
}
```

---

## 5. Implementation Order

### Phase A: Quick Wins (4 tasks)

1. **Fix TimesFM bug** — 1 line fix in `forecast_adapters.py`
2. **FinBERT real integration** — Swap `analyze_text` body in `sentiment_finbert.py`
3. **Chronos orchestrator fix** — Remove deterministic fallback in `forecasting.py`
4. **Add market data service** — New file `market_data.py` with CCXT + SQLite cache

### Phase B: ML Models (3 tasks)

5. **SHAP real integration** — Add `shap` + `lightgbm`, train on trade data
6. **FreqAI real training** — Replace simulation with LightGBM training
7. **Wire market data to forecast orchestrator** — Replace `_fetch_recent_prices`

### Phase C: Multi-Provider LLM (4 tasks)

8. **LLM Service** — New file `llm_service.py` with multi-provider support
9. **AI Provider API** — New router `ai_providers.py` + DB models
10. **RAG with LLM Service** — Refactor `rag_service.py` to use `LLMService`
11. **AI Provider Settings UI** — New macOS view + ViewModel

### Phase D: Multi-Market Factor Research (5 tasks)

12. **Factor Research Core** — Market-aware backends with IC/Rank IC/long-short/turnover (详见 factor-research-implementation.md)
13. **Factor Definitions** — 15+ factors across 6 categories (momentum, volatility, volume, technical, mean-reversion, crypto-specific)
14. **Factor Research API + UI** — Backend router + macOS factor research view
15. **Fama-MacBeth Regression** — Cross-sectional regression with t-statistics (Phase 2 advanced testing)
16. **Factor Robustness Testing** — Out-of-sample split, factor decay analysis, orthogonalization, Bonferroni correction

### Phase E: Cleanup (1 task)

17. **TradingAgents refactor** — Use LLMService instead of direct OpenAI

---

## 6. Dependencies Summary

### New in requirements.txt

```
# Market data
ccxt>=4.0.0

# SHAP attribution
shap>=0.45.0
lightgbm>=4.0.0

# LLM providers (all optional, install what you need)
# openai>=1.0.0        # for OpenAI/DeepSeek/vLLM
# anthropic>=0.30.0    # for Anthropic
# httpx>=0.27.0        # for Ollama (already via FastAPI)

# RAG strategy generation (optional)
pdfplumber>=0.11.0
chromadb>=0.5.0
sentence-transformers>=3.0.0
```

### Already in requirements.txt (just need to work)

- `transformers==4.50.3` — for FinBERT
- `torch==2.6.0` — for FinBERT + Chronos
- `timesfm==1.0.0` — for TimesFM forecast (bug fix needed)
- `chronos==1.2.0` — for Chronos forecast (already works)

---

## 7. Environment Variables (.env additions)

```bash
# === AI Provider Configuration ===
# Configure via UI (Settings → AI Provider) or .env file

# OpenAI-compatible API (works with DeepSeek, vLLM, LM Studio too)
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o
OPENAI_BASE_URL=https://api.openai.com/v1

# Anthropic
ANTHROPIC_API_KEY=
ANTHROPIC_MODEL=claude-sonnet-4-20250514

# Ollama (local, no API key needed)
OLLAMA_ENABLED=true
OLLAMA_URL=http://localhost:11434
OLLAMA_MODEL=qwen2.5:7b

# === ML Model Configuration ===
SENTIMENT_MODEL=ProsusAI/finbert
FORECAST_MODEL=chronos
MARKET_DATA_SOURCE=binance
MODEL_CACHE_DIR=./data/models
```

---

## 8. Acceptance Criteria

### Core Infrastructure
- [ ] `python run.py` starts backend with zero manual steps
- [ ] Core features (dashboard, strategies, backtest) work without any API keys
- [ ] All services degrade gracefully when dependencies unavailable

### ML Models (Phase A-B)
- [ ] FinBERT returns real sentiment scores (model: "finbert", not "keyword_fallback")
- [ ] Chronos returns real probabilistic forecasts with confidence intervals
- [ ] TimesFM returns real forecasts (context_len bug fixed)
- [ ] Market data from Binance public API, cached in SQLite
- [ ] SHAP returns real feature importance from trained LightGBM model
- [ ] FreqAI training produces real model with real metrics

### Multi-Provider LLM (Phase C)
- [ ] RAG works with any configured LLM provider (OpenAI/Anthropic/Ollama)
- [ ] AI Provider Settings page shows all providers and their status
- [ ] "Test Connection" button validates each provider
- [ ] ML models show loading status and can be pre-loaded
- [ ] OpenAI-compatible base_url allows DeepSeek/vLLM/LM Studio
- [ ] No mandatory API keys for core functionality

### Factor Research (Phase D)
- [ ] Factor research works for crypto market (IC, Rank IC, long-short, turnover)
- [ ] 15+ factors across 6 categories implemented and tested
- [ ] Minimum 10 assets required for cross-sectional IC (prevents noise)
- [ ] IC threshold 0.03 aligned with BARRA/MSCI industry standard
- [ ] Fama-MacBeth regression with t-statistics (|t|>2.0 = significant)
- [ ] Out-of-sample testing detects overfitting (IC decay < 50% = robust)
- [ ] Factor decay analysis across multiple horizons (1d/5d/10d/20d/30d)
- [ ] Factor orthogonalization removes inter-factor correlation
- [ ] Bonferroni correction for multiple testing
- [ ] Academic references cited in code comments (Grinold & Kahn, Liu et al., Bianchi, Fama-MacBeth)

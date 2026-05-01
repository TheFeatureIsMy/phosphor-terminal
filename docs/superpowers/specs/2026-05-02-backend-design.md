# CyberQuant OS 后端设计文档

## 概述

CyberQuant OS 后端是量化交易系统的核心引擎，基于 **Freqtrade 二次开发**，采用**插件化多市场架构**，通过 FastAPI 为前端提供 REST API。

### 技术栈
- **API层**: Python 3.11 + FastAPI + Uvicorn
- **交易引擎**: Freqtrade（Docker官方镜像）+ CCXT
- **数据库**: SQLite（MVP阶段）→ PostgreSQL（后期）
- **部署**: Docker Compose（FastAPI + Freqtrade 双容器）
- **AI模块**: SHAP, FinBERT, TimesFM, Chronos, LangChain, Qlib

### 设计原则
- Freqtrade 作为底层执行引擎，通过 REST API + 数据库直读双通道集成
- 插件化架构：每个市场是一个 Plugin，通过统一接口注册
- 事件驱动：交易事件通过 Event Bus 分发到各服务
- 先 MVP 后 AI：Phase 1 跑通交易闭环，Phase 2+ 逐步加入 AI 功能

---

## 1. 系统架构

### 1.1 总体架构图

```
┌─────────────────────────────────────────────────────┐
│                   前端 (React)                       │
│                 http://localhost:5173                │
└──────────────────────┬──────────────────────────────┘
                       │ REST API
┌──────────────────────▼──────────────────────────────┐
│              FastAPI Server (:8000)                   │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ │
│  │Strategy  │ │Dashboard │ │Backtest  │ │Risk    │ │
│  │Router    │ │Router    │ │Router    │ │Router  │ │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └───┬────┘ │
│       └─────────────┴────────────┴───────────┘      │
│                      │                               │
│  ┌───────────────────▼───────────────────────────┐  │
│  │              Service Layer                     │  │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐│  │
│  │  │ Freqtrade  │ │ Attribution│ │ Market     ││  │
│  │  │ Client     │ │ Service    │ │ Registry   ││  │
│  │  └────────────┘ └────────────┘ └────────────┘│  │
│  └───────────────────┬───────────────────────────┘  │
│                      │                               │
│  ┌───────────────────▼───────────────────────────┐  │
│  │         Market Plugin Layer                    │  │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────┐  │  │
│  │  │ Crypto   │ │ US Stock │ │ A-Share      │  │  │
│  │  │ Plugin   │ │ Plugin   │ │ Plugin       │  │  │
│  │  └──────────┘ └──────────┘ └──────────────┘  │  │
│  └───────────────────────────────────────────────┘  │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│              Freqtrade (:8080)                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐│
│  │ Strategy     │ │ Backtest     │ │ Exchange     ││
│  │ Engine       │ │ Engine       │ │ (CCXT)       ││
│  └──────────────┘ └──────────────┘ └──────────────┘│
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│              数据层                                   │
│  ┌──────────┐ ┌──────────────┐ ┌──────────────────┐│
│  │ SQLite   │ │ SQLite       │ │ Vector Store     ││
│  │ (扩展表) │ │ (Freqtrade)  │ │ (Phase 3)        ││
│  └──────────┘ └──────────────┘ └──────────────────┘│
└─────────────────────────────────────────────────────┘
```

### 1.2 数据流

**交易执行流：**
```
前端 → FastAPI → FreqtradeClient.start_bot() → Freqtrade REST API → CCXT → Binance
                                         ↓
                              Freqtrade 写入 trades 表
                                         ↓
                              FastAPI 读取 → 返回前端
```

**回测流：**
```
前端 → FastAPI → FreqtradeClient.run_backtest() → Freqtrade 回测引擎
                                                        ↓
                                              写入 backtest 结果
                                                        ↓
                                              FastAPI 读取 → 返回前端
```

**归因分析流 (Phase 2)：**
```
Freqtrade 订单完成 → Event Bus → AttributionService
                                      ↓
                              SHAP 计算特征贡献度
                                      ↓
                              写入 attribution_reports 表
                                      ↓
                              前端查询归因报告
```

---

## 2. Docker 部署方案

### 2.1 docker-compose.yml

```yaml
version: "3.8"

services:
  api:
    build:
      context: ./backend
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    volumes:
      - ./data:/app/data
      - ./backend:/app
    environment:
      - DATABASE_URL=sqlite:///app/data/cyberquant.db
      - FREQTRADE_URL=http://freqtrade:8080
      - FREQTRADE_DB_PATH=/freqtrade/user_data/tradesv3.sqlite
    depends_on:
      - freqtrade
    restart: unless-stopped

  freqtrade:
    image: freqtradeorg/freqtrade:stable
    volumes:
      - ./freqtrade/user_data:/freqtrade/user_data
      - ./freqtrade/strategies:/freqtrade/strategies
    ports:
      - "8080:8080"
    command: >
      trade
      --logfile /freqtrade/user_data/logs/freqtrade.log
      --config /freqtrade/user_data/config.json
      --strategy SampleStrategy
      --dry-run
    restart: unless-stopped
```

### 2.2 目录结构

```
cyberquant-os/
├── frontend/              # React 前端 (已完成)
├── backend/               # FastAPI 后端
│   ├── app/
│   │   ├── __init__.py
│   │   ├── main.py        # FastAPI 入口
│   │   ├── config.py      # 配置管理
│   │   ├── database.py    # 数据库连接
│   │   ├── routers/       # API 路由
│   │   │   ├── strategies.py
│   │   │   ├── orders.py
│   │   │   ├── dashboard.py
│   │   │   ├── backtest.py
│   │   │   ├── risk.py
│   │   │   └── system.py
│   │   ├── models/        # SQLAlchemy 模型
│   │   │   ├── strategy.py
│   │   │   ├── attribution.py
│   │   │   └── risk.py
│   │   ├── schemas/       # Pydantic 请求/响应模型
│   │   ├── services/      # 业务逻辑
│   │   │   ├── freqtrade_client.py
│   │   │   ├── freqtrade_db.py
│   │   │   ├── market_registry.py
│   │   │   └── attribution.py
│   │   └── plugins/       # 市场插件
│   │       ├── base.py
│   │       ├── crypto_binance.py
│   │       ├── us_alpaca.py
│   │       └── a_share_jq.py
│   ├── Dockerfile
│   └── requirements.txt
├── freqtrade/
│   ├── user_data/
│   │   ├── config.json
│   │   ├── strategies/
│   │   └── logs/
│   └── strategies/        # 自定义策略
├── data/
│   └── cyberquant.db      # SQLite 数据库
├── docker-compose.yml
└── .env
```

---

## 3. 数据库设计

### 3.1 Freqtrade 内置表（只读）

Freqtrade 自动创建以下表，我们通过 `FreqtradeDB` 直读：

- `trades` — 所有交易记录（id, pair, is_open, profit, open_date, close_date, ...）
- `orders` — 订单详情（id, trade_id, order_type, side, price, amount, ...）

### 3.2 CyberQuant 扩展表

```sql
-- 策略配置表
CREATE TABLE strategies (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL,                    -- ma_cross/breakout/grid/mean_reversion/rag_generated
    parameters JSON,
    source TEXT DEFAULT 'manual',          -- manual/rag_generated/optimized
    market TEXT DEFAULT 'crypto',          -- crypto/us_stock/a_share
    exchange TEXT DEFAULT 'binance',       -- binance/alpaca/joinquant
    version INTEGER DEFAULT 1,
    status TEXT DEFAULT 'draft',           -- draft/backtested/active/paused/retired
    sharpe_ratio REAL,
    max_drawdown REAL,
    freqtrade_strategy_id TEXT,            -- 关联Freqtrade策略名
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- SHAP归因报告表 (Phase 2)
CREATE TABLE attribution_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trade_id INTEGER NOT NULL,             -- 关联Freqtrade trades表
    strategy_id INTEGER,
    feature_contributions JSON,
    top_loss_factors JSON,
    market_context JSON,
    summary TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 滑点归因表 (Phase 2)
CREATE TABLE slippage_attribution (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    trade_id INTEGER NOT NULL,
    signal_price REAL,
    filled_price REAL,
    execution_slippage REAL,
    spread_cost REAL,
    market_impact REAL,
    latency_cost REAL,
    slippage_pct REAL,
    diagnosis TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 风控事件表
CREATE TABLE risk_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type TEXT NOT NULL,              -- stop_loss/circuit_breaker/api_error/correlation_warning
    strategy_id INTEGER,
    market TEXT DEFAULT 'crypto',
    severity TEXT NOT NULL,                -- low/medium/high/critical
    description TEXT,
    action_taken TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 情绪数据表 (Phase 2)
CREATE TABLE sentiment_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    market TEXT DEFAULT 'crypto',
    source TEXT NOT NULL,                  -- twitter/reddit/news
    score REAL NOT NULL,
    raw_text TEXT,
    model TEXT DEFAULT 'finbert',
    timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 相关性快照表 (Phase 2)
CREATE TABLE correlation_snapshots (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol_a TEXT NOT NULL,
    symbol_b TEXT NOT NULL,
    market TEXT DEFAULT 'crypto',
    correlation REAL NOT NULL,
    window_days INTEGER DEFAULT 30,
    alert_level TEXT,                      -- normal/yellow/red
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 组合压力测试表 (Phase 2)
CREATE TABLE portfolio_stress_tests (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER DEFAULT 1,
    market TEXT DEFAULT 'crypto',
    scenario TEXT NOT NULL,
    portfolio_var_95 REAL,
    portfolio_cvar REAL,
    max_potential_drawdown REAL,
    concentration_risk JSON,
    recommendations TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);
```

---

## 4. API 层设计

### 4.1 端点清单（15个）

| 方法 | 路径 | 数据来源 | 实现方式 |
|------|------|----------|----------|
| GET | `/api/strategies` | 扩展表 | 直接查询 |
| GET | `/api/strategies/{id}` | 扩展表 | 直接查询 |
| POST | `/api/strategies` | 扩展表 | 创建+注册Freqtrade策略 |
| PUT | `/api/strategies/{id}` | 扩展表 | 更新 |
| DELETE | `/api/strategies/{id}` | 扩展表 | 删除 |
| GET | `/api/orders` | Freqtrade trades表 | FreqtradeDB直读 |
| GET | `/api/positions` | Freqtrade trades表 | 聚合计算 |
| GET | `/api/dashboard/kpis` | Freqtrade trades表 | 实时计算 |
| GET | `/api/dashboard/equity-curve` | Freqtrade trades表 | 时间序列聚合 |
| POST | `/api/backtest` | Freqtrade引擎 | 调用REST API |
| GET | `/api/backtest/{id}` | Freqtrade结果 | 直读+格式化 |
| GET | `/api/system/status` | Freqtrade API | 转发 |
| GET | `/api/risk/events` | 扩展表 | 直接查询 |
| GET | `/api/portfolio/correlation` | 扩展表 | 直接查询 |

### 4.2 Freqtrade 集成客户端

```python
class FreqtradeClient:
    """通过REST API控制Freqtrade交易引擎"""

    def __init__(self, base_url: str = "http://freqtrade:8080"):
        self.base_url = base_url

    async def start_bot(self, strategy_name: str) -> dict:
        """启动策略"""
        ...

    async def stop_bot(self) -> dict:
        """停止策略"""
        ...

    async def get_status(self) -> dict:
        """获取运行状态"""
        ...

    async def get_trades(self) -> list:
        """获取交易列表"""
        ...

    async def run_backtest(self, config: BacktestConfig) -> dict:
        """触发回测"""
        ...
```

### 4.3 Freqtrade 数据库直读

```python
class FreqtradeDB:
    """直接读取Freqtrade的SQLite数据库"""

    def __init__(self, db_path: str):
        self.engine = create_engine(f"sqlite:///{db_path}")

    async def get_trades(self, limit: int = 50) -> list:
        """读取交易记录"""
        ...

    async def get_equity_curve(self, days: int = 90) -> list:
        """从trades表聚合计算收益曲线"""
        ...

    async def get_kpis(self) -> DashboardKPIs:
        """计算KPI指标"""
        ...
```

---

## 5. 插件化多市场架构

### 5.1 MarketPlugin 接口

```python
from abc import ABC, abstractmethod
from dataclasses import dataclass

@dataclass
class MarketConstraints:
    """市场交易约束"""
    trading_hours: list[tuple[str, str]]  # 交易时段
    settlement: str                        # T+0 / T+1
    allow_short: bool                      # 是否允许做空
    daily_limit: float | None              # 涨跌停幅度 (None=无限制)
    min_lot_size: int                      # 最小交易单位
    allow_day_trading: bool                # 是否允许当日买卖
    commission_rate: float                 # 手续费率

class MarketPlugin(ABC):
    """市场插件接口"""

    @property
    @abstractmethod
    def market_id(self) -> str: ...

    @property
    @abstractmethod
    def constraints(self) -> MarketConstraints: ...

    @abstractmethod
    async def connect(self) -> bool: ...

    @abstractmethod
    async def fetch_ohlcv(self, symbol: str, timeframe: str, limit: int) -> pd.DataFrame: ...

    @abstractmethod
    async def create_order(self, symbol: str, side: str, amount: float, order_type: str) -> dict: ...

    @abstractmethod
    async def get_balance(self) -> dict: ...

    @abstractmethod
    async def get_order_book(self, symbol: str, limit: int) -> dict: ...
```

### 5.2 MarketRegistry

```python
class MarketRegistry:
    """市场插件注册表"""

    _plugins: dict[str, MarketPlugin] = {}

    @classmethod
    def register(cls, plugin: MarketPlugin):
        cls._plugins[plugin.market_id] = plugin

    @classmethod
    def get(cls, market_id: str) -> MarketPlugin:
        if market_id not in cls._plugins:
            raise ValueError(f"Market {market_id} not registered")
        return cls._plugins[market_id]

    @classmethod
    def list_markets(cls) -> list[str]:
        return list(cls._plugins.keys())
```

### 5.3 内置插件实现

**Crypto Binance Plugin:**
- 基于 ccxt 库连接 Binance
- 24/7 交易，T+0 结算
- 支持做空（合约）
- 无涨跌停

**US Stock Alpaca Plugin (Phase 4):**
- 基于 ccxt 的 alpaca 驱动
- 美股交易时段 9:30-16:00 ET
- T+1 结算
- PDT 规则限制

**A-Share JoinQuant Plugin (Phase 4):**
- 基于聚宽 API
- A股交易时段 9:30-15:00 CST
- T+1 结算
- ±10% 涨跌停
- 100股最小单位

---

## 6. 事件驱动架构 (Phase 2)

```python
class EventBus:
    """事件总线 - 解耦各服务"""

    _handlers: dict[str, list[Callable]] = {}

    @classmethod
    def subscribe(cls, event_type: str, handler: Callable):
        cls._handlers.setdefault(event_type, []).append(handler)

    @classmethod
    async def emit(cls, event_type: str, data: Any):
        for handler in cls._handlers.get(event_type, []):
            await handler(data)

# 事件类型
class TradeFilledEvent:
    trade_id: int
    symbol: str
    side: str
    price: float
    quantity: float
    market: str

# 订阅示例
EventBus.subscribe("trade.filled", attribution_service.analyze)
EventBus.subscribe("trade.filled", risk_service.check_rules)
EventBus.subscribe("trade.filled", notification_service.notify)
```

---

## 7. 开发计划

### Phase 1 (Week 1-3): 核心MVP

**Week 1: 基础设施**
- [ ] Docker环境搭建（docker-compose配置）
- [ ] Freqtrade容器启动 + Binance测试网连接
- [ ] FastAPI项目初始化 + SQLite数据库
- [ ] 15个API端点实现
- [ ] Freqtrade数据库直读
- [ ] 前后端联调（`VITE_USE_MOCK=false`）
- **验收**: 前端所有页面显示真实数据

**Week 2: 交易引擎**
- [ ] 第一个策略（RSI+MA）编写+注册
- [ ] 策略启停通过API控制
- [ ] 回测引擎调用+结果展示
- [ ] Binance测试网实盘下单
- **验收**: 策略可回测，测试网可下单

**Week 3: 风控+监控**
- [ ] 基础风控规则（止损/止盈/最大回撤）
- [ ] 风控事件记录到risk_events表
- [ ] Telegram Bot基础功能（启停/状态/告警）
- [ ] 系统健康监控端点
- **验收**: 风控触发时自动暂停，Telegram通知正常

### Phase 2 (Week 4-6): 差异化功能

**Week 4: SHAP归因**
- [ ] SHAP模块集成
- [ ] 每笔交易自动归因分析
- [ ] 自然语言尸检报告
- **验收**: 每笔亏损订单有归因报告

**Week 5: 执行层归因 + 风控增强**
- [ ] 滑点归因（策略偏差 vs 执行损耗）
- [ ] 相关性矩阵监控
- [ ] 组合压力测试
- **验收**: 滑点归因正确区分原因

**Week 6: 情绪分析**
- [ ] FinBERT接入社交媒体
- [ ] 情绪打分作为策略信号
- [ ] Telegram日报推送
- **验收**: 情绪分数实时更新

### Phase 3 (Week 7-10): AI增强

**Week 7-8: RAG策略实验室**
- [ ] PDF上传+向量化
- [ ] LangChain策略代码生成
- [ ] AST安全扫描
- [ ] 生成策略自动回测
- **验收**: 上传PDF后生成可回测策略

**Week 9: 时序预测**
- [ ] TimesFM集成
- [ ] Chronos集成
- [ ] 预测特征接入策略
- **验收**: 策略信号包含AI预测

**Week 10: 因子挖掘 + 增量学习**
- [ ] Qlib因子研究
- [ ] FreqAI增量学习
- [ ] 自动策略优化
- **验收**: 模型定期自动更新

### Phase 4 (Week 11+): 多市场扩展

**Week 11-12: 美股**
- [ ] Alpaca Plugin实现
- [ ] MarketConstraints美股规则
- [ ] 美股策略适配

**Week 13+: A股**
- [ ] 聚宽/米筐 Plugin
- [ ] T+1/涨跌停约束
- [ ] A股策略适配

---

## 8. 依赖清单

### Python 依赖 (requirements.txt)

```
# 核心
fastapi==0.115.*
uvicorn[standard]==0.34.*
sqlalchemy==2.0.*
pydantic==2.10.*

# 交易引擎
freqtrade==2025.*
ccxt==4.*

# 数据处理
pandas==2.2.*
numpy==2.*

# Phase 2: AI/ML
# shap==0.47.*
# transformers==4.*        # FinBERT
# torch==2.*

# Phase 3: 高级AI
# langchain==0.3.*
# pinecone-client==5.*
# timesfm==2.*
# chronos-forecasting==2.*
# qlib==0.9.*

# 通信
python-telegram-bot==21.*
aiohttp==3.11.*

# 工具
python-dotenv==1.*
alembic==1.14.*            # 数据库迁移
```

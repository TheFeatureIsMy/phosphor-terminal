# Sources & Evidence Policy

> 本文档用于 PulseDesk v2.0 开发。关键技术判断要求至少两类来源互相印证：官方文档 / 官方 GitHub / 论文 / 权威行业报告优先。

## 核心来源

### Freqtrade / FreqAI / CCXT
- Freqtrade Official Docs: https://www.freqtrade.io/en/stable/
- Freqtrade Docker Quickstart: https://www.freqtrade.io/en/stable/docker_quickstart/
- Freqtrade REST API / WebSocket RPC: https://www.freqtrade.io/en/stable/rest-api/
- Freqtrade Strategy Customization: https://www.freqtrade.io/en/stable/strategy-customization/
- Freqtrade Backtesting: https://www.freqtrade.io/en/stable/backtesting/
- FreqAI Docs: https://www.freqtrade.io/en/stable/freqai/
- Freqtrade Docker Hub: https://hub.docker.com/r/freqtradeorg/freqtrade/
- CCXT Docs: https://docs.ccxt.com/

### AI Agent / Multi-Agent Trading
- TradingAgents GitHub: https://github.com/tauricresearch/tradingagents
- TradingAgents Paper: https://arxiv.org/abs/2412.20138
- TradingAgents Research Page: https://tauric.ai/research/tradingagents/
- AI-Trader GitHub: https://github.com/HKUDS/AI-Trader
- AI-Trader Paper: https://arxiv.org/abs/2512.10971
- TradingGroup Paper: https://arxiv.org/abs/2508.17565

### Research / Forecast / NLP / Explainability
- Microsoft Qlib GitHub: https://github.com/microsoft/qlib
- Microsoft Qlib Research: https://www.microsoft.com/en-us/research/publication/qlib-an-ai-oriented-quantitative-investment-platform/
- TimesFM GitHub: https://github.com/google-research/timesfm
- Chronos GitHub: https://github.com/amazon-science/chronos-forecasting
- FinBERT GitHub: https://github.com/ProsusAI/finBERT
- SHAP GitHub: https://github.com/shap/shap
- SHAP Docs: https://shap.readthedocs.io/

### Agent / RAG / App UI
- LangGraph Docs: https://docs.langchain.com/oss/python/langgraph/overview
- LangChain Agents Docs: https://docs.langchain.com/oss/python/langchain/agents
- React Flow Docs: https://reactflow.dev/
- Apple WKWebView Docs: https://developer.apple.com/documentation/webkit/wkwebview

### Market Manipulation / Crypto Risk
- Chainalysis Crypto Market Manipulation 2025: https://www.chainalysis.com/blog/crypto-market-manipulation-wash-trading-pump-and-dump-2025/
- IOSCO Crypto and Digital Asset Recommendations: https://www.iosco.org/
- ESMA Crypto-Assets and MiCA: https://www.esma.europa.eu/

---

# v2.2 新增资料依据

## MCP

- Model Context Protocol 官方文档将 MCP 定义为连接 AI 应用与外部系统的开放标准，可暴露 data sources、tools 和 workflows。
- MCP 规范支持 server 暴露 prompts，客户端可以发现和调用。
- MCP 生态存在安全与维护风险，因此 PulseDesk MCP v1 只读、脱敏、审计、禁止交易写操作。

## Freqtrade 风控

- Freqtrade 官方配置文档支持 trailing stoploss 配置。
- Freqtrade stoploss 文档说明 open trade 的 stoploss 可通过配置或策略调整。
- Freqtrade strategy customization 文档说明策略可自定义指标和交易规则。

## PostgreSQL 分区

- PostgreSQL 官方文档支持 declarative partitioning，适合按时间范围拆分大表。


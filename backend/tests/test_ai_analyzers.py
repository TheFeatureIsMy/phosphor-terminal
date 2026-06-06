import pytest
from app.services.ai_analyzers.news_risk import NewsRiskAnalyzer
from app.services.ai_analyzers.whale_risk import WhaleRiskAnalyzer
from app.services.ai_analyzers.conflict_analysis import ConflictAnalyzer

@pytest.mark.asyncio
async def test_news_analyzer_no_llm():
    analyzer = NewsRiskAnalyzer(llm_service=None)
    result = await analyzer.analyze("BTC/USDT", {})
    assert result.analyzer_name == "news_risk"
    assert 0 <= result.risk_score <= 1.0
    assert result.confidence == 0.2

@pytest.mark.asyncio
async def test_whale_analyzer_no_llm():
    analyzer = WhaleRiskAnalyzer(llm_service=None)
    result = await analyzer.analyze("BTC/USDT", {})
    assert result.analyzer_name == "whale_risk"
    assert result.risk_score == 0.2

@pytest.mark.asyncio
async def test_conflict_no_conflicts():
    analyzer = ConflictAnalyzer()
    result = await analyzer.analyze("BTC/USDT", {})
    assert result.risk_score == 0.0
    assert len(result.risk_flags) == 0

@pytest.mark.asyncio
async def test_conflict_structure_news():
    analyzer = ConflictAnalyzer()
    result = await analyzer.analyze("BTC/USDT", {
        "structure_direction": "bullish",
        "news_bias": "bearish",
    })
    assert "structure_news_conflict" in result.risk_flags
    assert result.risk_score > 0

@pytest.mark.asyncio
async def test_conflict_high_whale():
    analyzer = ConflictAnalyzer()
    result = await analyzer.analyze("BTC/USDT", {
        "whale_risk_score": 0.8,
    })
    assert "high_whale_risk" in result.risk_flags

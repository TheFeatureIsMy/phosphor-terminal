import pytest
from app.services.trade_reviewer import TradeReviewer

@pytest.mark.asyncio
async def test_review_no_llm():
    reviewer = TradeReviewer(llm_service=None)
    review = await reviewer.review_trade(
        trade_id="t1", symbol="BTC/USDT", direction="long",
        entry_price=60000, exit_price=62000, profit_pct=3.33,
    )
    assert review.trade_id == "t1"
    assert review.outcome == "win"
    assert review.confidence == 0.0

@pytest.mark.asyncio
async def test_review_with_snapshot():
    reviewer = TradeReviewer(llm_service=None)
    snapshot = {
        "snapshot_id": "snap_123",
        "structure_context": {"structure_score": 75, "market_regime": "range"},
        "ai_context": {"ai_risk_score": 0.3},
        "reason_codes": ["sweep_confirmed"],
    }
    review = await reviewer.review_trade(
        trade_id="t2", symbol="BTC/USDT", direction="long",
        entry_price=60000, exit_price=58000, profit_pct=-3.33,
        snapshot=snapshot,
    )
    assert review.outcome == "loss"
    assert review.snapshot_uid == "snap_123"

@pytest.mark.asyncio
async def test_review_breakeven():
    reviewer = TradeReviewer(llm_service=None)
    review = await reviewer.review_trade(
        trade_id="t3", symbol="ETH/USDT", direction="long",
        entry_price=3000, exit_price=3000, profit_pct=0.0,
    )
    assert review.outcome == "breakeven"

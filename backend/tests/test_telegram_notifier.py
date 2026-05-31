import pytest
from app.services.telegram_notifier import build_risk_message, send_telegram_notification


def test_build_risk_message_includes_severity_and_event_type():
    msg = build_risk_message({
        "severity": "high",
        "event_type": "stop_loss",
        "description": "BTC loss -6%",
        "action_taken": "pause_strategy",
    })
    assert "[HIGH]" in msg
    assert "stop_loss" in msg
    assert "BTC loss -6%" in msg
    assert "pause_strategy" in msg


def test_build_risk_message_default_severity():
    msg = build_risk_message({"event_type": "test"})
    assert "[INFO]" in msg


def test_build_risk_message_defaults_for_missing_fields():
    msg = build_risk_message({})
    assert "[INFO]" in msg
    assert "risk_event" in msg
    assert "review_required" in msg


@pytest.mark.asyncio
async def test_dry_run_returns_dry_run_status():
    result = await send_telegram_notification(
        {"event_type": "test", "severity": "low"},
        dry_run=True,
        bot_token="token",
        chat_id="123",
    )
    assert result["status"] == "dry_run"


@pytest.mark.asyncio
async def test_dry_run_when_bot_token_missing():
    result = await send_telegram_notification(
        {"event_type": "test"},
        dry_run=False,
        bot_token=None,
        chat_id="123",
    )
    assert result["status"] == "dry_run"


@pytest.mark.asyncio
async def test_dry_run_when_chat_id_missing():
    result = await send_telegram_notification(
        {"event_type": "test"},
        dry_run=False,
        bot_token="token",
        chat_id=None,
    )
    assert result["status"] == "dry_run"


@pytest.mark.asyncio
async def test_dry_run_destination_not_configured():
    result = await send_telegram_notification(
        {"event_type": "test"},
        dry_run=True,
        bot_token=None,
        chat_id=None,
    )
    assert result["destination"] == "not_configured"

import pytest
from datetime import datetime, timezone
from runtime_snapshot_guard import RuntimeSnapshotGuard

@pytest.fixture
def guard():
    config = {
        "max_snapshot_miss_ticks": 3,
        "hard_disconnect_timeout_ms": 3000,
        "fallback_stop_pct": 0.02,
    }
    return RuntimeSnapshotGuard(config)

def _now():
    return datetime.now(timezone.utc)

def test_healthy_on_valid_snapshot(guard):
    snapshot = {"execution_plan": {"stop_price": 60000}}
    result = guard.update_from_snapshot("BTC/USDT", snapshot, _now())
    assert result["state"] == "healthy"
    assert result["stop_price"] == 60000

def test_degraded_on_single_miss(guard):
    result = guard.update_from_snapshot("BTC/USDT", None, _now())
    assert result["state"] == "degraded"

def test_disconnect_after_max_misses(guard):
    for _ in range(3):
        guard.update_from_snapshot("BTC/USDT", None, _now())
    result = guard.update_from_snapshot("BTC/USDT", None, _now())
    assert result["state"] == "disconnect_protection"

def test_last_valid_stop_preserved(guard):
    snapshot = {"execution_plan": {"stop_price": 60000}}
    guard.update_from_snapshot("BTC/USDT", snapshot, _now())
    for _ in range(4):
        guard.update_from_snapshot("BTC/USDT", None, _now())
    result = guard.update_from_snapshot("BTC/USDT", None, _now())
    assert result["stop_price"] == 60000

def test_emergency_close_on_stop_hit(guard):
    snapshot = {"execution_plan": {"stop_price": 60000}}
    guard.update_from_snapshot("BTC/USDT", snapshot, _now())
    for _ in range(4):
        guard.update_from_snapshot("BTC/USDT", None, _now())
    result = guard.should_emergency_close("BTC/USDT", 59900, "long", _now())
    assert result["close"] is True

def test_no_emergency_close_price_above_stop(guard):
    snapshot = {"execution_plan": {"stop_price": 60000}}
    guard.update_from_snapshot("BTC/USDT", snapshot, _now())
    for _ in range(4):
        guard.update_from_snapshot("BTC/USDT", None, _now())
    result = guard.should_emergency_close("BTC/USDT", 61000, "long", _now())
    assert result["close"] is False

def test_fallback_stoploss_calculation(guard):
    snapshot = {"execution_plan": {"stop_price": 60000}}
    guard.update_from_snapshot("BTC/USDT", snapshot, _now())
    sl = guard.get_fallback_stoploss("BTC/USDT", 61000)
    assert sl < 0
    assert abs(sl - ((60000 / 61000) - 1)) < 0.001

def test_fallback_stoploss_no_stop(guard):
    sl = guard.get_fallback_stoploss("BTC/USDT", 61000)
    assert sl == -0.02

# --- Phase 3 tests ---

def test_graduated_degraded_tightens_stop(guard):
    snapshot = {"execution_plan": {"stop_price": 59000, "entry_price": 61000}}
    guard.update_from_snapshot("BTC/USDT", snapshot, _now())
    result = guard.update_from_snapshot("BTC/USDT", None, _now())
    assert result["state"] == "degraded"
    # Tightened: 61000 + (59000 - 61000) * 0.7 = 61000 - 1400 = 59600
    assert result["stop_price"] is not None
    assert result["stop_price"] > 59000  # tightened closer to entry

def test_graduated_emergency_after_6_misses():
    config = {"max_snapshot_miss_ticks": 3, "hard_disconnect_timeout_ms": 30000,
              "fallback_stop_pct": 0.02, "emergency_miss_ticks": 6}
    guard = RuntimeSnapshotGuard(config)
    snapshot = {"execution_plan": {"stop_price": 60000}}
    guard.update_from_snapshot("BTC/USDT", snapshot, _now())
    for _ in range(6):
        guard.update_from_snapshot("BTC/USDT", None, _now())
    result = guard.update_from_snapshot("BTC/USDT", None, _now())
    assert result["state"] == "emergency"

def test_reconnection_detection(guard):
    snapshot = {"execution_plan": {"stop_price": 60000}}
    guard.update_from_snapshot("BTC/USDT", snapshot, _now())
    for _ in range(4):
        guard.update_from_snapshot("BTC/USDT", None, _now())
    result = guard.update_from_snapshot("BTC/USDT", snapshot, _now())
    assert result.get("reconnected") is True
    assert result["state"] == "healthy"

def test_emergency_force_close():
    config = {"max_snapshot_miss_ticks": 3, "hard_disconnect_timeout_ms": 999999,
              "fallback_stop_pct": 0.02, "emergency_miss_ticks": 6}
    guard = RuntimeSnapshotGuard(config)
    snapshot = {"execution_plan": {"stop_price": 60000}}
    guard.update_from_snapshot("BTC/USDT", snapshot, _now())
    for _ in range(7):
        guard.update_from_snapshot("BTC/USDT", None, _now())
    result = guard.should_emergency_close("BTC/USDT", 65000, "long", _now())
    assert result["close"] is True
    assert "emergency" in result["reason"]

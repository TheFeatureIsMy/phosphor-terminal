"""Tests for ProviderHealthBroadcaster."""
from app.services.providers.realtime.health_broadcaster import ProviderHealthBroadcaster


def test_subscribe_publish_unsubscribe():
    b = ProviderHealthBroadcaster()
    q1 = b.subscribe()
    q2 = b.subscribe()
    b.publish({"type": "update", "n": 1})
    b.publish({"type": "update", "n": 2})
    assert q1.get_nowait() == {"type": "update", "n": 1}
    assert q2.get_nowait() == {"type": "update", "n": 1}
    assert q1.get_nowait() == {"type": "update", "n": 2}
    b.unsubscribe(q1)
    b.publish({"type": "update", "n": 3})
    assert q1.empty()
    assert q2.get_nowait() == {"type": "update", "n": 2}
    assert q2.get_nowait() == {"type": "update", "n": 3}


def test_publish_does_not_block_on_full_queue():
    b = ProviderHealthBroadcaster()
    q = b.subscribe()
    for i in range(150):
        b.publish({"i": i})
    assert q.qsize() <= 100

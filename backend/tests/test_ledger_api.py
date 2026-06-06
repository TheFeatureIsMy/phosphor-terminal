"""Execution Ledger API tests — end-to-end via TestClient."""
import uuid
from datetime import datetime, timezone

from fastapi.testclient import TestClient


class TestPostEvent:
    def test_create_event(self, client: TestClient):
        body = {
            "event_type": "PULSEDESK_COMMAND_STARTED",
            "source_system": "pulsedesk",
            "normalized_payload": {"cmd": "deploy_rules"},
        }
        resp = client.post("/api/v2/ledger/events", json=body)
        assert resp.status_code == 201
        data = resp.json()
        assert data["event_type"] == "PULSEDESK_COMMAND_STARTED"
        assert data["source_system"] == "pulsedesk"
        assert data["schema_version"] == "2.5"
        assert len(data["event_hash"]) == 64
        assert data["normalized_payload"] == {"cmd": "deploy_rules"}

    def test_create_with_all_fields(self, client: TestClient):
        corr = str(uuid.uuid4())
        cause = str(uuid.uuid4())
        cmd = str(uuid.uuid4())
        run = str(uuid.uuid4())
        body = {
            "event_type": "FREQTRADE_ORDER_OPENED",
            "source_system": "freqtrade",
            "source_event_id": "order-789",
            "normalized_payload": {"order_id": "789", "symbol": "BTC/USDT"},
            "raw_payload": {"raw": True},
            "event_time": datetime.now(timezone.utc).isoformat(),
            "strategy_run_id": run,
            "command_id": cmd,
            "correlation_id": corr,
            "causation_id": cause,
            "symbol": "BTC/USDT",
            "sequence_no": 42,
        }
        resp = client.post("/api/v2/ledger/events", json=body)
        assert resp.status_code == 201
        data = resp.json()
        assert data["correlation_id"] == corr
        assert data["causation_id"] == cause
        assert data["command_id"] == cmd
        assert data["symbol"] == "BTC/USDT"
        assert data["raw_payload"] == {"raw": True}

    def test_idempotent_post(self, client: TestClient):
        now = datetime.now(timezone.utc).isoformat()
        body = {
            "event_type": "PULSEDESK_COMMAND_SUCCEEDED",
            "source_system": "pulsedesk",
            "source_event_id": "cmd-dedup",
            "normalized_payload": {"done": True},
            "event_time": now,
        }
        r1 = client.post("/api/v2/ledger/events", json=body)
        assert r1.status_code == 201
        id1 = r1.json()["id"]

        r2 = client.post("/api/v2/ledger/events", json=body)
        assert r2.status_code == 201
        assert r2.json()["id"] == id1

    def test_validation_error(self, client: TestClient):
        resp = client.post("/api/v2/ledger/events", json={
            "source_system": "pulsedesk",
            "normalized_payload": {"x": 1},
        })
        assert resp.status_code == 422


class TestGetEvent:
    def test_get_by_id(self, client: TestClient):
        r = client.post("/api/v2/ledger/events", json={
            "event_type": "FREQTRADE_RUN_STARTED",
            "source_system": "freqtrade",
            "normalized_payload": {"run": "lookup"},
        })
        eid = r.json()["id"]
        resp = client.get(f"/api/v2/ledger/events/{eid}")
        assert resp.status_code == 200
        assert resp.json()["id"] == eid

    def test_get_not_found(self, client: TestClient):
        resp = client.get(f"/api/v2/ledger/events/{uuid.uuid4()}")
        assert resp.status_code == 404


class TestListEvents:
    def test_list_with_filter(self, client: TestClient):
        run_id = str(uuid.uuid4())
        for i in range(3):
            client.post("/api/v2/ledger/events", json={
                "event_type": "FREQTRADE_ORDER_FILLED",
                "source_system": "freqtrade",
                "normalized_payload": {"i": i},
                "strategy_run_id": run_id,
            })
        client.post("/api/v2/ledger/events", json={
            "event_type": "PULSEDESK_COMMAND_STARTED",
            "source_system": "pulsedesk",
            "normalized_payload": {"noise": True},
        })

        resp = client.get("/api/v2/ledger/events", params={"strategy_run_id": run_id})
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["items"]) == 3

    def test_list_by_correlation(self, client: TestClient):
        corr = str(uuid.uuid4())
        for i in range(2):
            client.post("/api/v2/ledger/events", json={
                "event_type": "FREQTRADE_ORDER_OPENED",
                "source_system": "freqtrade",
                "normalized_payload": {"corr": i},
                "correlation_id": corr,
            })
        resp = client.get("/api/v2/ledger/events", params={"correlation_id": corr})
        assert resp.status_code == 200
        assert len(resp.json()["items"]) == 2

    def test_pagination(self, client: TestClient):
        run_id = str(uuid.uuid4())
        for i in range(5):
            client.post("/api/v2/ledger/events", json={
                "event_type": "FREQTRADE_RUN_HEARTBEAT",
                "source_system": "freqtrade",
                "normalized_payload": {"beat": i},
                "strategy_run_id": run_id,
            })
        resp = client.get("/api/v2/ledger/events", params={
            "strategy_run_id": run_id, "offset": 0, "limit": 2,
        })
        assert resp.status_code == 200
        data = resp.json()
        assert len(data["items"]) == 2
        assert data["offset"] == 0
        assert data["limit"] == 2

"""Tests for v2.5 Strategy API — CRUD + versions + DSL validation."""

from fastapi.testclient import TestClient

VALID_DSL = {
    "schema_version": "2.5",
    "timeframe": "1h",
    "symbols": ["BTC/USDT"],
    "entry": {
        "logic": "AND",
        "rules": [
            {
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": "<",
                "value": 30,
            }
        ],
    },
    "exit": {
        "logic": "OR",
        "rules": [
            {
                "type": "indicator_threshold",
                "indicator": "rsi",
                "params": {"period": 14},
                "operator": ">",
                "value": 70,
            }
        ],
    },
    "filters": [],
    "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
    "risk": {"stoploss": -0.05, "max_open_trades": 3},
    "metadata": {},
}

INVALID_DSL_BAD_INDICATOR = {
    **VALID_DSL,
    "entry": {
        "logic": "AND",
        "rules": [
            {
                "type": "indicator_threshold",
                "indicator": "magic_indicator",
                "params": {},
                "operator": "<",
                "value": 30,
            }
        ],
    },
}

INVALID_DSL_NO_STOPLOSS = {
    **VALID_DSL,
    "risk": {"max_open_trades": 3},
}


def _create_strategy(client: TestClient, name: str = "Test RSI Strategy") -> dict:
    resp = client.post("/api/v2/strategies", json={
        "name": name,
        "strategy_type": "rule_dsl",
        "source_type": "manual",
    })
    assert resp.status_code == 201
    return resp.json()


class TestCreateStrategy:
    def test_create_success(self, client: TestClient):
        body = _create_strategy(client)
        assert body["name"] == "Test RSI Strategy"
        assert body["strategy_type"] == "rule_dsl"
        assert body["status"] == "draft"
        assert body["id"] is not None

    def test_create_empty_name_rejected(self, client: TestClient):
        resp = client.post("/api/v2/strategies", json={
            "name": "",
            "strategy_type": "rule_dsl",
        })
        assert resp.status_code == 422


class TestListStrategies:
    def test_list_empty(self, client: TestClient):
        resp = client.get("/api/v2/strategies")
        assert resp.status_code == 200
        assert resp.json() == []

    def test_list_returns_created(self, client: TestClient):
        _create_strategy(client, "Alpha")
        _create_strategy(client, "Beta")
        resp = client.get("/api/v2/strategies")
        assert resp.status_code == 200
        assert len(resp.json()) == 2


class TestGetStrategy:
    def test_get_success(self, client: TestClient):
        created = _create_strategy(client)
        resp = client.get(f"/api/v2/strategies/{created['id']}")
        assert resp.status_code == 200
        assert resp.json()["name"] == "Test RSI Strategy"

    def test_get_not_found(self, client: TestClient):
        resp = client.get("/api/v2/strategies/00000000-0000-0000-0000-000000000000")
        assert resp.status_code == 404


class TestCreateVersion:
    def test_create_version_valid_dsl(self, client: TestClient):
        strategy = _create_strategy(client)
        resp = client.post(
            f"/api/v2/strategies/{strategy['id']}/versions",
            json={"rule_dsl": VALID_DSL},
        )
        assert resp.status_code == 201
        body = resp.json()
        assert body["version_no"] == 1
        assert body["dsl_version"] == "2.5"
        assert body["dsl_hash"] is not None
        assert body["strategy_id"] == strategy["id"]

    def test_create_version_increments(self, client: TestClient):
        strategy = _create_strategy(client)
        client.post(f"/api/v2/strategies/{strategy['id']}/versions", json={"rule_dsl": VALID_DSL})
        resp = client.post(f"/api/v2/strategies/{strategy['id']}/versions", json={"rule_dsl": VALID_DSL})
        assert resp.status_code == 201
        assert resp.json()["version_no"] == 2

    def test_create_version_invalid_dsl_rejected(self, client: TestClient):
        strategy = _create_strategy(client)
        resp = client.post(
            f"/api/v2/strategies/{strategy['id']}/versions",
            json={"rule_dsl": INVALID_DSL_BAD_INDICATOR},
        )
        assert resp.status_code == 422
        detail = resp.json()["detail"]
        assert detail["message"] == "DSL validation failed"
        assert any(e["code"] == "DSL_UNSUPPORTED_INDICATOR" for e in detail["errors"])

    def test_create_version_strategy_not_found(self, client: TestClient):
        resp = client.post(
            "/api/v2/strategies/00000000-0000-0000-0000-000000000000/versions",
            json={"rule_dsl": VALID_DSL},
        )
        assert resp.status_code == 404


class TestListVersions:
    def test_list_versions(self, client: TestClient):
        strategy = _create_strategy(client)
        client.post(f"/api/v2/strategies/{strategy['id']}/versions", json={"rule_dsl": VALID_DSL})
        client.post(f"/api/v2/strategies/{strategy['id']}/versions", json={"rule_dsl": VALID_DSL})
        resp = client.get(f"/api/v2/strategies/{strategy['id']}/versions")
        assert resp.status_code == 200
        versions = resp.json()
        assert len(versions) == 2
        assert versions[0]["version_no"] == 2
        assert versions[1]["version_no"] == 1


class TestValidateDSL:
    def test_validate_valid_dsl(self, client: TestClient):
        resp = client.post("/api/v2/strategies/validate-dsl", json={"dsl": VALID_DSL})
        assert resp.status_code == 200
        body = resp.json()
        assert body["valid"] is True
        assert body["error_count"] == 0

    def test_validate_bad_indicator(self, client: TestClient):
        resp = client.post("/api/v2/strategies/validate-dsl", json={"dsl": INVALID_DSL_BAD_INDICATOR})
        assert resp.status_code == 200
        body = resp.json()
        assert body["valid"] is False
        assert body["error_count"] > 0
        codes = [e["code"] for e in body["errors"]]
        assert "DSL_UNSUPPORTED_INDICATOR" in codes

    def test_validate_missing_stoploss(self, client: TestClient):
        resp = client.post("/api/v2/strategies/validate-dsl", json={"dsl": INVALID_DSL_NO_STOPLOSS})
        assert resp.status_code == 200
        body = resp.json()
        assert body["valid"] is False
        codes = [e["code"] for e in body["errors"]]
        assert "DSL_RISK_FIELD_MISSING" in codes


class TestUpdateStrategy:
    def test_update_name(self, client: TestClient):
        created = _create_strategy(client)
        resp = client.patch(f"/api/v2/strategies/{created['id']}", json={"name": "Updated Name"})
        assert resp.status_code == 200
        assert resp.json()["name"] == "Updated Name"

    def test_update_status(self, client: TestClient):
        created = _create_strategy(client)
        resp = client.patch(f"/api/v2/strategies/{created['id']}", json={"status": "active"})
        assert resp.status_code == 200
        assert resp.json()["status"] == "active"

    def test_update_not_found(self, client: TestClient):
        resp = client.patch(
            "/api/v2/strategies/00000000-0000-0000-0000-000000000000",
            json={"name": "X"},
        )
        assert resp.status_code == 404


class TestGetVersion:
    def test_get_version_by_id(self, client: TestClient):
        strategy = _create_strategy(client)
        v_resp = client.post(
            f"/api/v2/strategies/{strategy['id']}/versions",
            json={"rule_dsl": VALID_DSL},
        )
        vid = v_resp.json()["id"]
        resp = client.get(f"/api/v2/strategies/{strategy['id']}/versions/{vid}")
        assert resp.status_code == 200
        assert resp.json()["version_no"] == 1

    def test_get_version_wrong_strategy(self, client: TestClient):
        strategy = _create_strategy(client)
        v_resp = client.post(
            f"/api/v2/strategies/{strategy['id']}/versions",
            json={"rule_dsl": VALID_DSL},
        )
        vid = v_resp.json()["id"]
        resp = client.get(f"/api/v2/strategies/00000000-0000-0000-0000-000000000000/versions/{vid}")
        assert resp.status_code == 404


class TestTransitionVersionStatus:
    def test_valid_transition(self, client: TestClient):
        strategy = _create_strategy(client)
        v_resp = client.post(
            f"/api/v2/strategies/{strategy['id']}/versions",
            json={"rule_dsl": VALID_DSL},
        )
        vid = v_resp.json()["id"]
        resp = client.patch(
            f"/api/v2/strategies/{strategy['id']}/versions/{vid}/status",
            json={"to_status": "validated"},
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "validated"

    def test_invalid_transition_returns_409(self, client: TestClient):
        strategy = _create_strategy(client)
        v_resp = client.post(
            f"/api/v2/strategies/{strategy['id']}/versions",
            json={"rule_dsl": VALID_DSL},
        )
        vid = v_resp.json()["id"]
        resp = client.patch(
            f"/api/v2/strategies/{strategy['id']}/versions/{vid}/status",
            json={"to_status": "paper_running"},
        )
        assert resp.status_code == 409

    def test_system_only_returns_403(self, client: TestClient):
        strategy = _create_strategy(client)
        v_resp = client.post(
            f"/api/v2/strategies/{strategy['id']}/versions",
            json={"rule_dsl": VALID_DSL},
        )
        vid = v_resp.json()["id"]
        # First transition to validated
        client.patch(
            f"/api/v2/strategies/{strategy['id']}/versions/{vid}/status",
            json={"to_status": "validated"},
        )
        # validated -> backtested is system-only
        resp = client.patch(
            f"/api/v2/strategies/{strategy['id']}/versions/{vid}/status",
            json={"to_status": "backtested"},
        )
        assert resp.status_code == 403


class TestVersionDiff:
    def test_diff_two_versions(self, client: TestClient):
        strategy = _create_strategy(client)
        v1 = client.post(
            f"/api/v2/strategies/{strategy['id']}/versions",
            json={"rule_dsl": VALID_DSL},
        ).json()

        modified_dsl = {**VALID_DSL, "timeframe": "4h"}
        v2 = client.post(
            f"/api/v2/strategies/{strategy['id']}/versions",
            json={"rule_dsl": modified_dsl},
        ).json()

        resp = client.get(
            f"/api/v2/strategies/{strategy['id']}/versions/diff",
            params={"from_vid": v1["id"], "to_vid": v2["id"]},
        )
        assert resp.status_code == 200
        body = resp.json()
        assert body["from_version_no"] == 1
        assert body["to_version_no"] == 2
        assert "timeframe" in body["changed"]

    def test_diff_version_not_found(self, client: TestClient):
        strategy = _create_strategy(client)
        v1 = client.post(
            f"/api/v2/strategies/{strategy['id']}/versions",
            json={"rule_dsl": VALID_DSL},
        ).json()
        resp = client.get(
            f"/api/v2/strategies/{strategy['id']}/versions/diff",
            params={"from_vid": v1["id"], "to_vid": "00000000-0000-0000-0000-000000000000"},
        )
        assert resp.status_code == 404

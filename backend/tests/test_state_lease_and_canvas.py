"""Phase 4 tests — StateLeaseService + /api/state-leases, canvas
compile/save-draft/publish/templates, reconciliation lease integration.
"""
from __future__ import annotations

import uuid
from datetime import timedelta

import pytest

from app.domain.reconciliation import StateLease
from app.domain.strategy import StrategyV2
from app.routers.canvas import CANVAS_TEMPLATES
from app.services.dsl_validator import DSLValidator
from app.services.state_lease_service import StateLeaseService, _utcnow


def _sample_dsl() -> dict:
    return {
        "schema_version": "2.5",
        "timeframe": "1d",
        "symbols": ["BTC/USDT"],
        "entry": {
            "logic": "AND",
            "rules": [
                {"type": "indicator_threshold", "indicator": "rsi", "operator": "<",
                 "value": 30, "params": {"period": 14}},
            ],
        },
        "exit": {
            "logic": "OR",
            "rules": [
                {"type": "indicator_threshold", "indicator": "rsi", "operator": ">",
                 "value": 70, "params": {"period": 14}},
            ],
        },
        "filters": [],
        "position_sizing": {"position_pct": 0.05},
        "risk": {"stoploss": -0.05, "max_open_trades": 3, "trailing_stop": False},
    }


# ══════════════════════════════════════════════════════════════════════
# StateLeaseService
# ══════════════════════════════════════════════════════════════════════

class TestStateLeaseService:
    def test_acquire_and_list(self, session):
        svc = StateLeaseService(session)
        lease, status = svc.acquire("reconciliation:r1", "worker-a", ttl_sec=60)
        assert status == "acquired" and lease is not None
        assert [lk.resource_key for lk in svc.list_active()] == ["reconciliation:r1"]

    def test_second_owner_blocked(self, session):
        svc = StateLeaseService(session)
        svc.acquire("reconciliation:r1", "worker-a", ttl_sec=60)
        lease, status = svc.acquire("reconciliation:r1", "worker-b", ttl_sec=60)
        assert lease is None and status == "already_held"

    def test_same_owner_renews(self, session):
        svc = StateLeaseService(session)
        svc.acquire("k", "owner-a", ttl_sec=60)
        lease, status = svc.acquire("k", "owner-a", ttl_sec=120)
        assert status == "renewed_own"

    def test_expired_lease_taken_over(self, session):
        svc = StateLeaseService(session)
        lease, _ = svc.acquire("k", "owner-a", ttl_sec=60)
        lease.expires_at = _utcnow() - timedelta(seconds=1)
        session.flush()
        lease2, status = svc.acquire("k", "owner-b", ttl_sec=60)
        assert status == "taken_over"
        assert lease2.owner == "owner-b"

    def test_release_allows_new_acquire(self, session):
        svc = StateLeaseService(session)
        svc.acquire("k", "owner-a", ttl_sec=60)
        assert svc.release("k", "owner-a") is True
        lease, status = svc.acquire("k", "owner-b", ttl_sec=60)
        assert status == "taken_over"

    def test_renew_only_by_owner(self, session):
        svc = StateLeaseService(session)
        svc.acquire("k", "owner-a", ttl_sec=60)
        assert svc.renew("k", "owner-b") is False
        assert svc.renew("k", "owner-a") is True

    def test_force_release_only_expired(self, session):
        svc = StateLeaseService(session)
        lease, _ = svc.acquire("k", "owner-a", ttl_sec=60)
        assert svc.force_release_expired("k") is False  # still active
        lease.expires_at = _utcnow() - timedelta(seconds=1)
        session.flush()
        assert svc.force_release_expired("k") is True


class TestStateLeaseRouter:
    def test_list_endpoint(self, client, session):
        svc = StateLeaseService(session)
        svc.acquire("reconciliation:r1", "worker-a", ttl_sec=60)
        session.commit()
        r = client.get("/api/state-leases")
        assert r.status_code == 200
        body = r.json()
        assert body["total"] == 1
        assert body["leases"][0]["resource_key"] == "reconciliation:r1"


class TestReconciliationLeaseIntegration:
    def test_concurrent_start_blocked_by_lease(self, session):
        from app.services.reconciliation_service import ReconciliationService

        svc = ReconciliationService(session)
        run_id = uuid.uuid4()
        ft_id = uuid.uuid4()
        svc.start_reconciliation(run_id, ft_id)

        # Second start for the same run must be rejected while lease is held
        svc2 = ReconciliationService(session)
        with pytest.raises(RuntimeError, match="state lease held"):
            svc2.start_reconciliation(run_id, ft_id)

    def test_complete_releases_lease(self, session):
        from app.domain.execution import FreqtradeRun, StrategyRun
        from app.domain.strategy import StrategyVersion, StrategyV2
        from app.services.reconciliation_service import ReconciliationService

        strategy = StrategyV2(name="s", strategy_type="dsl", source_type="manual")
        session.add(strategy)
        session.flush()
        version = StrategyVersion(
            strategy_id=strategy.id, version_no=1, status="draft",
            dsl_version="2.5", rule_dsl=_sample_dsl(), dsl_hash="h", created_by="t",
        )
        session.add(version)
        session.flush()
        run = StrategyRun(strategy_version_id=version.id, mode="dry_run", status="running")
        session.add(run)
        session.flush()
        ft_run = FreqtradeRun(
            strategy_run_id=run.id, status="running",
            config_path="/tmp/config.json", rules_path="/tmp/rules.json",
            rule_package_hash="h",
        )
        session.add(ft_run)
        session.flush()

        svc = ReconciliationService(session)
        event = svc.start_reconciliation(run.id, ft_run.id)
        svc.execute(event.id, freqtrade_positions=[])
        svc.complete(event.id, success=True)

        # Lease released → a new start succeeds
        svc2 = ReconciliationService(session)
        event2 = svc2.start_reconciliation(run.id, ft_run.id)
        assert event2.status == "started"


# ══════════════════════════════════════════════════════════════════════
# Canvas compile / save-draft / publish / templates
# ══════════════════════════════════════════════════════════════════════

class TestCanvasTemplates:
    def test_all_templates_pass_validation(self):
        validator = DSLValidator()
        for tpl in CANVAS_TEMPLATES:
            report = validator.validate(tpl["dsl"])
            assert report.valid, f"template {tpl['name']} invalid: {report.errors}"


class TestCanvasEndpoints:
    def _make_strategy(self, session) -> StrategyV2:
        s = StrategyV2(name="canvas-strategy", strategy_type="dsl", source_type="manual")
        session.add(s)
        session.commit()
        return s

    def test_compile_valid_dsl(self, client, session):
        r = client.post("/api/canvas/compile", json={
            "dsl": _sample_dsl(), "graph": {"nodes": [], "edges": []},
        })
        assert r.status_code == 200
        body = r.json()
        assert body["state"] == "healthy"
        assert body["validation"]["valid"] is True
        assert body["dsl_hash"]

    def test_compile_invalid_dsl_blocked(self, client, session):
        dsl = _sample_dsl()
        dsl["entry"]["rules"][0]["operator"] = "~~bad~~"
        r = client.post("/api/canvas/compile", json={"dsl": dsl})
        body = r.json()
        assert body["state"] == "blocked"
        assert body["validation"]["valid"] is False

    def test_save_and_load_draft(self, client, session):
        s = self._make_strategy(session)
        graph = {"nodes": [{"id": "n1"}], "edges": []}
        r = client.post("/api/canvas/save-draft", json={
            "strategy_id": str(s.id), "graph": graph, "dsl": _sample_dsl(),
        })
        assert r.status_code == 200
        assert r.json()["dsl_hash"]

        r2 = client.get(f"/api/canvas/strategies/{s.id}")
        draft = r2.json()["draft"]
        assert draft["graph"] == graph
        assert draft["dsl"] == _sample_dsl()

        # Upsert: second save replaces the draft, no duplicate
        client.post("/api/canvas/save-draft", json={
            "strategy_id": str(s.id), "graph": {"nodes": []}, "dsl": _sample_dsl(),
        })
        draft2 = client.get(f"/api/canvas/strategies/{s.id}").json()["draft"]
        assert draft2["graph"] == {"nodes": []}

    def test_load_missing_draft_reports_no_draft(self, client, session):
        r = client.get(f"/api/canvas/strategies/{uuid.uuid4()}")
        assert r.status_code == 200
        assert r.json()["draft"] is None
        assert r.json()["reason_codes"] == ["no_draft"]

    def test_publish_creates_draft_version(self, client, session):
        s = self._make_strategy(session)
        r = client.post("/api/canvas/publish", json={
            "strategy_id": str(s.id), "dsl": _sample_dsl(),
        })
        assert r.status_code == 201
        body = r.json()
        assert body["status"] == "draft"
        assert body["version_no"] == 1
        assert body["dsl_hash"]

    def test_publish_invalid_dsl_422(self, client, session):
        s = self._make_strategy(session)
        dsl = _sample_dsl()
        del dsl["risk"]["stoploss"]
        r = client.post("/api/canvas/publish", json={"strategy_id": str(s.id), "dsl": dsl})
        assert r.status_code == 422

    def test_publish_unknown_strategy_404(self, client, session):
        r = client.post("/api/canvas/publish", json={
            "strategy_id": str(uuid.uuid4()), "dsl": _sample_dsl(),
        })
        assert r.status_code == 404

    def test_templates_endpoint(self, client, session):
        r = client.get("/api/canvas/templates")
        assert r.status_code == 200
        assert len(r.json()["templates"]) >= 2

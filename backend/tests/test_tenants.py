"""Tenant bootstrap: first user owns a tenant; JWT carries tid/role."""
from app.models.tenant import Membership, Tenant
from app.services.auth import decode_token


def _register(client, username="tenantuser"):
    resp = client.post("/auth/register", json={
        "username": username,
        "email": f"{username}@example.com",
        "password": "secret123",
    })
    assert resp.status_code == 201
    return resp.json()


def _login(client, username="tenantuser"):
    resp = client.post("/auth/login", data={
        "username": f"{username}@example.com",
        "password": "secret123",
    })
    assert resp.status_code == 200
    return resp.json()


def test_register_creates_tenant_and_owner_membership(client, session):
    user = _register(client)

    tenant = session.query(Tenant).filter(Tenant.name == "tenantuser").first()
    assert tenant is not None
    assert tenant.slug.startswith("tenantuser-")

    membership = (
        session.query(Membership)
        .filter(Membership.user_id == user["id"], Membership.tenant_id == tenant.id)
        .first()
    )
    assert membership is not None
    assert membership.role == "owner"


def test_login_token_contains_tenant_claims(client, session):
    _register(client)
    tenant = session.query(Tenant).first()
    tokens = _login(client)

    payload = decode_token(tokens["access_token"])
    assert payload is not None
    assert payload["tid"] == str(tenant.id)
    assert payload["role"] == "owner"

    refresh = decode_token(tokens["refresh_token"])
    assert refresh["tid"] == str(tenant.id)


def test_tenant_endpoint_returns_current_tenant(client):
    _register(client)
    tokens = _login(client)
    resp = client.get(
        "/auth/tenant",
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["role"] == "owner"
    assert body["slug"].startswith("tenantuser-")


def test_refresh_keeps_tenant_claims(client):
    _register(client)
    tokens = _login(client)
    resp = client.post("/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert resp.status_code == 200
    payload = decode_token(resp.json()["access_token"])
    assert payload.get("tid") == decode_token(tokens["access_token"]).get("tid")


def test_strategy_visibility_is_tenant_scoped(client, session, monkeypatch):
    from app.config import settings
    from app.models.tenant import Membership, Tenant
    from app.models.user import User
    from app.services.auth import create_access_token

    monkeypatch.setattr(settings, "auth_required", True)

    # Tenant A through the real registration flow.
    _register(client, "alice")
    alice = _login(client, "alice")
    alice_headers = {"Authorization": f"Bearer {alice['access_token']}"}

    created = client.post(
        "/api/v2/strategies",
        json={"name": "alice-only", "strategy_type": "rule_dsl", "source_type": "manual"},
        headers=alice_headers,
    )
    assert created.status_code == 201
    strategy_id = created.json()["id"]

    alice_tenant = session.query(Tenant).filter(Tenant.name == "alice").first()
    strategy_row = session.get(
        __import__("app.domain.strategy", fromlist=["StrategyV2"]).StrategyV2,
        __import__("uuid").UUID(strategy_id),
    )
    assert strategy_row.tenant_id == alice_tenant.id

    # Tenant B, created directly (registration is closed after the first user).
    bob = User(
        username="bob", email="bob@example.com",
        hashed_password="x", is_active=True, is_superuser=False,
    )
    session.add(bob)
    session.flush()
    bob_tenant = Tenant(name="bob", slug="bob-test")
    session.add(bob_tenant)
    session.flush()
    session.add(Membership(user_id=bob.id, tenant_id=bob_tenant.id, role="owner"))
    session.commit()
    bob_token = create_access_token(
        {"sub": str(bob.id), "tid": str(bob_tenant.id), "role": "owner"}
    )
    bob_headers = {"Authorization": f"Bearer {bob_token}"}

    listing = client.get("/api/v2/strategies", headers=bob_headers)
    assert listing.status_code == 200
    assert all(item["id"] != strategy_id for item in listing.json())

    assert client.get(f"/api/v2/strategies/{strategy_id}", headers=bob_headers).status_code == 404
    assert client.get(
        f"/api/v2/strategies/{strategy_id}/versions", headers=bob_headers
    ).status_code == 404

    alice_listing = client.get("/api/v2/strategies", headers=alice_headers)
    assert any(item["id"] == strategy_id for item in alice_listing.json())


def test_backtest_runs_are_tenant_scoped(client, session, monkeypatch):
    from unittest.mock import patch

    from app.config import settings
    from app.models.strategy import BacktestRun
    from app.models.tenant import Membership, Tenant
    from app.models.user import User
    from app.services.auth import create_access_token
    from app.services.backtest_runner import BacktestMetrics, BacktestResult
    from app.workers.command_worker import CommandWorker

    monkeypatch.setattr(settings, "auth_required", True)
    _register(client, "carol")
    carol = _login(client, "carol")
    headers = {"Authorization": f"Bearer {carol['access_token']}"}

    strategy = client.post(
        "/api/v2/strategies",
        json={"name": "bt", "strategy_type": "rule_dsl", "source_type": "manual"},
        headers=headers,
    ).json()
    dsl = {
        "schema_version": "2.5", "timeframe": "1h", "symbols": ["BTC/USDT"],
        "entry": {"logic": "AND", "rules": [{"type": "indicator_threshold", "indicator": "rsi",
                  "params": {"period": 14}, "operator": "<", "value": 30}]},
        "exit": {"logic": "OR", "rules": [{"type": "indicator_threshold", "indicator": "rsi",
                  "params": {"period": 14}, "operator": ">", "value": 70}]},
        "filters": [], "position_sizing": {"type": "fixed_pct", "position_pct": 0.02},
        "risk": {"stoploss": -0.05, "max_open_trades": 2}, "metadata": {},
    }
    version = client.post(
        f"/api/v2/strategies/{strategy['id']}/versions",
        json={"rule_dsl": dsl}, headers=headers,
    ).json()

    started = client.post("/api/v2/backtest", json={
        "dsl": dsl, "timerange": "20240101-20240601", "symbols": ["BTC/USDT"],
        "initial_capital": 10000, "strategy_version_id": version["id"],
        "client_request_id": "tenant-bt",
    }, headers=headers)
    assert started.status_code == 202

    with patch("app.workers.backtest_handler.FreqtradeBacktestRunner") as runner_cls:
        runner_cls.return_value.run.return_value = BacktestResult(
            success=True, metrics=BacktestMetrics(total_trades=3), trades=[], equity_curve=[]
        )
        assert CommandWorker(session).poll_once() is True
        session.commit()

    run = session.query(BacktestRun).first()
    carol_tenant = session.query(Tenant).filter(Tenant.name == "carol").first()
    assert run.tenant_id == carol_tenant.id

    # A second tenant cannot list or read the run.
    dave = User(username="dave", email="dave@example.com", hashed_password="x",
                is_active=True, is_superuser=False)
    session.add(dave)
    session.flush()
    dave_tenant = Tenant(name="dave", slug="dave-test")
    session.add(dave_tenant)
    session.flush()
    session.add(Membership(user_id=dave.id, tenant_id=dave_tenant.id, role="owner"))
    session.commit()
    token = create_access_token({"sub": str(dave.id), "tid": str(dave_tenant.id), "role": "owner"})
    dave_headers = {"Authorization": f"Bearer {token}"}

    assert client.get("/api/v2/backtest", headers=dave_headers).json() == []
    assert client.get(f"/api/v2/backtest/{run.id}", headers=dave_headers).status_code == 404
    assert client.get(f"/api/v2/backtest/{run.id}", headers=headers).status_code == 200


def test_strategy_runs_are_tenant_scoped(client, session, monkeypatch):
    import uuid

    from app.config import settings
    from app.domain.execution import StrategyRun
    from app.domain.strategy import StrategyV2, StrategyVersion
    from app.models.tenant import Tenant
    from app.models.user import User
    from app.services.auth import create_access_token

    monkeypatch.setattr(settings, "auth_required", True)

    tenant_a = Tenant(name="run-a", slug="run-a")
    tenant_b = Tenant(name="run-b", slug="run-b")
    session.add_all([tenant_a, tenant_b])
    session.flush()

    strategy_a = StrategyV2(
        name="run-a-strategy", strategy_type="rule_dsl", source_type="manual",
        status="draft", tenant_id=tenant_a.id,
    )
    session.add(strategy_a)
    session.flush()
    version_a = StrategyVersion(
        strategy_id=strategy_a.id, version_no=1, status="draft", dsl_version="2.5",
        rule_dsl={}, dsl_hash="h", created_by="test", tenant_id=tenant_a.id,
    )
    session.add(version_a)
    session.flush()
    run = StrategyRun(strategy_version_id=version_a.id, mode="dry_run", status="running")
    session.add(run)
    session.commit()

    def _token(tid: int) -> str:
        user = User(
            username=f"u{tid}", email=f"u{tid}@example.com", hashed_password="x",
            is_active=True, is_superuser=False,
        )
        session.add(user)
        session.flush()
        return create_access_token({"sub": str(user.id), "tid": str(tid), "role": "owner"})

    a_headers = {"Authorization": f"Bearer {_token(tenant_a.id)}"}
    b_headers = {"Authorization": f"Bearer {_token(tenant_b.id)}"}

    assert client.get(f"/api/v2/strategy-runs/{run.id}", headers=a_headers).status_code == 200
    assert client.get(f"/api/v2/strategy-runs/{run.id}", headers=b_headers).status_code == 404
    assert client.get(f"/api/v2/strategy-runs/{run.id}/orders", headers=b_headers).status_code == 404

    a_list = client.get("/api/v2/strategy-runs", headers=a_headers).json()
    b_list = client.get("/api/v2/strategy-runs", headers=b_headers).json()
    assert any(item["id"] == str(run.id) for item in a_list)
    assert all(item["id"] != str(run.id) for item in b_list)


def test_ledger_events_are_tenant_scoped(client, session, monkeypatch):
    import uuid
    from datetime import datetime, timezone

    from app.config import settings
    from app.domain.execution import StrategyRun
    from app.domain.ledger import ExecutionLedgerEvent
    from app.domain.strategy import StrategyV2, StrategyVersion
    from app.models.tenant import Tenant
    from app.models.user import User
    from app.services.auth import create_access_token

    monkeypatch.setattr(settings, "auth_required", True)

    tenant_a = Tenant(name="ledger-a", slug="ledger-a")
    tenant_b = Tenant(name="ledger-b", slug="ledger-b")
    session.add_all([tenant_a, tenant_b])
    session.flush()
    ledger_strategy = StrategyV2(
        name="ledger-a-strategy", strategy_type="rule_dsl", source_type="manual",
        status="draft", tenant_id=tenant_a.id,
    )
    session.add(ledger_strategy)
    session.flush()
    version = StrategyVersion(
        strategy_id=ledger_strategy.id, version_no=1, status="draft", dsl_version="2.5",
        rule_dsl={}, dsl_hash="h", created_by="test", tenant_id=tenant_a.id,
    )
    session.add(version)
    session.flush()
    run = StrategyRun(strategy_version_id=version.id, mode="dry_run", status="running")
    session.add(run)
    session.flush()
    session.add(ExecutionLedgerEvent(
        event_type="TEST_EVENT", source_system="test", event_hash=uuid.uuid4().hex,
        strategy_run_id=run.id, normalized_payload={},
        event_time=datetime.now(timezone.utc),
    ))
    session.commit()

    def _token(tid: int, name: str) -> str:
        user = User(username=name, email=f"{name}@example.com", hashed_password="x",
                    is_active=True, is_superuser=False)
        session.add(user)
        session.flush()
        return create_access_token({"sub": str(user.id), "tid": str(tid), "role": "owner"})

    a_headers = {"Authorization": f"Bearer {_token(tenant_a.id, 'ledger-a-user')}"}
    b_headers = {"Authorization": f"Bearer {_token(tenant_b.id, 'ledger-b-user')}"}

    a_items = client.get("/api/v2/ledger/events", headers=a_headers).json()["items"]
    b_items = client.get("/api/v2/ledger/events", headers=b_headers).json()["items"]
    assert any(item["event_type"] == "TEST_EVENT" for item in a_items)
    assert all(item["event_type"] != "TEST_EVENT" for item in b_items)


def test_rag_knowledge_is_tenant_scoped(client, session, monkeypatch):
    from app.config import settings
    from app.models.tenant import Membership, Tenant
    from app.models.user import User
    from app.services.auth import create_access_token

    monkeypatch.setattr(settings, "auth_required", True)
    _register(client, "ragalice")
    alice = _login(client, "ragalice")
    a_headers = {"Authorization": f"Bearer {alice['access_token']}"}

    content = b"RSI oversold strategy with volume confirmation"
    up_a = client.post(
        "/rag/upload",
        files={"file": ("a.txt", content, "text/plain")},
        headers=a_headers,
    )
    assert up_a.status_code == 200
    doc_a = up_a.json()["doc_id"]

    bob = User(username="ragbob", email="ragbob@example.com", hashed_password="x",
               is_active=True, is_superuser=False)
    session.add(bob)
    session.flush()
    tenant_b = Tenant(name="ragbob", slug="ragbob-tenant")
    session.add(tenant_b)
    session.flush()
    session.add(Membership(user_id=bob.id, tenant_id=tenant_b.id, role="owner"))
    session.commit()
    b_token = create_access_token({"sub": str(bob.id), "tid": str(tenant_b.id), "role": "owner"})
    b_headers = {"Authorization": f"Bearer {b_token}"}

    search_b = client.post(
        "/rag/search", json={"query": "RSI oversold", "top_k": 5}, headers=b_headers,
    )
    assert search_b.status_code == 200
    assert search_b.json()["results"] == []

    up_b = client.post(
        "/rag/upload",
        files={"file": ("a.txt", content, "text/plain")},
        headers=b_headers,
    )
    assert up_b.status_code == 200
    # Same bytes, different tenant: must not reuse Alice's document id.
    assert up_b.json()["doc_id"] != doc_a

    knowledge_b = client.get("/rag/knowledge", headers=b_headers).json()["documents"]
    assert len(knowledge_b) == 1
    assert knowledge_b[0]["id"] != doc_a


def test_capital_and_risk_lookups_are_tenant_scoped(client, session, monkeypatch):
    import uuid

    from app.config import settings
    from app.domain.risk import CapitalPool, RiskPolicy, RiskPolicyVersion
    from app.models.tenant import Tenant
    from app.services.auth import create_access_token

    monkeypatch.setattr(settings, "auth_required", True)
    ta = Tenant(name="cap-a", slug="cap-a")
    tb = Tenant(name="cap-b", slug="cap-b")
    session.add_all([ta, tb])
    session.flush()

    def pool(tenant, name):
        return CapitalPool(
            tenant_id=tenant.id, name=name, pool_type="live_small", currency="USDT",
            total_budget=10000, max_position_pct_per_trade=0.02,
            max_total_exposure_pct=0.2, max_daily_loss_pct=0.03,
            max_drawdown_pct=0.1,
        )

    session.add_all([pool(ta, "pool-a"), pool(tb, "pool-b")])
    pa = RiskPolicy(tenant_id=ta.id, name="policy-a", policy_type="live_small", status="active")
    pb = RiskPolicy(tenant_id=tb.id, name="policy-b", policy_type="live_small", status="active")
    session.add_all([pa, pb])
    session.flush()
    session.add_all([
        RiskPolicyVersion(
            risk_policy_id=pa.id, version_no=1, policy_json={}, policy_hash="ha",
            status="active", created_by="test",
        ),
        RiskPolicyVersion(
            risk_policy_id=pb.id, version_no=1, policy_json={}, policy_hash="hb",
            status="active", created_by="test",
        ),
    ])
    session.commit()

    token = create_access_token({"sub": "1", "tid": str(ta.id), "role": "owner"})
    headers = {"Authorization": f"Bearer {token}"}

    pools = client.get("/api/capital-pools", headers=headers).json()
    assert {p["name"] for p in pools} == {"pool-a"}
    policies = client.get("/api/risk-policy-versions", headers=headers).json()
    assert {p["policy_name"] for p in policies} == {"policy-a"}

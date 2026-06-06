"""Tests for MCP API."""


class TestMcpStatus:
    def test_get_status(self, client):
        resp = client.get("/api/mcp/status")
        assert resp.status_code == 200
        data = resp.json()
        assert "enabled" in data
        assert data["enabled"] is True
        assert "bind_address" in data


class TestAuditLogs:
    def test_list_empty(self, client):
        resp = client.get("/api/mcp/audit-logs")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_list_with_pagination(self, client):
        resp = client.get("/api/mcp/audit-logs?limit=10&offset=0")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_list_with_tool_filter(self, client):
        resp = client.get("/api/mcp/audit-logs?tool_name=test_tool")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)


class TestRotateToken:
    def test_rotate(self, client):
        resp = client.post("/api/mcp/rotate-token", json={"reason": "test rotation"})
        assert resp.status_code == 200
        data = resp.json()
        assert "new_token" in data
        assert data["old_token_revoked"] is True
        assert len(data["new_token"]) > 0

    def test_rotate_without_reason(self, client):
        resp = client.post("/api/mcp/rotate-token", json={})
        assert resp.status_code == 200
        data = resp.json()
        assert "new_token" in data
        assert data["old_token_revoked"] is True

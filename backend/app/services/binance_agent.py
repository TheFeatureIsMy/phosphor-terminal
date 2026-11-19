"""Official Binance native agent (MCP). OAuth only. Never a local API key."""
from __future__ import annotations

import json
from typing import Any

import aiohttp

from app.services.system_trust import client_ssl_context

BINANCE_MCP_URL = "https://agent.binance.com/mcp/agentic"
MCP_PROTOCOL = "2025-03-26"


def quote_steps(first_status: int) -> list[str]:
    """MCP lifecycle. A non-200 initialize stops before any tool call."""
    if first_status != 200:
        return ["initialize"]
    return ["initialize", "notifications/initialized", "tools/list", "tools/call"]


class BinanceAgentClient:
    """Talks to the Binance Agentic MCP server.

    Authorization is a bearer token from the desktop OAuth grant. This client
    does not accept or send an exchange API key.
    """

    def __init__(self, oauth_token: str | None = None) -> None:
        self._token = (oauth_token or "").strip() or None

    async def rpc(
        self,
        method: str,
        params: dict[str, Any] | None = None,
        *,
        notify: bool = False,
    ) -> dict[str, Any]:
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        if self._token:
            headers["Authorization"] = f"Bearer {self._token}"
        body: dict[str, Any] = {"jsonrpc": "2.0", "method": method}
        if not notify:
            body["id"] = 1
        if params is not None:
            body["params"] = params
        timeout = aiohttp.ClientTimeout(total=20)
        connector = aiohttp.TCPConnector(ssl=client_ssl_context())
        async with aiohttp.ClientSession(timeout=timeout, connector=connector) as session:
            async with session.post(BINANCE_MCP_URL, json=body, headers=headers) as resp:
                text = await resp.text()
                parsed: Any
                try:
                    parsed = json.loads(text)
                except json.JSONDecodeError:
                    parsed = text[:500]
                return {
                    "url": BINANCE_MCP_URL,
                    "status": resp.status,
                    "www_authenticate": resp.headers.get("WWW-Authenticate") or resp.headers.get("www-authenticate"),
                    "body": parsed,
                    "sent_api_key": False,
                }

    async def btc_quote(self) -> dict[str, Any]:
        """Ask the official agent for BTCUSDT. Unauthenticated calls stay as 401."""
        opened = await self.rpc("initialize", {
            "protocolVersion": MCP_PROTOCOL,
            "capabilities": {},
            "clientInfo": {"name": "alphaloop", "version": "1"},
        })
        if quote_steps(opened["status"]) == ["initialize"]:
            opened["tool"] = None
            return opened
        await self.rpc("notifications/initialized", notify=True)
        listed = await self.rpc("tools/list")
        if listed["status"] != 200:
            listed["tool"] = None
            return listed
        tools = ((listed.get("body") or {}).get("result") or {}).get("tools") or []
        name = _price_tool(tools)
        if not name:
            listed["error"] = "no price tool in the authenticated catalog"
            listed["tool"] = None
            return listed
        called = await self.rpc("tools/call", {"name": name, "arguments": {"symbol": "BTCUSDT"}})
        called["tool"] = name
        return called


def _price_tool(tools: list[dict[str, Any]]) -> str | None:
    for tool in tools:
        name = str(tool.get("name") or "")
        blob = name.lower()
        if "btc" in blob or "ticker" in blob or "price" in blob:
            return name
    return None

"""Official Binance MCP client. No local API key, and 401 stops the lifecycle."""
import inspect

from app.services.binance_agent import BINANCE_MCP_URL, BinanceAgentClient, quote_steps


def test_unauthenticated_plan_stops_at_initialize():
    assert quote_steps(401) == ["initialize"]
    assert quote_steps(200) == [
        "initialize",
        "notifications/initialized",
        "tools/list",
        "tools/call",
    ]
    assert quote_steps(200).index("notifications/initialized") < quote_steps(200).index("tools/list")


def test_client_has_no_api_key_parameter_and_uses_the_official_url():
    params = inspect.signature(BinanceAgentClient.__init__).parameters
    assert "api_key" not in params
    assert "api_secret" not in params
    assert BINANCE_MCP_URL == "https://agent.binance.com/mcp/agentic"
    src = inspect.getsource(BinanceAgentClient)
    assert "X-MBX-APIKEY" not in src
    assert "quote_steps" in src

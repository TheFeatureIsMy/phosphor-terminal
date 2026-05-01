import aiohttp
from aiohttp import BasicAuth
from app.config import settings

FT_AUTH = BasicAuth("freqtrade", "freqtrade")


class FreqtradeClient:
    """Control Freqtrade via its REST API."""

    def __init__(self, base_url: str | None = None):
        self.base_url = base_url or settings.freqtrade_url

    async def _get(self, path: str) -> dict:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.get(f"{self.base_url}{path}", auth=FT_AUTH) as resp:
                    if resp.status == 200:
                        return await resp.json()
                    return {"error": f"HTTP {resp.status}", "detail": await resp.text()}
        except Exception as e:
            return {"error": str(e)}

    async def _post(self, path: str, data: dict | None = None) -> dict:
        try:
            async with aiohttp.ClientSession() as session:
                async with session.post(f"{self.base_url}{path}", json=data, auth=FT_AUTH) as resp:
                    if resp.status == 200:
                        return await resp.json()
                    return {"error": f"HTTP {resp.status}", "detail": await resp.text()}
        except Exception as e:
            return {"error": str(e)}

    async def get_status(self) -> dict:
        return await self._get("/api/v1/status")

    async def get_trades(self) -> dict:
        return await self._get("/api/v1/trades")

    async def start_bot(self) -> dict:
        return await self._post("/api/v1/start")

    async def stop_bot(self) -> dict:
        return await self._post("/api/v1/stop")

    async def run_backtest(self, config: dict) -> dict:
        return await self._post("/api/v1/backtest", config)

    async def get_balance(self) -> dict:
        return await self._get("/api/v1/balance")

    async def get_performance(self) -> dict:
        return await self._get("/api/v1/performance")


freqtrade_client = FreqtradeClient()

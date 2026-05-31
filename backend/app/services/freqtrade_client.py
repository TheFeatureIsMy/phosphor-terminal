import aiohttp
from aiohttp import BasicAuth
from app.config import settings
from typing import Optional


class FreqtradeClient:
    """Control Freqtrade via its REST API."""

    def __init__(self, base_url: Optional[str] = None):
        self.base_url = base_url or settings.freqtrade_url
        self._auth = BasicAuth(settings.freqtrade_username, settings.freqtrade_password)

    async def _get(self, path: str) -> dict:
        try:
            timeout = aiohttp.ClientTimeout(total=5)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(f"{self.base_url}{path}", auth=self._auth) as resp:
                    if resp.status == 200:
                        return await resp.json()
                    return {"error": f"HTTP {resp.status}", "detail": await resp.text()}
        except Exception as e:
            return {"error": str(e)}

    async def _post(self, path: str, data: Optional[dict] = None) -> dict:
        try:
            timeout = aiohttp.ClientTimeout(total=10)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.post(f"{self.base_url}{path}", json=data, auth=self._auth) as resp:
                    if resp.status == 200:
                        return await resp.json()
                    return {"error": f"HTTP {resp.status}", "detail": await resp.text()}
        except Exception as e:
            return {"error": str(e)}

    @staticmethod
    def is_success(payload: object) -> bool:
        return not (isinstance(payload, dict) and payload.get("error"))

    async def ping(self) -> bool:
        try:
            timeout = aiohttp.ClientTimeout(total=3)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.get(f"{self.base_url}/api/v1/ping", auth=self._auth) as resp:
                    return resp.status == 200
        except Exception:
            return False

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

    async def submit_backtest(self, config: dict) -> dict:
        """Submit a backtest job and return the job identifier.

        For long-running backtests, use this instead of ``run_backtest`` to
        avoid HTTP timeouts.  Call ``poll_backtest`` with the returned
        ``job_id`` to check progress.
        """
        result = await self._post("/api/v1/backtest", config)
        if self.is_success(result):
            # Freqtrade returns a token/job_id field — normalise it
            job_id = result.get("job_id") or result.get("token") or result.get("id")
            if job_id is not None:
                result["job_id"] = str(job_id)
        return result

    async def poll_backtest(self, job_id: str) -> dict:
        """Poll the status / result of a previously submitted backtest job.

        Returns the full backtest result when finished, or a status dict such
        as ``{"status": "running"}`` while still in progress.
        """
        return await self._get(f"/api/v1/backtest/{job_id}")

    async def get_balance(self) -> dict:
        return await self._get("/api/v1/balance")

    async def get_performance(self) -> dict:
        return await self._get("/api/v1/performance")


freqtrade_client = FreqtradeClient()

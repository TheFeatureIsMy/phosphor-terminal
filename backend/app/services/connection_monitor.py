"""Freqtrade connection health monitoring."""
import uuid
import logging
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.reconciliation import FreqtradeConnectionState
from app.domain.execution import FreqtradeRun

logger = logging.getLogger(__name__)


class ConnectionMonitor:
    """Monitors Freqtrade REST/WS/Docker health and tracks connection state."""

    DEGRADATION_THRESHOLD = 3  # consecutive failures before degradation

    def __init__(self, session: Session):
        self._s = session

    # ------------------------------------------------------------------
    # helpers
    # ------------------------------------------------------------------

    def _now(self) -> datetime:
        return datetime.now(timezone.utc)

    # ------------------------------------------------------------------
    # public API
    # ------------------------------------------------------------------

    async def check_health(self, freqtrade_run_id: uuid.UUID) -> dict:
        """Check REST, WebSocket, and Docker health for a Freqtrade run."""
        ft_run = self._s.get(FreqtradeRun, freqtrade_run_id)
        if not ft_run:
            return {"error": "FreqtradeRun not found", "freqtrade_run_id": str(freqtrade_run_id)}

        rest_ok = await self._check_rest(ft_run)
        ws_ok = await self._check_websocket(ft_run)
        docker_ok = self._check_docker(ft_run)

        return {
            "freqtrade_run_id": str(freqtrade_run_id),
            "rest": "ok" if rest_ok else "failed",
            "websocket": "ok" if ws_ok else "failed",
            "docker": "ok" if docker_ok else "failed",
            "overall": "healthy" if all([rest_ok, ws_ok, docker_ok]) else "degraded",
        }

    def update_state(self, freqtrade_run_id: uuid.UUID, health: dict) -> FreqtradeConnectionState:
        """Create or update connection state record based on health check results."""
        # Find existing state record for this run
        stmt = (
            select(FreqtradeConnectionState)
            .where(FreqtradeConnectionState.freqtrade_run_id == freqtrade_run_id)
            .order_by(FreqtradeConnectionState.last_checked_at.desc())
            .limit(1)
        )
        state = self._s.scalar(stmt)

        new_state_value = self._determine_state(health)
        now = self._now()

        if not state:
            state = FreqtradeConnectionState(
                freqtrade_run_id=freqtrade_run_id,
                state=new_state_value,
                rest_status=health.get("rest"),
                websocket_status=health.get("websocket"),
                docker_status=health.get("docker"),
                last_checked_at=now,
            )
            self._s.add(state)
        else:
            state.state = new_state_value
            state.rest_status = health.get("rest")
            state.websocket_status = health.get("websocket")
            state.docker_status = health.get("docker")
            state.last_checked_at = now

        # If degraded or worse, update FreqtradeRun status accordingly
        if new_state_value in ("connection_lost", "failed"):
            ft_run = self._s.get(FreqtradeRun, freqtrade_run_id)
            if ft_run and ft_run.status == "running":
                ft_run.status = "degraded"

        self._s.flush()
        return state

    def get_latest_state(self, freqtrade_run_id: uuid.UUID) -> FreqtradeConnectionState | None:
        """Get the most recent connection state."""
        stmt = (
            select(FreqtradeConnectionState)
            .where(FreqtradeConnectionState.freqtrade_run_id == freqtrade_run_id)
            .order_by(FreqtradeConnectionState.last_checked_at.desc())
            .limit(1)
        )
        return self._s.scalar(stmt)

    # ------------------------------------------------------------------
    # state determination
    # ------------------------------------------------------------------

    def _determine_state(self, health: dict) -> str:
        """Map health check results to a ConnectionState value."""
        rest = health.get("rest") == "ok"
        ws = health.get("websocket") == "ok"
        docker = health.get("docker") == "ok"

        if rest and ws and docker:
            return "healthy"
        if not docker:
            return "failed"
        if not rest and not ws:
            return "connection_lost"
        if rest and not ws:
            return "pulse_degraded"
        if not rest:
            return "freqtrade_native_guard_only"
        return "pulse_degraded"

    # ------------------------------------------------------------------
    # individual health checks
    # ------------------------------------------------------------------

    async def _check_rest(self, ft_run: FreqtradeRun) -> bool:
        """Try to call Freqtrade REST /api/v1/ping."""
        try:
            from app.services.freqtrade_client import FreqtradeClient

            api_url = ft_run.api_base_url
            if not api_url:
                return False
            client = FreqtradeClient(api_url)
            return await client.ping()
        except Exception as exc:
            logger.debug("REST health check failed for run %s: %s", ft_run.id, exc)
            return False

    async def _check_websocket(self, ft_run: FreqtradeRun) -> bool:
        """WebSocket health check - basic connectivity verification."""
        ws_url = ft_run.websocket_url
        if not ws_url:
            # No WebSocket configured is not a failure
            return True
        try:
            import aiohttp

            timeout = aiohttp.ClientTimeout(total=3)
            async with aiohttp.ClientSession(timeout=timeout) as session:
                async with session.ws_connect(ws_url) as ws:
                    await ws.close()
                    return True
        except Exception as exc:
            logger.debug("WebSocket health check failed for run %s: %s", ft_run.id, exc)
            return False

    def _check_docker(self, ft_run: FreqtradeRun) -> bool:
        """Docker container health check via container_id."""
        container_id = ft_run.container_id
        if not container_id:
            # Not Docker-managed = not a failure
            return True
        try:
            import subprocess

            result = subprocess.run(
                ["docker", "inspect", "--format", "{{.State.Running}}", container_id],
                capture_output=True,
                text=True,
                timeout=5,
            )
            return result.returncode == 0 and result.stdout.strip() == "true"
        except Exception as exc:
            logger.debug("Docker health check failed for run %s: %s", ft_run.id, exc)
            return False

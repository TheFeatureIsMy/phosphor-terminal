"""Command handlers — base class and registry."""
from abc import ABC, abstractmethod
from typing import Any

from sqlalchemy.orm import Session

from app.domain.command import CommandBusCommand


class CommandHandler(ABC):
    @abstractmethod
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        """Execute the command. Return result dict. Raise on failure."""
        ...


class NoOpHandler(CommandHandler):
    """Placeholder handler for testing. Does nothing."""
    def execute(self, command: CommandBusCommand, session: Session) -> dict[str, Any]:
        return {"status": "noop", "command_type": command.command_type}


_registry: dict[str, type[CommandHandler]] = {}
_initialized = False


def register_handler(command_type: str, handler_cls: type[CommandHandler]) -> None:
    _registry[command_type] = handler_cls


def _ensure_registered() -> None:
    global _initialized
    if _initialized:
        return
    _initialized = True
    from app.workers.backtest_handler import StartBacktestHandler
    from app.workers.dryrun_handler import StartDryRunHandler, StopDryRunHandler
    from app.workers.deploy_rules_handler import DeployRulesHandler
    from app.workers.pause_handler import PauseStrategyHandler
    from app.workers.live_small_handler import RequestLiveSmallHandler
    from app.workers.emergency_stop_handler import EmergencyStopHandler
    from app.workers.reconciliation_handler import StartReconciliationHandler
    register_handler("start_backtest", StartBacktestHandler)
    register_handler("start_dryrun", StartDryRunHandler)
    register_handler("stop_dryrun", StopDryRunHandler)
    register_handler("deploy_rules", DeployRulesHandler)
    register_handler("pause_strategy", PauseStrategyHandler)
    register_handler("request_live_small", RequestLiveSmallHandler)
    register_handler("emergency_stop", EmergencyStopHandler)
    register_handler("start_reconciliation", StartReconciliationHandler)


def get_handler(command_type: str) -> CommandHandler | None:
    _ensure_registered()
    cls = _registry.get(command_type)
    return cls() if cls else None

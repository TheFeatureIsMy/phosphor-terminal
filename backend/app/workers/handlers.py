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
_builtins: dict[str, type[CommandHandler]] | None = None


def register_handler(command_type: str, handler_cls: type[CommandHandler]) -> None:
    _registry[command_type] = handler_cls


def _load_builtins() -> dict[str, type[CommandHandler]]:
    global _builtins
    if _builtins is None:
        from app.workers.backtest_handler import StartBacktestHandler
        from app.workers.dryrun_handler import StartDryRunHandler, StopDryRunHandler
        from app.workers.deploy_rules_handler import DeployRulesHandler
        from app.workers.pause_handler import PauseStrategyHandler
        from app.workers.resume_handler import ResumeStrategyHandler
        from app.workers.live_small_handler import RequestLiveSmallHandler
        from app.workers.emergency_stop_handler import EmergencyStopHandler
        from app.workers.reconciliation_handler import StartReconciliationHandler
        from app.workers.agent_task_handler import RunAgentTaskHandler

        _builtins = {
            "start_backtest": StartBacktestHandler,
            "start_dryrun": StartDryRunHandler,
            "stop_dryrun": StopDryRunHandler,
            "deploy_rules": DeployRulesHandler,
            "pause_strategy": PauseStrategyHandler,
            "resume_strategy": ResumeStrategyHandler,
            "request_live_small": RequestLiveSmallHandler,
            "emergency_stop": EmergencyStopHandler,
            "start_reconciliation": StartReconciliationHandler,
            "run_agent_task": RunAgentTaskHandler,
        }
    return _builtins


def _ensure_registered() -> None:
    """Re-add missing built-ins without clobbering test/custom overrides."""
    for command_type, handler_cls in _load_builtins().items():
        _registry.setdefault(command_type, handler_cls)


def get_handler(command_type: str) -> CommandHandler | None:
    _ensure_registered()
    cls = _registry.get(command_type)
    return cls() if cls else None

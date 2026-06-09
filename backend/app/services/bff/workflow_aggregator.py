"""Workflow BFF Aggregator — Daily Trading Loop §4"""
from __future__ import annotations

import logging
from datetime import date, datetime, timezone

from app.config import settings
from app.domain.enums import WorkflowStepName, WorkflowStepStatus, WorkflowGlobalState
from app.services.runtime_redis_store import RuntimeRedisStore
from app.services.account_risk_firewall import AccountRiskFirewall
from app.services.freqtrade_client import FreqtradeClient

logger = logging.getLogger(__name__)

STEP_DEFINITIONS = [
    {
        "step": WorkflowStepName.MISSION_CONTROL,
        "title": "今日状态",
        "question": "今天能不能交易？",
        "jump_target": "liveReadiness",
    },
    {
        "step": WorkflowStepName.OPPORTUNITY,
        "title": "信号机会",
        "question": "有哪些机会？",
        "jump_target": "signalCenter",
    },
    {
        "step": WorkflowStepName.STRATEGY,
        "title": "策略草稿",
        "question": "机会能不能变成策略？",
        "jump_target": "strategyWorkspace",
    },
    {
        "step": WorkflowStepName.MTF_DEFENSE,
        "title": "MTF防御",
        "question": "多周期结构是否安全？",
        "jump_target": "structureMatrix",
    },
    {
        "step": WorkflowStepName.VALIDATION,
        "title": "回测验证",
        "question": "历史和模拟是否有效？",
        "jump_target": "backtestSimulation",
    },
    {
        "step": WorkflowStepName.RISK_GATE,
        "title": "风控准入",
        "question": "能不能实盘？",
        "jump_target": "riskCenter",
    },
    {
        "step": WorkflowStepName.EXECUTION,
        "title": "执行监控",
        "question": "执行是否正常？",
        "jump_target": "executionCenter",
    },
    {
        "step": WorkflowStepName.REVIEW,
        "title": "交易复盘",
        "question": "为什么赚亏？",
        "jump_target": "growthReview",
    },
    {
        "step": WorkflowStepName.EVOLUTION,
        "title": "策略进化",
        "question": "是否生成影子策略并升级？",
        "jump_target": "strategyOptimization",
    },
]


class WorkflowAggregator:
    def __init__(self):
        self._store = RuntimeRedisStore(redis_url=settings.redis_url)
        self._ft = FreqtradeClient(base_url=settings.freqtrade_url)
        self._firewall = AccountRiskFirewall(
            policy=__import__("app.domain.dsl", fromlist=["AccountRiskPolicy"]).AccountRiskPolicy(),
            redis_store=self._store,
        )

    async def get_daily_workflow(self, target_date: date | None = None) -> dict:
        if target_date is None:
            target_date = date.today()

        cache_key = f"pulsedesk:workflow:daily:{target_date.isoformat()}"
        cached = await self._store._get(cache_key)
        if cached:
            return cached

        steps = []
        for defn in STEP_DEFINITIONS:
            step_data = await self._evaluate_step(defn)
            steps.append(step_data)

        current_step = self._determine_current_step(steps)
        global_state = self._determine_global_state(steps)

        result = {
            "workflow_id": f"daily_{target_date.isoformat()}",
            "date": target_date.isoformat(),
            "global_state": global_state,
            "current_step": current_step,
            "steps": steps,
        }

        await self._store._set(cache_key, result, ttl=30)
        return result

    async def _evaluate_step(self, defn: dict) -> dict:
        step_name = defn["step"]
        try:
            if step_name == WorkflowStepName.MISSION_CONTROL:
                return await self._eval_mission_control(defn)
            elif step_name == WorkflowStepName.OPPORTUNITY:
                return await self._eval_opportunity(defn)
            elif step_name == WorkflowStepName.STRATEGY:
                return await self._eval_strategy(defn)
            elif step_name == WorkflowStepName.RISK_GATE:
                return await self._eval_risk_gate(defn)
            elif step_name == WorkflowStepName.EXECUTION:
                return await self._eval_execution(defn)
            else:
                return self._default_step(defn, WorkflowStepStatus.NOT_STARTED)
        except Exception as e:
            logger.warning("workflow step %s evaluation failed: %s", step_name.value, e)
            return self._default_step(defn, WorkflowStepStatus.NOT_STARTED)

    async def _eval_mission_control(self, defn: dict) -> dict:
        risk_state = await self._firewall.check("default")
        redis_ok = await self._store.ping()
        ft_state = "unknown"
        try:
            version = await self._ft.version()
            ft_state = "healthy" if version else "unavailable"
        except Exception:
            ft_state = "unavailable"

        blocking = []
        if not redis_ok:
            blocking.append("redis_unavailable")
        if ft_state != "healthy":
            blocking.append("freqtrade_unavailable")
        if not risk_state.allowed:
            blocking.append(risk_state.reason_code)

        if blocking:
            status = WorkflowStepStatus.BLOCKED
            summary = f"系统异常：{', '.join(blocking)}"
        else:
            status = WorkflowStepStatus.PASSED
            summary = "系统健康，允许 paper / dry-run"

        return {
            "step": defn["step"].value,
            "status": status.value,
            "title": defn["title"],
            "question": defn["question"],
            "summary": summary,
            "count": None,
            "blocking_reasons": blocking,
            "available_actions": [
                {"type": "open_live_readiness", "enabled": True, "label": "查看详情"},
                {"type": "run_system_check", "enabled": True, "label": "重新检查"},
            ],
            "jump_target": defn["jump_target"],
        }

    async def _eval_opportunity(self, defn: dict) -> dict:
        cached = await self._store._get("pulsedesk:workflow:signal_count")
        active_count = cached.get("count", 0) if cached else 0

        if active_count > 0:
            status = WorkflowStepStatus.ATTENTION
            summary = f"发现 {active_count} 个 active signals"
        else:
            status = WorkflowStepStatus.READY
            summary = "暂无新信号"

        return {
            "step": defn["step"].value,
            "status": status.value,
            "title": defn["title"],
            "question": defn["question"],
            "summary": summary,
            "count": active_count,
            "blocking_reasons": [],
            "available_actions": [
                {"type": "open_signal_center", "enabled": True, "label": "查看信号"},
                {"type": "run_ai_research", "enabled": True, "label": "AI 投研"},
            ],
            "jump_target": defn["jump_target"],
        }

    async def _eval_strategy(self, defn: dict) -> dict:
        return {
            "step": defn["step"].value,
            "status": WorkflowStepStatus.READY.value,
            "title": defn["title"],
            "question": defn["question"],
            "summary": "策略管理就绪",
            "count": None,
            "blocking_reasons": [],
            "available_actions": [
                {"type": "open_strategy_workspace", "enabled": True, "label": "策略工作台"},
                {"type": "create_strategy_draft", "enabled": True, "label": "新建策略"},
            ],
            "jump_target": defn["jump_target"],
        }

    async def _eval_risk_gate(self, defn: dict) -> dict:
        risk_state = await self._firewall.check("default")
        blocking = []
        if not risk_state.allowed:
            blocking.append(risk_state.reason_code)

        if blocking:
            status = WorkflowStepStatus.BLOCKED
            summary = f"风控拦截：{risk_state.reason_code}"
        else:
            status = WorkflowStepStatus.PASSED
            summary = "风控允许交易"

        return {
            "step": defn["step"].value,
            "status": status.value,
            "title": defn["title"],
            "question": defn["question"],
            "summary": summary,
            "count": None,
            "blocking_reasons": blocking,
            "available_actions": [
                {"type": "open_risk_center", "enabled": True, "label": "风控中心"},
            ],
            "jump_target": defn["jump_target"],
        }

    async def _eval_execution(self, defn: dict) -> dict:
        ft_state = "unknown"
        try:
            version = await self._ft.version()
            ft_state = "healthy" if version else "unavailable"
        except Exception:
            ft_state = "unavailable"

        if ft_state == "healthy":
            status = WorkflowStepStatus.RUNNING
            summary = "Freqtrade 运行中"
        else:
            status = WorkflowStepStatus.NOT_STARTED
            summary = "Freqtrade 未连接"

        return {
            "step": defn["step"].value,
            "status": status.value,
            "title": defn["title"],
            "question": defn["question"],
            "summary": summary,
            "count": None,
            "blocking_reasons": [] if ft_state == "healthy" else ["freqtrade_unavailable"],
            "available_actions": [
                {"type": "open_execution_center", "enabled": True, "label": "执行中心"},
            ],
            "jump_target": defn["jump_target"],
        }

    def _default_step(self, defn: dict, status: WorkflowStepStatus) -> dict:
        return {
            "step": defn["step"].value,
            "status": status.value,
            "title": defn["title"],
            "question": defn["question"],
            "summary": "",
            "count": None,
            "blocking_reasons": [],
            "available_actions": [
                {"type": f"open_{defn['jump_target']}", "enabled": True, "label": "查看"},
            ],
            "jump_target": defn["jump_target"],
        }

    def _determine_current_step(self, steps: list[dict]) -> str:
        for step in steps:
            if step["status"] in (
                WorkflowStepStatus.BLOCKED.value,
                WorkflowStepStatus.ATTENTION.value,
                WorkflowStepStatus.NOT_STARTED.value,
            ):
                return step["step"]
        return steps[-1]["step"]

    def _determine_global_state(self, steps: list[dict]) -> str:
        statuses = [s["status"] for s in steps]
        if WorkflowStepStatus.BLOCKED.value in statuses:
            return WorkflowGlobalState.BLOCKED.value
        if WorkflowStepStatus.ATTENTION.value in statuses:
            return WorkflowGlobalState.ATTENTION.value
        if all(s in (WorkflowStepStatus.PASSED.value, WorkflowStepStatus.RUNNING.value) for s in statuses):
            return WorkflowGlobalState.COMPLETED.value
        return WorkflowGlobalState.READY.value

"""Workflow BFF — Daily Trading Loop §3"""
import logging
from datetime import date

from fastapi import APIRouter

from app.services.bff.workflow_aggregator import WorkflowAggregator

router = APIRouter(prefix="/api/workflow", tags=["workflow-bff"])
logger = logging.getLogger(__name__)

_aggregator = WorkflowAggregator()


@router.get("/daily")
async def get_daily_workflow():
    return await _aggregator.get_daily_workflow()


@router.get("/daily/{target_date}")
async def get_daily_workflow_by_date(target_date: date):
    return await _aggregator.get_daily_workflow(target_date)


@router.post("/daily/refresh")
async def refresh_daily_workflow():
    return await _aggregator.get_daily_workflow()


@router.post("/steps/{step}/action")
async def execute_step_action(step: str, body: dict):
    action_type = body.get("type", "")
    logger.info("workflow step action: step=%s action=%s", step, action_type)
    return {
        "step": step,
        "action": action_type,
        "result": "acknowledged",
        "message": f"Action {action_type} on step {step} acknowledged",
    }

"""v2 Emergency Stop / Resume API — single real endpoint for emergency control."""
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.emergency import EmergencyStopRequest, EmergencyStopResponse, EmergencyResumeRequest

router = APIRouter(prefix="/api/v2/emergency", tags=["emergency-v2"])


@router.post("/stop", response_model=EmergencyStopResponse)
def emergency_stop(body: EmergencyStopRequest, db: Session = Depends(get_db)):
    """Trigger emergency stop for one or all active strategy runs."""
    from app.services.emergency_stop_service import EmergencyStopService

    svc = EmergencyStopService(db)
    result = svc.stop(strategy_run_id=body.strategy_run_id, reason=body.reason)
    db.commit()
    return EmergencyStopResponse(
        stopped_runs=result["stopped_runs"],
        ledger_event_ids=result.get("ledger_event_ids", []),
        message=f"Stopped {result['stopped_count']} run(s). Reason: {result['reason']}",
    )


@router.post("/resume")
def emergency_resume(body: EmergencyResumeRequest, db: Session = Depends(get_db)):
    """Resume from emergency stop."""
    from app.services.emergency_stop_service import EmergencyStopService

    svc = EmergencyStopService(db)
    try:
        result = svc.resume(body.strategy_run_id, reason=body.reason)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    db.commit()
    return result

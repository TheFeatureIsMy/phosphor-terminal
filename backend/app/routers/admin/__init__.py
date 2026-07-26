"""Admin API — data vacuum and maintenance operations."""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db

router = APIRouter(prefix="/api/admin", tags=["admin"])


@router.post("/data-vacuum/run", status_code=202)
def run_data_vacuum(db: Session = Depends(get_db)):
    """Trigger a data vacuum job (archive old signals, clean expired data)."""
    from app.domain.archive import SignalArchivalJob
    job = SignalArchivalJob(
        status="pending",
        criteria={"max_age_days": 30, "min_score": 2.0, "exclude_referenced": True},
    )
    db.add(job)
    db.commit()
    return {"job_id": str(job.id), "status": "pending", "message": "Data vacuum job queued"}


@router.get("/data-vacuum/jobs")
def list_vacuum_jobs(
    limit: int = Query(default=20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    """List data vacuum jobs."""
    from app.domain.archive import SignalArchivalJob
    from sqlalchemy import desc
    jobs = db.query(SignalArchivalJob).order_by(
        desc(SignalArchivalJob.created_at)
    ).limit(limit).all()
    return [
        {
            "id": str(j.id),
            "status": j.status,
            "signals_scanned": j.signals_scanned,
            "signals_archived": j.signals_archived,
            "started_at": str(j.started_at) if j.started_at else None,
            "completed_at": str(j.completed_at) if j.completed_at else None,
            "created_at": str(j.created_at),
        }
        for j in jobs
    ]

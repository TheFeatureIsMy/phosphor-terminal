"""Inference Queue API — submit, query, and cancel inference jobs."""
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas.inference import InferenceJobCreate, InferenceJobView, RuntimeStateView
from app.services.inference_queue import InferenceQueueService

router = APIRouter(prefix="/api/inference", tags=["inference"])


@router.post("/jobs", status_code=201, response_model=InferenceJobView)
def create_job(body: InferenceJobCreate, db: Session = Depends(get_db)):
    svc = InferenceQueueService(db)
    job = svc.submit_job(
        job_type=body.job_type,
        model_name=body.model_name,
        input_payload=body.input_payload,
        provider_id=body.provider_id,
        timeout_sec=body.timeout_sec,
    )
    db.commit()
    return job


@router.get("/jobs", response_model=list[InferenceJobView])
def list_jobs(
    status: str | None = None,
    model_name: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    db: Session = Depends(get_db),
):
    svc = InferenceQueueService(db)
    return svc.list_jobs(status=status, model_name=model_name, limit=limit, offset=offset)


@router.get("/jobs/{job_id}", response_model=InferenceJobView)
def get_job(job_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = InferenceQueueService(db)
    job = svc.get_job(job_id)
    if not job:
        raise HTTPException(status_code=404, detail="Inference job not found")
    return job


@router.post("/jobs/{job_id}/cancel", response_model=InferenceJobView)
def cancel_job(job_id: uuid.UUID, db: Session = Depends(get_db)):
    svc = InferenceQueueService(db)
    try:
        job = svc.cancel_job(job_id)
    except ValueError as e:
        raise HTTPException(status_code=409, detail=str(e))
    db.commit()
    return job


@router.get("/runtime-state", response_model=list[RuntimeStateView])
def get_runtime_state(db: Session = Depends(get_db)):
    svc = InferenceQueueService(db)
    return svc.get_runtime_state()

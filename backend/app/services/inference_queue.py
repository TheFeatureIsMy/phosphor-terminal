"""AI inference job queue management."""
import uuid
import logging
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.domain.inference import InferenceJob, RemoteModelJob
from app.domain.mcp import ModelRuntimeState

logger = logging.getLogger(__name__)


class InferenceQueueService:
    """CRUD and lifecycle management for inference jobs."""

    def __init__(self, session: Session):
        self._s = session

    def submit_job(self, job_type: str, model_name: str, input_payload: dict,
                   provider_id: uuid.UUID | None = None, timeout_sec: int = 300) -> InferenceJob:
        """Create a new inference job in queued status."""
        job = InferenceJob(
            job_type=job_type,
            model_name=model_name,
            provider_id=provider_id,
            status="queued",
            input_payload=input_payload,
            timeout_sec=timeout_sec,
        )
        self._s.add(job)
        self._s.flush()
        logger.info("Inference job %s submitted: %s/%s", job.id, job_type, model_name)
        return job

    def list_jobs(self, status: str | None = None, model_name: str | None = None,
                  limit: int = 50, offset: int = 0) -> list[InferenceJob]:
        """List jobs with optional filtering."""
        q = self._s.query(InferenceJob)
        if status:
            q = q.filter(InferenceJob.status == status)
        if model_name:
            q = q.filter(InferenceJob.model_name == model_name)
        return q.order_by(desc(InferenceJob.submitted_at)).offset(offset).limit(limit).all()

    def get_job(self, job_id: uuid.UUID) -> InferenceJob | None:
        """Get a single job by ID."""
        return self._s.get(InferenceJob, job_id)

    def cancel_job(self, job_id: uuid.UUID) -> InferenceJob:
        """Cancel a queued or running job."""
        job = self._s.get(InferenceJob, job_id)
        if not job:
            raise ValueError(f"InferenceJob {job_id} not found")
        if job.status not in ("queued", "running"):
            raise ValueError(f"Cannot cancel job in status '{job.status}'")
        job.status = "cancelled"
        job.completed_at = datetime.now(timezone.utc)
        self._s.flush()
        logger.info("Inference job %s cancelled", job_id)
        return job

    def start_job(self, job_id: uuid.UUID) -> InferenceJob:
        """Mark job as running."""
        job = self._s.get(InferenceJob, job_id)
        if not job:
            raise ValueError(f"InferenceJob {job_id} not found")
        job.status = "running"
        job.started_at = datetime.now(timezone.utc)
        self._s.flush()
        return job

    def complete_job(self, job_id: uuid.UUID, output_payload: dict,
                     actual_cost_usd: float | None = None) -> InferenceJob:
        """Mark job as completed with results."""
        job = self._s.get(InferenceJob, job_id)
        if not job:
            raise ValueError(f"InferenceJob {job_id} not found")
        job.status = "completed"
        job.output_payload = output_payload
        job.actual_cost_usd = actual_cost_usd
        job.completed_at = datetime.now(timezone.utc)
        self._s.flush()
        return job

    def fail_job(self, job_id: uuid.UUID, error_message: str) -> InferenceJob:
        """Mark job as failed."""
        job = self._s.get(InferenceJob, job_id)
        if not job:
            raise ValueError(f"InferenceJob {job_id} not found")
        job.status = "failed"
        job.error_message = error_message
        job.completed_at = datetime.now(timezone.utc)
        self._s.flush()
        return job

    def get_runtime_state(self) -> list[ModelRuntimeState]:
        """Get all model runtime states."""
        return self._s.query(ModelRuntimeState).all()

    def update_runtime_state(self, model_name: str, provider: str, state: str,
                             gpu_memory_mb: int | None = None) -> ModelRuntimeState:
        """Update or create model runtime state."""
        existing = self._s.query(ModelRuntimeState).filter(
            ModelRuntimeState.model_name == model_name,
        ).first()
        now = datetime.now(timezone.utc)
        if existing:
            existing.state = state
            existing.provider = provider
            existing.gpu_memory_mb = gpu_memory_mb
            existing.last_heartbeat_at = now
            self._s.flush()
            return existing
        runtime = ModelRuntimeState(
            model_name=model_name,
            provider=provider,
            state=state,
            gpu_memory_mb=gpu_memory_mb,
            last_heartbeat_at=now,
        )
        self._s.add(runtime)
        self._s.flush()
        return runtime

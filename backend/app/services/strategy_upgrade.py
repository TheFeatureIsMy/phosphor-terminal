"""Strategy Upgrade Service — request, approve, reject shadow-to-version
upgrades.

Follows the StrategyVersionUpgradeRequest lifecycle:
    pending → approved  (creates new StrategyVersion)
    pending → rejected

References strategy_transition.py for version creation patterns and
strategy_repository.py for DB operations.
"""
from __future__ import annotations

import logging
import uuid
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.enums import (
    ShadowStrategyStatus,
    UpgradeApprovalStatus,
)
from app.domain.shadow_strategy import (
    ShadowStrategyDraft,
    StrategyVersionUpgradeRequest,
)
from app.domain.strategy import StrategyVersion
from app.repositories.strategy_repository import StrategyRepository
from app.services.dsl_hasher import compute_dsl_hash
from app.services.dsl_patch import DSLPatchService

logger = logging.getLogger(__name__)

_patch_svc = DSLPatchService()


class StrategyUpgradeService:
    """Manages the upgrade lifecycle: request → approve/reject."""

    def request_upgrade(
        self,
        db_session: Session,
        draft_id: uuid.UUID,
    ) -> StrategyVersionUpgradeRequest:
        """Create an upgrade request from a validated/backtested draft.

        1. Load draft, verify status
        2. Create StrategyVersionUpgradeRequest
        3. Update draft status to human_review
        """
        draft = db_session.get(ShadowStrategyDraft, draft_id)
        if draft is None:
            raise ValueError(f"ShadowStrategyDraft {draft_id} not found")

        allowed = {
            ShadowStrategyStatus.VALIDATED.value,
            ShadowStrategyStatus.BACKTESTED.value,
            ShadowStrategyStatus.DRYRUN_PASSED.value,
        }
        if draft.status not in allowed:
            raise ValueError(
                f"Draft {draft_id} status is '{draft.status}', "
                f"expected one of {sorted(allowed)} to request upgrade"
            )

        # Check for existing pending request for this draft
        existing = db_session.scalar(
            select(StrategyVersionUpgradeRequest).where(
                StrategyVersionUpgradeRequest.shadow_strategy_draft_id == draft_id,
                StrategyVersionUpgradeRequest.approval_status == UpgradeApprovalStatus.PENDING.value,
            )
        )
        if existing:
            raise ValueError(
                f"A pending upgrade request already exists for draft {draft_id}: {existing.id}"
            )

        # Build diff summary from patch ops
        patch_ops = draft.dsl_patch or []
        diff_lines = []
        for op in patch_ops:
            desc = op.get("description", "")
            path = op.get("path", "")
            diff_lines.append(f"[{op.get('op', '?')}] {path}: {desc}")
        diff_summary = "\n".join(diff_lines) if diff_lines else "DSL patch applied"

        # Validation report from draft
        validation_report = draft.validation_state or {}

        request = StrategyVersionUpgradeRequest(
            strategy_id=draft.target_strategy_id,
            from_version_id=draft.target_strategy_version_id,
            shadow_strategy_draft_id=draft_id,
            proposed_version_name=f"v-shadow-{str(draft_id)[:8]}",
            diff_summary=diff_summary,
            validation_report=validation_report,
            approval_status=UpgradeApprovalStatus.PENDING.value,
        )
        db_session.add(request)

        draft.status = ShadowStrategyStatus.HUMAN_REVIEW.value
        db_session.flush()

        logger.info(
            "Created upgrade request %s for draft %s (strategy=%s)",
            request.id, draft_id, draft.target_strategy_id,
        )
        return request

    def approve(
        self,
        db_session: Session,
        request_id: uuid.UUID,
        approved_by: str,
    ) -> StrategyVersion:
        """Approve an upgrade request — creates a new StrategyVersion.

        1. Load request, verify pending
        2. Load draft, apply patch to target DSL
        3. Create new StrategyVersion (increment version_no)
        4. Update request status → approved
        5. Update draft status → merged
        """
        request = db_session.get(StrategyVersionUpgradeRequest, request_id)
        if request is None:
            raise ValueError(f"UpgradeRequest {request_id} not found")

        if request.approval_status != UpgradeApprovalStatus.PENDING.value:
            raise ValueError(
                f"Request {request_id} is '{request.approval_status}', expected 'pending'"
            )

        # Load draft
        draft = db_session.get(ShadowStrategyDraft, request.shadow_strategy_draft_id)
        if draft is None:
            raise ValueError(
                f"ShadowStrategyDraft {request.shadow_strategy_draft_id} not found"
            )

        # Load target version DSL
        target_version = db_session.get(StrategyVersion, request.from_version_id)
        if target_version is None:
            raise ValueError(
                f"Source StrategyVersion {request.from_version_id} not found"
            )

        # Apply patch
        target_dsl = target_version.rule_dsl or {}
        patch_ops = draft.dsl_patch or []
        patched_dsl = _patch_svc.apply_patch(target_dsl, patch_ops)
        patched_dsl.pop("dsl_hash", None)
        patched_dsl["dsl_hash"] = compute_dsl_hash(patched_dsl)

        # Create new version — use StrategyRepository for version_no
        repo = StrategyRepository(db_session)
        next_no = repo.next_version_no(request.strategy_id)

        new_version = StrategyVersion(
            strategy_id=request.strategy_id,
            version_no=next_no,
            status="draft",
            dsl_version=patched_dsl.get("schema_version", target_version.dsl_version),
            rule_dsl=patched_dsl,
            dsl_hash=patched_dsl["dsl_hash"],
            created_by=f"shadow_upgrade:{approved_by}",
        )
        db_session.add(new_version)
        db_session.flush()

        # Update request
        now = datetime.now(timezone.utc)
        request.approval_status = UpgradeApprovalStatus.APPROVED.value
        request.approved_by = approved_by
        request.approved_at = now

        # Update draft
        draft.status = ShadowStrategyStatus.MERGED.value

        db_session.flush()

        logger.info(
            "Approved upgrade request %s — created StrategyVersion %s (v%d) for strategy %s",
            request_id, new_version.id, next_no, request.strategy_id,
        )
        return new_version

    def reject(
        self,
        db_session: Session,
        request_id: uuid.UUID,
        reason: str,
    ) -> StrategyVersionUpgradeRequest:
        """Reject an upgrade request.

        Updates request.approval_status → rejected and draft.status → rejected.
        """
        request = db_session.get(StrategyVersionUpgradeRequest, request_id)
        if request is None:
            raise ValueError(f"UpgradeRequest {request_id} not found")

        if request.approval_status != UpgradeApprovalStatus.PENDING.value:
            raise ValueError(
                f"Request {request_id} is '{request.approval_status}', expected 'pending'"
            )

        request.approval_status = UpgradeApprovalStatus.REJECTED.value
        request.approved_at = datetime.now(timezone.utc)

        # Store rejection reason in validation_report
        report = request.validation_report or {}
        report["rejection_reason"] = reason
        request.validation_report = report

        # Update draft status
        if request.shadow_strategy_draft_id:
            draft = db_session.get(ShadowStrategyDraft, request.shadow_strategy_draft_id)
            if draft:
                draft.status = ShadowStrategyStatus.REJECTED.value

        db_session.flush()

        logger.info(
            "Rejected upgrade request %s — reason: %s",
            request_id, reason,
        )
        return request

    def list_requests(
        self,
        db_session: Session,
        strategy_id: uuid.UUID,
        status: str | None = None,
        offset: int = 0,
        limit: int = 50,
    ) -> list[StrategyVersionUpgradeRequest]:
        """List upgrade requests for a strategy."""
        stmt = select(StrategyVersionUpgradeRequest).where(
            StrategyVersionUpgradeRequest.strategy_id == strategy_id,
        )
        if status:
            stmt = stmt.where(StrategyVersionUpgradeRequest.approval_status == status)
        stmt = stmt.order_by(StrategyVersionUpgradeRequest.created_at.desc()).offset(offset).limit(limit)
        return list(db_session.scalars(stmt).all())

    def get_request(
        self,
        db_session: Session,
        request_id: uuid.UUID,
    ) -> StrategyVersionUpgradeRequest | None:
        return db_session.get(StrategyVersionUpgradeRequest, request_id)

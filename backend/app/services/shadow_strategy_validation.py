"""Shadow Strategy Validation Service — DSL validation + incremental backtest
for ShadowStrategyDraft instances.
"""
from __future__ import annotations

import logging
import uuid
from dataclasses import asdict
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.domain.enums import ShadowStrategyStatus, CommandType
from app.domain.shadow_strategy import ShadowStrategyDraft
from app.domain.strategy import StrategyVersion
from app.services.command_bus import CommandBusService
from app.services.dsl_hasher import compute_dsl_hash
from app.services.dsl_patch import DSLPatchService
from app.services.dsl_validator import DSLValidator

logger = logging.getLogger(__name__)

_patch_svc = DSLPatchService()
_dsl_validator = DSLValidator()


class ShadowStrategyValidationService:
    """Validates shadow strategy drafts — static DSL checks + backtest."""

    def validate(
        self,
        db_session: Session,
        draft_id: uuid.UUID,
    ) -> dict:
        """Run static DSL validation on the patched DSL.

        1. Load draft + target version DSL
        2. Apply patch
        3. Recompute dsl_hash
        4. Run DSLValidator
        5. Update draft.validation_state and draft.status
        6. Return validation report
        """
        draft = db_session.get(ShadowStrategyDraft, draft_id)
        if draft is None:
            raise ValueError(f"ShadowStrategyDraft {draft_id} not found")

        target_version = db_session.get(StrategyVersion, draft.target_strategy_version_id)
        if target_version is None:
            raise ValueError(
                f"Target StrategyVersion {draft.target_strategy_version_id} not found"
            )

        # Apply patch
        target_dsl = target_version.rule_dsl or {}
        patch_ops = draft.dsl_patch or []
        patched_dsl = _patch_svc.apply_patch(target_dsl, patch_ops)

        # Recompute hash
        patched_dsl.pop("dsl_hash", None)
        patched_dsl["dsl_hash"] = compute_dsl_hash(patched_dsl)

        # Validate
        report = _dsl_validator.validate(patched_dsl)

        validation_state = {
            "valid": report.valid,
            "error_count": report.error_count,
            "warning_count": report.warning_count,
            "safe_hold_required": report.safe_hold_required,
            "safe_hold_reasons": report.safe_hold_reasons,
            "errors": [
                {"code": e.code, "path": e.path, "message": e.message, "severity": e.severity}
                for e in report.errors
            ],
            "warnings": [
                {"code": w.code, "path": w.path, "message": w.message, "severity": w.severity}
                for w in report.warnings
            ],
            "patched_dsl_hash": patched_dsl.get("dsl_hash", ""),
            "validated_at": datetime.now(timezone.utc).isoformat(),
        }

        draft.validation_state = validation_state
        if report.valid:
            draft.status = ShadowStrategyStatus.VALIDATED.value
        # If invalid, keep current status but store the report

        db_session.flush()

        logger.info(
            "Validated ShadowStrategyDraft %s — valid=%s, errors=%d, warnings=%d",
            draft_id, report.valid, report.error_count, report.warning_count,
        )

        return validation_state

    def run_incremental_backtest(
        self,
        db_session: Session,
        draft_id: uuid.UUID,
    ) -> dict:
        """Enqueue an incremental backtest for the patched DSL.

        1. Load draft, verify status is validated
        2. Apply patch to target DSL
        3. Create a backtest command via CommandBus
        4. Update draft.backtest_id
        5. Return backtest command info
        """
        draft = db_session.get(ShadowStrategyDraft, draft_id)
        if draft is None:
            raise ValueError(f"ShadowStrategyDraft {draft_id} not found")

        if draft.status not in (
            ShadowStrategyStatus.GENERATED.value,
            ShadowStrategyStatus.VALIDATED.value,
        ):
            raise ValueError(
                f"Draft {draft_id} status is '{draft.status}', "
                f"expected 'generated' or 'validated' for backtest"
            )

        target_version = db_session.get(StrategyVersion, draft.target_strategy_version_id)
        if target_version is None:
            raise ValueError(
                f"Target StrategyVersion {draft.target_strategy_version_id} not found"
            )

        # Apply patch
        target_dsl = target_version.rule_dsl or {}
        patch_ops = draft.dsl_patch or []
        patched_dsl = _patch_svc.apply_patch(target_dsl, patch_ops)
        patched_dsl.pop("dsl_hash", None)
        patched_dsl["dsl_hash"] = compute_dsl_hash(patched_dsl)

        # Enqueue backtest command
        cmd_bus = CommandBusService(db_session)
        idempotency_key = f"shadow_backtest:{draft_id}"

        payload = {
            "shadow_strategy_draft_id": str(draft_id),
            "strategy_id": str(draft.target_strategy_id),
            "source_version_id": str(draft.target_strategy_version_id),
            "patched_dsl": patched_dsl,
            "symbols": patched_dsl.get("symbols", []),
            "timerange": patched_dsl.get("backtest_timerange", "20240101-"),
        }

        cmd, created = cmd_bus.enqueue(
            command_type=CommandType.START_BACKTEST.value,
            aggregate_type="shadow_strategy_draft",
            aggregate_id=draft.id,
            payload=payload,
            idempotency_key=idempotency_key,
            requested_by="shadow_strategy_validation",
        )

        draft.backtest_id = cmd.id
        db_session.flush()

        logger.info(
            "Enqueued incremental backtest for ShadowStrategyDraft %s — command=%s (created=%s)",
            draft_id, cmd.id, created,
        )

        return {
            "draft_id": str(draft_id),
            "backtest_command_id": str(cmd.id),
            "command_created": created,
            "command_status": cmd.status,
            "idempotency_key": idempotency_key,
        }

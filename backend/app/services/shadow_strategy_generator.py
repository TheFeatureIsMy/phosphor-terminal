"""Shadow Strategy Generator Service — creates ShadowStrategyDraft from
failure clusters.

Reads a FailureClusterRecord, resolves the target strategy + latest
version, generates a DSL patch via DSLPatchService, and persists the
draft to the DB.
"""
from __future__ import annotations

import logging
import uuid
from typing import Optional

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.domain.enums import ShadowStrategyStatus
from app.domain.shadow_strategy import FailureClusterRecord, ShadowStrategyDraft
from app.domain.strategy import StrategyVersion
from app.services.dsl_patch import DSLPatchService

logger = logging.getLogger(__name__)

_patch_svc = DSLPatchService()


class ShadowStrategyGeneratorService:
    """Generates shadow strategy drafts from failure cluster analysis."""

    def generate_from_cluster(
        self,
        db_session: Session,
        cluster_id: uuid.UUID,
    ) -> ShadowStrategyDraft:
        """Create a ShadowStrategyDraft from a FailureClusterRecord.

        Steps:
        1. Load FailureClusterRecord
        2. Resolve target strategy + latest version
        3. Extract common_features / failure pattern
        4. Generate DSL patch
        5. Persist ShadowStrategyDraft
        """
        # 1. Load cluster
        cluster = db_session.get(FailureClusterRecord, cluster_id)
        if cluster is None:
            raise ValueError(f"FailureClusterRecord {cluster_id} not found")

        if cluster.status != "active":
            raise ValueError(
                f"Cluster {cluster_id} is '{cluster.status}', expected 'active'"
            )

        # 2. Resolve target strategy + latest version
        strategy_id = cluster.strategy_id
        if strategy_id is None:
            raise ValueError(
                f"Cluster {cluster_id} has no strategy_id — cannot generate shadow"
            )

        latest_version = self._get_latest_version(db_session, strategy_id)
        if latest_version is None:
            raise ValueError(
                f"No StrategyVersion found for strategy {strategy_id}"
            )

        # 3. Build failure pattern dict for patch generation
        failure_pattern = {
            "label": cluster.label,
            "sample_size": cluster.sample_size,
            "total_loss": float(cluster.total_loss) if cluster.total_loss else 0,
            "avg_loss": float(cluster.avg_loss) if cluster.avg_loss else 0,
            "common_features": cluster.common_features or {},
            "representative_trade_ids": cluster.representative_trade_ids or [],
        }

        # 4. Generate DSL patch
        target_dsl = latest_version.rule_dsl or {}
        patch_ops = _patch_svc.generate_patch(failure_pattern, target_dsl)

        # 5. Create draft
        title = f"Shadow: fix '{cluster.label}' (n={cluster.sample_size})"
        summary_parts = [
            f"Auto-generated from failure cluster '{cluster.label}'.",
            f"Sample size: {cluster.sample_size}, total loss: {failure_pattern['total_loss']:.2f}.",
        ]
        suggested = (cluster.common_features or {}).get("suggested_fix", "")
        if suggested:
            summary_parts.append(f"Suggested fix: {suggested}")

        draft = ShadowStrategyDraft(
            source_type="failure_cluster",
            source_failure_cluster_id=cluster_id,
            target_strategy_id=strategy_id,
            target_strategy_version_id=latest_version.id,
            title=title,
            summary="\n".join(summary_parts),
            status=ShadowStrategyStatus.GENERATED.value,
            failure_pattern=failure_pattern,
            dsl_patch=patch_ops,
            validation_state={},
            created_by="growth_engine",
        )
        db_session.add(draft)
        db_session.flush()

        logger.info(
            "Generated ShadowStrategyDraft %s from cluster %s (strategy=%s, version=%s)",
            draft.id, cluster_id, strategy_id, latest_version.id,
        )
        return draft

    def get_draft(
        self,
        db_session: Session,
        draft_id: uuid.UUID,
    ) -> Optional[ShadowStrategyDraft]:
        return db_session.get(ShadowStrategyDraft, draft_id)

    def list_drafts(
        self,
        db_session: Session,
        strategy_id: uuid.UUID | None = None,
        status: str | None = None,
        offset: int = 0,
        limit: int = 50,
    ) -> list[ShadowStrategyDraft]:
        stmt = select(ShadowStrategyDraft)
        if strategy_id is not None:
            stmt = stmt.where(ShadowStrategyDraft.target_strategy_id == strategy_id)
        if status is not None:
            stmt = stmt.where(ShadowStrategyDraft.status == status)
        stmt = stmt.order_by(ShadowStrategyDraft.created_at.desc()).offset(offset).limit(limit)
        return list(db_session.scalars(stmt).all())

    # ── helpers ─────────────────────────────────────────────────────

    @staticmethod
    def _get_latest_version(
        db_session: Session, strategy_id: uuid.UUID,
    ) -> Optional[StrategyVersion]:
        stmt = (
            select(StrategyVersion)
            .where(StrategyVersion.strategy_id == strategy_id)
            .order_by(StrategyVersion.version_no.desc())
            .limit(1)
        )
        return db_session.scalar(stmt)

"""knowledge tenant scoping

Revision ID: 95f5eccd6db2
Revises: d0c6a2c13d8c
Create Date: 2026-11-16 01:00:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '95f5eccd6db2'
down_revision: Union[str, Sequence[str], None] = 'd0c6a2c13d8c'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("knowledge_documents", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_knowledge_documents_tenant", "knowledge_documents", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_knowledge_documents_tenant_id", "knowledge_documents", ["tenant_id"])
    op.drop_constraint(
        "knowledge_documents_content_hash_key", "knowledge_documents", type_="unique",
    )
    op.create_unique_constraint(
        "uq_knowledge_doc_tenant_hash", "knowledge_documents", ["tenant_id", "content_hash"],
    )
    op.execute(
        "UPDATE knowledge_documents SET tenant_id = (SELECT MIN(id) FROM tenants) "
        "WHERE tenant_id IS NULL"
    )

    op.add_column("knowledge_chunks", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_knowledge_chunks_tenant", "knowledge_chunks", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_knowledge_chunks_tenant_id", "knowledge_chunks", ["tenant_id"])
    op.execute(
        "UPDATE knowledge_chunks SET tenant_id = (SELECT MIN(id) FROM tenants) "
        "WHERE tenant_id IS NULL"
    )

    op.add_column("generated_strategy_artifacts", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_generated_artifacts_tenant", "generated_strategy_artifacts", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index(
        "ix_generated_strategy_artifacts_tenant_id",
        "generated_strategy_artifacts", ["tenant_id"],
    )


def downgrade() -> None:
    op.drop_index("ix_generated_strategy_artifacts_tenant_id", table_name="generated_strategy_artifacts")
    op.drop_constraint("fk_generated_artifacts_tenant", "generated_strategy_artifacts", type_="foreignkey")
    op.drop_column("generated_strategy_artifacts", "tenant_id")

    op.drop_index("ix_knowledge_chunks_tenant_id", table_name="knowledge_chunks")
    op.drop_constraint("fk_knowledge_chunks_tenant", "knowledge_chunks", type_="foreignkey")
    op.drop_column("knowledge_chunks", "tenant_id")

    op.drop_constraint("uq_knowledge_doc_tenant_hash", "knowledge_documents", type_="unique")
    op.create_unique_constraint(
        "knowledge_documents_content_hash_key", "knowledge_documents", ["content_hash"],
    )
    op.drop_index("ix_knowledge_documents_tenant_id", table_name="knowledge_documents")
    op.drop_constraint("fk_knowledge_documents_tenant", "knowledge_documents", type_="foreignkey")
    op.drop_column("knowledge_documents", "tenant_id")

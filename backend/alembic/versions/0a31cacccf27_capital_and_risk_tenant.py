"""capital and risk tenant

Revision ID: 0a31cacccf27
Revises: 95f5eccd6db2
Create Date: 2026-11-16 01:10:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '0a31cacccf27'
down_revision: Union[str, Sequence[str], None] = '95f5eccd6db2'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("capital_pools", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_capital_pools_tenant", "capital_pools", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_capital_pools_tenant_id", "capital_pools", ["tenant_id"])
    op.execute(
        "UPDATE capital_pools SET tenant_id = (SELECT MIN(id) FROM tenants) "
        "WHERE tenant_id IS NULL"
    )

    op.add_column("risk_policies", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_risk_policies_tenant", "risk_policies", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index("ix_risk_policies_tenant_id", "risk_policies", ["tenant_id"])
    op.execute(
        "UPDATE risk_policies SET tenant_id = (SELECT MIN(id) FROM tenants) "
        "WHERE tenant_id IS NULL"
    )


def downgrade() -> None:
    op.drop_index("ix_risk_policies_tenant_id", table_name="risk_policies")
    op.drop_constraint("fk_risk_policies_tenant", "risk_policies", type_="foreignkey")
    op.drop_column("risk_policies", "tenant_id")

    op.drop_index("ix_capital_pools_tenant_id", table_name="capital_pools")
    op.drop_constraint("fk_capital_pools_tenant", "capital_pools", type_="foreignkey")
    op.drop_column("capital_pools", "tenant_id")

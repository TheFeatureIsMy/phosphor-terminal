"""risk policy version rls

Revision ID: 66b99c27f75e
Revises: 8f43eae7587d
Create Date: 2026-11-17 01:45:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = '66b99c27f75e'
down_revision: Union[str, Sequence[str], None] = '8f43eae7587d'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("risk_policy_versions", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_foreign_key(
        "fk_risk_policy_versions_tenant", "risk_policy_versions", "tenants",
        ["tenant_id"], ["id"], ondelete="SET NULL",
    )
    op.create_index(
        "ix_risk_policy_versions_tenant_id", "risk_policy_versions", ["tenant_id"]
    )
    op.execute(
        """
        UPDATE risk_policy_versions v
        SET tenant_id = p.tenant_id
        FROM risk_policies p
        WHERE v.risk_policy_id = p.id AND v.tenant_id IS NULL
        """
    )
    op.execute(
        """
        CREATE POLICY tenant_isolation_risk_policy_versions
          ON risk_policy_versions
          USING (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
          WITH CHECK (
            tenant_id = NULLIF(current_setting('app.tenant_id', true), '')::int
          )
        """
    )
    op.execute("ALTER TABLE risk_policy_versions ENABLE ROW LEVEL SECURITY")


def downgrade() -> None:
    op.execute("ALTER TABLE risk_policy_versions DISABLE ROW LEVEL SECURITY")
    op.execute(
        "DROP POLICY IF EXISTS tenant_isolation_risk_policy_versions "
        "ON risk_policy_versions"
    )
    op.drop_index("ix_risk_policy_versions_tenant_id", table_name="risk_policy_versions")
    op.drop_constraint(
        "fk_risk_policy_versions_tenant", "risk_policy_versions", type_="foreignkey"
    )
    op.drop_column("risk_policy_versions", "tenant_id")

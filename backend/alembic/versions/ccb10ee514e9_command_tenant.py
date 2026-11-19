"""command tenant

Revision ID: ccb10ee514e9
Revises: 63491bf52939
Create Date: 2026-11-17 02:15:00.000000
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = 'ccb10ee514e9'
down_revision: Union[str, Sequence[str], None] = '63491bf52939'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column("command_bus_commands", sa.Column("tenant_id", sa.Integer(), nullable=True))
    op.create_index(
        "ix_command_bus_commands_tenant_id", "command_bus_commands", ["tenant_id"]
    )
    op.execute(
        """
        UPDATE command_bus_commands
        SET tenant_id = NULLIF(payload->>'tenant_id', '')::int
        WHERE tenant_id IS NULL AND payload->>'tenant_id' IS NOT NULL
        """
    )


def downgrade() -> None:
    op.drop_index("ix_command_bus_commands_tenant_id", table_name="command_bus_commands")
    op.drop_column("command_bus_commands", "tenant_id")

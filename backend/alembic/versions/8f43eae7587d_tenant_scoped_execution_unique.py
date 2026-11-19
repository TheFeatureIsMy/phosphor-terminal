"""tenant scoped execution unique

Revision ID: 8f43eae7587d
Revises: 24b2af3b76ba
Create Date: 2026-11-17 01:35:00.000000
"""
from typing import Sequence, Union

from alembic import op


revision: str = '8f43eae7587d'
down_revision: Union[str, Sequence[str], None] = '24b2af3b76ba'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def _drop_unique_constraints(table: str) -> None:
    op.execute(
        f"""
        DO $$
        DECLARE r record;
        BEGIN
          FOR r IN
            SELECT conname FROM pg_constraint
            WHERE conrelid = '{table}'::regclass AND contype = 'u'
          LOOP
            EXECUTE format('ALTER TABLE {table} DROP CONSTRAINT %I', r.conname);
          END LOOP;
        END $$;
        """
    )


def upgrade() -> None:
    _drop_unique_constraints("execution_orders")
    op.create_unique_constraint(
        "uq_execution_orders_tenant_source", "execution_orders",
        ["tenant_id", "source_system", "source_order_id"],
    )
    _drop_unique_constraints("execution_trades")
    op.create_unique_constraint(
        "uq_execution_trades_tenant_source", "execution_trades",
        ["tenant_id", "source_system", "source_trade_id"],
    )


def downgrade() -> None:
    op.drop_constraint(
        "uq_execution_trades_tenant_source", "execution_trades", type_="unique"
    )
    op.create_unique_constraint(
        "execution_trades_source_system_source_trade_id_key",
        "execution_trades", ["source_system", "source_trade_id"],
    )
    op.drop_constraint(
        "uq_execution_orders_tenant_source", "execution_orders", type_="unique"
    )
    op.create_unique_constraint(
        "execution_orders_source_system_source_order_id_key",
        "execution_orders", ["source_system", "source_order_id"],
    )

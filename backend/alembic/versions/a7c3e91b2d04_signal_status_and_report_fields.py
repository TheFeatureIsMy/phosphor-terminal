"""Widen signal status and add missing research report fields."""
from alembic import op
import sqlalchemy as sa

revision = "a7c3e91b2d04"
down_revision = "f1a2b3c4d5e6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("signals", "status", type_=sa.String(32), existing_nullable=False)
    op.alter_column("signal_lifecycle_events", "from_status", type_=sa.String(32), existing_nullable=True)
    op.alter_column("signal_lifecycle_events", "to_status", type_=sa.String(32), existing_nullable=True)
    op.add_column("research_reports", sa.Column("uncertainty", sa.Float(), nullable=False, server_default="0.5"))
    op.add_column("research_reports", sa.Column("facts", sa.JSON(), nullable=False, server_default="[]"))
    op.add_column("research_reports", sa.Column("model_interpretation", sa.Text(), nullable=False, server_default=""))
    op.add_column("research_reports", sa.Column("trading_implication", sa.Text(), nullable=False, server_default=""))
    op.add_column("research_reports", sa.Column("risk_warning", sa.Text(), nullable=False, server_default=""))
    op.add_column("research_reports", sa.Column("strategy_impact", sa.Text(), nullable=False, server_default=""))
    op.add_column("research_reports", sa.Column("prompt_version", sa.String(16), nullable=False, server_default="2.5.1"))


def downgrade() -> None:
    op.drop_column("research_reports", "prompt_version")
    op.drop_column("research_reports", "strategy_impact")
    op.drop_column("research_reports", "risk_warning")
    op.drop_column("research_reports", "trading_implication")
    op.drop_column("research_reports", "model_interpretation")
    op.drop_column("research_reports", "facts")
    op.drop_column("research_reports", "uncertainty")
    op.alter_column("signals", "status", type_=sa.String(16), existing_nullable=False)
    op.alter_column("signal_lifecycle_events", "from_status", type_=sa.String(16), existing_nullable=True)
    op.alter_column("signal_lifecycle_events", "to_status", type_=sa.String(16), existing_nullable=True)

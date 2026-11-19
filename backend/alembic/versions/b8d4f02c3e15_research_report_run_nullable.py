"""Allow signal-center research reports without a research run."""
from alembic import op

revision = "b8d4f02c3e15"
down_revision = "a7c3e91b2d04"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column("research_reports", "run_id", nullable=True)


def downgrade() -> None:
    op.alter_column("research_reports", "run_id", nullable=False)
import sys
from logging.config import fileConfig
from pathlib import Path

from sqlalchemy import engine_from_config, pool

from alembic import context

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.config import settings  # noqa: E402
from app.database.base import Base  # noqa: E402

# Import all model modules so Base.metadata is populated
import app.models.strategy  # noqa: F401, E402
import app.models.user  # noqa: F401, E402
import app.models.ai  # noqa: F401, E402
import app.models.ai_provider  # noqa: F401, E402
import app.models.agent_signal  # noqa: F401, E402
import app.models.dryrun  # noqa: F401, E402
import app.models.research  # noqa: F401, E402
import app.models.research_v2  # noqa: F401, E402
import app.domain.command  # noqa: F401, E402
import app.domain.execution  # noqa: F401, E402
import app.domain.feature  # noqa: F401, E402
import app.domain.growth  # noqa: F401, E402
import app.domain.ledger  # noqa: F401, E402
import app.domain.manipulation  # noqa: F401, E402
import app.domain.order  # noqa: F401, E402
import app.domain.outbox  # noqa: F401, E402
import app.domain.provider  # noqa: F401, E402
import app.domain.risk  # noqa: F401, E402
import app.domain.signal  # noqa: F401, E402
import app.domain.strategy  # noqa: F401, E402
import app.domain.trade_intent  # noqa: F401, E402
import app.domain.inference  # noqa: F401, E402
import app.domain.mcp  # noqa: F401, E402
import app.domain.reconciliation  # noqa: F401, E402
import app.domain.archive  # noqa: F401, E402
import app.domain.runtime  # noqa: F401, E402

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

config.set_main_option("sqlalchemy.url", settings.database_url)

target_metadata = Base.metadata


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    connectable = engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    with connectable.connect() as connection:
        context.configure(
            connection=connection,
            target_metadata=target_metadata,
        )
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()

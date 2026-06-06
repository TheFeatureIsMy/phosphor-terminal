from datetime import datetime, timedelta

from sqlalchemy import text
from sqlalchemy.engine import Engine


def ensure_monthly_partition(engine: Engine, table_name: str, year: int, month: int) -> None:
    start = datetime(year, month, 1)
    if month == 12:
        end = datetime(year + 1, 1, 1)
    else:
        end = datetime(year, month + 1, 1)
    partition_name = f"{table_name}_{year}_{month:02d}"
    sql = text(f"""
        CREATE TABLE IF NOT EXISTS {partition_name}
        PARTITION OF {table_name}
        FOR VALUES FROM ('{start.strftime('%Y-%m-%d')}')
        TO ('{end.strftime('%Y-%m-%d')}')
    """)
    with engine.begin() as conn:
        conn.execute(sql)


def ensure_current_partitions(engine: Engine, partitioned_tables: list[str]) -> None:
    now = datetime.utcnow()
    next_month = (now.replace(day=1) + timedelta(days=32)).replace(day=1)
    for table in partitioned_tables:
        ensure_monthly_partition(engine, table, now.year, now.month)
        ensure_monthly_partition(engine, table, next_month.year, next_month.month)

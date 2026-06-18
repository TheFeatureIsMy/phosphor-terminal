from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session

from app.config import settings
from app.database.base import Base

from app.domain.activity_log import StrategyActivityLog  # noqa: F401

engine = create_engine(settings.database_url)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    Base.metadata.create_all(bind=engine)


def check_db() -> bool:
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        return True
    except Exception:
        return False

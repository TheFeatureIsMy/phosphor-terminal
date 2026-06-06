import uuid
from typing import Generic, TypeVar, Type, Optional

from sqlalchemy import select, func
from sqlalchemy.orm import Session

from app.database.base import Base

T = TypeVar("T", bound=Base)


class BaseRepository(Generic[T]):
    def __init__(self, model: Type[T], session: Session):
        self._model = model
        self._session = session

    def get_by_id(self, entity_id: uuid.UUID) -> Optional[T]:
        return self._session.get(self._model, entity_id)

    def list(self, *, offset: int = 0, limit: int = 50) -> list[T]:
        stmt = select(self._model).offset(offset).limit(limit)
        return list(self._session.scalars(stmt).all())

    def count(self) -> int:
        stmt = select(func.count()).select_from(self._model)
        return self._session.scalar(stmt) or 0

    def create(self, entity: T) -> T:
        self._session.add(entity)
        self._session.flush()
        return entity

    def delete(self, entity: T) -> None:
        self._session.delete(entity)
        self._session.flush()

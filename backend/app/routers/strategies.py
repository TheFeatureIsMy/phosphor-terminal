from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models.strategy import Strategy
from app.schemas.api import StrategyCreate, StrategyUpdate, StrategyResponse

router = APIRouter(prefix="/api/strategies", tags=["strategies"])


@router.get("", response_model=list[StrategyResponse])
def list_strategies(db: Session = Depends(get_db)):
    return db.query(Strategy).all()


@router.get("/{strategy_id}", response_model=StrategyResponse)
def get_strategy(strategy_id: int, db: Session = Depends(get_db)):
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    return strategy


@router.post("", response_model=StrategyResponse)
def create_strategy(data: StrategyCreate, db: Session = Depends(get_db)):
    strategy = Strategy(
        name=data.name,
        type=data.type,
        parameters=data.parameters,
        market=data.market,
        exchange=data.exchange,
    )
    db.add(strategy)
    db.commit()
    db.refresh(strategy)
    return strategy


@router.put("/{strategy_id}", response_model=StrategyResponse)
def update_strategy(strategy_id: int, data: StrategyUpdate, db: Session = Depends(get_db)):
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(strategy, field, value)
    strategy.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(strategy)
    return strategy


@router.delete("/{strategy_id}", status_code=204)
def delete_strategy(strategy_id: int, db: Session = Depends(get_db)):
    strategy = db.query(Strategy).filter(Strategy.id == strategy_id).first()
    if not strategy:
        raise HTTPException(status_code=404, detail="Strategy not found")
    db.delete(strategy)
    db.commit()

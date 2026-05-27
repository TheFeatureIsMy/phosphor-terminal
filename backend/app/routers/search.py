from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.database import get_db
from app.models.strategy import Strategy
from app.models.user import User

router = APIRouter(prefix="/search", tags=["search"])


@router.get("")
def global_search(
    q: str = Query(..., min_length=1, max_length=100),
    db: Session = Depends(get_db),
):
    results = []

    strategies = db.query(Strategy).filter(
        or_(
            Strategy.name.ilike(f"%{q}%"),
            Strategy.type.ilike(f"%{q}%"),
            Strategy.market.ilike(f"%{q}%"),
        )
    ).limit(10).all()

    for s in strategies:
        results.append({
            "type": "strategy",
            "id": s.id,
            "title": s.name,
            "subtitle": f"{s.type} · {s.market} · {s.status}",
            "url": f"/strategies/{s.id}",
        })

    return {"query": q, "results": results, "total": len(results)}

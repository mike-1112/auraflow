from fastapi import APIRouter, Query
from typing import List, Optional
from sqlmodel import Session, select
from app.db import engine
from app.models import CheckInDB

router = APIRouter()

@router.get("", response_model=List[CheckInDB])
def list_history(
    user_id: str = Query(...),
    limit: int = Query(20, ge=1, le=200),
):
    with Session(engine) as session:
        stmt = (
            select(CheckInDB)
            .where(CheckInDB.user_id == user_id)
            .order_by(CheckInDB.ts.desc())
            .limit(limit)
        )
        return session.exec(stmt).all()

from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional, List
from sqlmodel import Session, select
from app.models import CheckInDB
from app.db import engine

router = APIRouter()

class CheckIn(BaseModel):
    user_id: str
    energy: float  # 010
    mood: Optional[str] = None  # e.g., "focused","tired","anxious"

@router.post("", response_model=dict)
def create_checkin(ci: CheckIn):
    with Session(engine) as session:
        row = CheckInDB(user_id=ci.user_id, energy=ci.energy, mood=ci.mood)
        session.add(row)
        session.commit()
        session.refresh(row)
        return {"ok": True, "id": row.id, "ts": row.ts.isoformat() + "Z"}

@router.get("", response_model=List[CheckInDB])
def list_checkins(user_id: str):
    with Session(engine) as session:
        stmt = select(CheckInDB).where(CheckInDB.user_id == user_id).order_by(CheckInDB.ts.desc())
        return session.exec(stmt).all()

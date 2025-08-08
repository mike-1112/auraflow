from fastapi import APIRouter, Query
from pydantic import BaseModel
from typing import Optional, List
from sqlmodel import Session, select
from app.db import engine
from app.models import DietEntryDB

router = APIRouter()

class DietIn(BaseModel):
    user_id: int
    item: str
    qty: Optional[str] = None
    notes: Optional[str] = None

@router.post("", response_model=dict)
def add_diet(d: DietIn):
    with Session(engine) as s:
        row = DietEntryDB(user_id=d.user_id, item=d.item, qty=d.qty, notes=d.notes)
        s.add(row); s.commit(); s.refresh(row)
        return {"ok": True, "id": row.id, "when": row.when.isoformat()+"Z"}

@router.get("", response_model=List[DietEntryDB])
def list_diet(user_id: int, limit: int = Query(50, ge=1, le=200)):
    with Session(engine) as s:
        q = select(DietEntryDB).where(DietEntryDB.user_id==user_id).order_by(DietEntryDB.when.desc()).limit(limit)
        return s.exec(q).all()

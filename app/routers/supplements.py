from fastapi import APIRouter, Query
from pydantic import BaseModel
from typing import Optional, List
from sqlmodel import Session, select
from app.db import engine
from app.models import SupplementEntryDB

router = APIRouter()

class SuppIn(BaseModel):
    user_id: int
    name: str
    dose: Optional[str] = None
    notes: Optional[str] = None

@router.post("", response_model=dict)
def add_supp(sup: SuppIn):
    with Session(engine) as s:
        row = SupplementEntryDB(user_id=sup.user_id, name=sup.name, dose=sup.dose, notes=sup.notes)
        s.add(row); s.commit(); s.refresh(row)
        return {"ok": True, "id": row.id, "when": row.when.isoformat()+"Z"}

@router.get("", response_model=List[SupplementEntryDB])
def list_supp(user_id: int, limit: int = Query(50, ge=1, le=200)):
    with Session(engine) as s:
        q = select(SupplementEntryDB).where(SupplementEntryDB.user_id==user_id).order_by(SupplementEntryDB.when.desc()).limit(limit)
        return s.exec(q).all()

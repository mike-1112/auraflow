from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from typing import Optional, List
from sqlmodel import Session, select
from app.db import engine
from app.models import CheckInDB, UserPrefsDB, DietEntryDB, SupplementEntryDB
from app.deps_current_user import get_current_user
from app.models_user import UserDB
from datetime import datetime

router = APIRouter()

# ---- Check-in ----
class CheckInIn(BaseModel):
    energy: float
    mood: Optional[str] = None

@router.post("/checkin", response_model=dict)
def me_checkin(body: CheckInIn, user: UserDB = Depends(get_current_user)):
    with Session(engine) as s:
        row = CheckInDB(user_id=user.id, energy=body.energy, mood=body.mood)
        s.add(row); s.commit(); s.refresh(row)
        return {"ok": True, "id": row.id, "ts": row.ts.isoformat() + "Z"}

@router.get("/history", response_model=List[CheckInDB])
def me_history(limit: int = Query(50, ge=1, le=200), user: UserDB = Depends(get_current_user)):
    with Session(engine) as s:
        q = (select(CheckInDB)
             .where(CheckInDB.user_id == user.id)
             .order_by(CheckInDB.ts.desc())
             .limit(limit))
        return s.exec(q).all()

# ---- Preferences ----
class PrefsIn(BaseModel):
    show_diet: Optional[bool] = None
    show_supplements: Optional[bool] = None

@router.get("/prefs")
def me_get_prefs(user: UserDB = Depends(get_current_user)):
    with Session(engine) as s:
        prefs = s.exec(select(UserPrefsDB).where(UserPrefsDB.user_id == user.id)).first()
        if not prefs:
            prefs = UserPrefsDB(user_id=user.id); s.add(prefs); s.commit(); s.refresh(prefs)
        return {"show_diet": prefs.show_diet, "show_supplements": prefs.show_supplements}

@router.post("/prefs")
def me_set_prefs(p: PrefsIn, user: UserDB = Depends(get_current_user)):
    with Session(engine) as s:
        prefs = s.exec(select(UserPrefsDB).where(UserPrefsDB.user_id == user.id)).first() or UserPrefsDB(user_id=user.id)
        if p.show_diet is not None: prefs.show_diet = p.show_diet
        if p.show_supplements is not None: prefs.show_supplements = p.show_supplements
        s.add(prefs); s.commit(); s.refresh(prefs)
        return {"ok": True, "prefs": {"show_diet": prefs.show_diet, "show_supplements": prefs.show_supplements}}

# ---- Diet & Supplements (optional modules) ----
class DietIn(BaseModel):
    item: str
    qty: Optional[str] = None
    notes: Optional[str] = None

@router.post("/diet", response_model=dict)
def me_add_diet(d: DietIn, user: UserDB = Depends(get_current_user)):
    with Session(engine) as s:
        row = DietEntryDB(user_id=user.id, item=d.item, qty=d.qty, notes=d.notes)
        s.add(row); s.commit(); s.refresh(row)
        return {"ok": True, "id": row.id, "when": row.when.isoformat()+"Z"}

@router.get("/diet", response_model=List[DietEntryDB])
def me_list_diet(limit: int = Query(50, ge=1, le=200), user: UserDB = Depends(get_current_user)):
    with Session(engine) as s:
        q = (select(DietEntryDB)
             .where(DietEntryDB.user_id == user.id)
             .order_by(DietEntryDB.when.desc())
             .limit(limit))
        return s.exec(q).all()

class SuppIn(BaseModel):
    name: str
    dose: Optional[str] = None
    notes: Optional[str] = None

@router.post("/supplements", response_model=dict)
def me_add_supp(sup: SuppIn, user: UserDB = Depends(get_current_user)):
    with Session(engine) as s:
        row = SupplementEntryDB(user_id=user.id, name=sup.name, dose=sup.dose, notes=sup.notes)
        s.add(row); s.commit(); s.refresh(row)
        return {"ok": True, "id": row.id, "when": row.when.isoformat()+"Z"}

@router.get("/supplements", response_model=List[SupplementEntryDB])
def me_list_supp(limit: int = Query(50, ge=1, le=200), user: UserDB = Depends(get_current_user)):
    with Session(engine) as s:
        q = (select(SupplementEntryDB)
             .where(SupplementEntryDB.user_id == user.id)
             .order_by(SupplementEntryDB.when.desc())
             .limit(limit))
        return s.exec(q).all()

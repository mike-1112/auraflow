from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from sqlmodel import Session, select
from app.db import engine
from app.models import UserPrefsDB

router = APIRouter()

class PrefsIn(BaseModel):
    user_id: int
    show_diet: bool | None = None
    show_supplements: bool | None = None

@router.get("")
def get_prefs(user_id: int):
    with Session(engine) as s:
        prefs = s.exec(select(UserPrefsDB).where(UserPrefsDB.user_id==user_id)).first()
        if not prefs: 
            prefs = UserPrefsDB(user_id=user_id); s.add(prefs); s.commit(); s.refresh(prefs)
        return {"user_id": prefs.user_id, "show_diet": prefs.show_diet, "show_supplements": prefs.show_supplements}

@router.post("")
def set_prefs(p: PrefsIn):
    with Session(engine) as s:
        prefs = s.exec(select(UserPrefsDB).where(UserPrefsDB.user_id==p.user_id)).first()
        if not prefs:
            prefs = UserPrefsDB(user_id=p.user_id)
        if p.show_diet is not None: prefs.show_diet = p.show_diet
        if p.show_supplements is not None: prefs.show_supplements = p.show_supplements
        s.add(prefs); s.commit(); s.refresh(prefs)
        return {"ok": True, "prefs": {"show_diet": prefs.show_diet, "show_supplements": prefs.show_supplements}}

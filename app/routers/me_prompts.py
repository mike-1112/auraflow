from fastapi import APIRouter, Depends
from app.deps_current_user import get_current_user
from app.models_user import UserDB

router = APIRouter()

@router.get("/daily")
def daily_prompt(user: UserDB = Depends(get_current_user)):
    # simple placeholder; later personalize by user habits, prefs, history
    return {"prompt": "4-7-8 breathing, 3 minutes.", "type": "alignment"}

from fastapi import APIRouter, Query

router = APIRouter()

@router.get("/daily")
def daily_prompt(user_id: str = Query(...)):
    # TODO: personalize; stub for now
    return {"user_id": user_id, "prompt": "4-7-8 breathing, 3 minutes.", "type": "alignment"}

from fastapi import FastAPI
from app.routers import checkin, prompts, history, users, diet, supplements, prefs, me
from app.db import init_db

app = FastAPI(title="AuraFlow API", version="0.1.0")

@app.on_event("startup")
def on_startup():
    init_db()

@app.get("/")
def root():
    return {"message": "AuraFlow API is running"}

@app.get("/health")
def health():
    return {"status": "ok"}

app.include_router(users.router,        prefix="/users",        tags=["Users"])
app.include_router(checkin.router,      prefix="/checkin",      tags=["Check-in"])
app.include_router(diet.router,         prefix="/diet",         tags=["Diet"])
app.include_router(supplements.router,  prefix="/supplements",  tags=["Supplements"])
app.include_router(prefs.router,        prefix="/prefs",        tags=["Preferences"])
app.include_router(prompts.router,      prefix="/prompts",      tags=["Prompts"])
app.include_router(history.router,      prefix="/history",      tags=["History"])

app.include_router(me.router, prefix="/me", tags=["Me"])
from fastapi.middleware.cors import CORSMiddleware
from app.config import ALLOWED_ORIGINS

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS if ALLOWED_ORIGINS != ["*"] else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

from app.routers import me_prompts

app.include_router(me_prompts.router, prefix="/me/prompts", tags=["Me"])

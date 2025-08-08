from fastapi import FastAPI
from app.routers import checkin, prompts, history, users
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

app.include_router(users.router, prefix="/users", tags=["Users"])
app.include_router(checkin.router, prefix="/checkin", tags=["Check-in"])
app.include_router(prompts.router, prefix="/prompts", tags=["Prompts"])
app.include_router(history.router, prefix="/history", tags=["History"])

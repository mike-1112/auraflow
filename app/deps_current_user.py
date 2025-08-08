from fastapi import Header, HTTPException, status
from typing import Optional
from jose import JWTError
from app.auth import decode_access_token
from sqlmodel import Session, select
from app.db import engine
from app.models_user import UserDB

def get_current_user(authorization: Optional[str] = Header(None)) -> UserDB:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing Bearer token")
    token = authorization.split(" ", 1)[1]
    payload = decode_access_token(token)
    if not payload or "sub" not in payload:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user_id = int(payload["sub"])
    with Session(engine) as session:
        user = session.exec(select(UserDB).where(UserDB.id == user_id)).first()
        if not user:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
        return user

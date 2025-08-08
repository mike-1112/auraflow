from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlmodel import Session, select
from app.db import engine
from app.models_user import UserDB
from app.auth import hash_password, verify_password, create_access_token

router = APIRouter()

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

@router.post("/signup")
def signup(user: UserCreate):
    with Session(engine) as session:
        existing = session.exec(select(UserDB).where(UserDB.email == user.email)).first()
        if existing:
            raise HTTPException(status_code=400, detail="Email already registered")
        db_user = UserDB(
            name=user.name,
            email=user.email,
            hashed_password=hash_password(user.password)
        )
        session.add(db_user)
        session.commit()
        session.refresh(db_user)
        return {"id": db_user.id, "email": db_user.email}

@router.post("/login")
def login(credentials: UserLogin):
    with Session(engine) as session:
        user = session.exec(select(UserDB).where(UserDB.email == credentials.email)).first()
        if not user or not verify_password(credentials.password, user.hashed_password):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
        token = create_access_token({"sub": str(user.id)})
        return {"access_token": token, "token_type": "bearer"}

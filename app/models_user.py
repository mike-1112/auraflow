from datetime import datetime
from typing import Optional
from sqlmodel import SQLModel, Field

class UserDB(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    name: str
    email: str
    hashed_password: str
    created_at: datetime = Field(default_factory=datetime.utcnow)

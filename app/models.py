from datetime import datetime
from typing import Optional
from sqlmodel import SQLModel, Field

class CheckInDB(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: str
    energy: float
    mood: Optional[str] = None
    ts: datetime = Field(default_factory=datetime.utcnow)
from typing import Optional
from datetime import datetime
from sqlmodel import SQLModel, Field

class DietEntryDB(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int
    when: datetime = Field(default_factory=datetime.utcnow)
    item: str                   # free text: "eggs + toast"
    qty: Optional[str] = None   # "2 eggs", "1 slice"
    notes: Optional[str] = None

class SupplementEntryDB(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int
    when: datetime = Field(default_factory=datetime.utcnow)
    name: str                   # "Vitamin D3"
    dose: Optional[str] = None  # "2000 IU"
    notes: Optional[str] = None

class UserPrefsDB(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: int
    show_diet: bool = True
    show_supplements: bool = True

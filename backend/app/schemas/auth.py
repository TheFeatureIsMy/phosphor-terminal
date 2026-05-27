from datetime import datetime
from pydantic import BaseModel, Field, EmailStr
from typing import Optional
class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: str = Field(..., min_length=5, max_length=255)
    password: str = Field(..., min_length=6, max_length=128)
class UserLogin(BaseModel):
    username: str
    password: str
class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    is_active: bool
    avatar_url: Optional[str]
    created_at: datetime
    model_config = {"from_attributes": True}
class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
class TokenRefresh(BaseModel):
    refresh_token: str
class UserSettingsUpdate(BaseModel):
    theme: Optional[str] = None
    language: Optional[str] = None
    notifications_enabled: Optional[bool] = None
    default_exchange: Optional[str] = None
    default_market: Optional[str] = None
    risk_tolerance: Optional[str] = None
class UserSettingsResponse(BaseModel):
    id: int
    user_id: int
    theme: str
    language: str
    notifications_enabled: bool
    default_exchange: str
    default_market: str
    risk_tolerance: str
    created_at: datetime
    updated_at: datetime
    model_config = {"from_attributes": True}

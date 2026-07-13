from pydantic import BaseModel, Field


class UpsertRequest(BaseModel):
    """Called after Firebase sign-in. Backend finds-or-creates the User row by
    firebase_uid so the same user_id is returned across sessions."""
    firebase_uid: str = Field(min_length=1, max_length=128)
    nickname: str = Field(min_length=1, max_length=40)
    email: str | None = None
    photo_url: str | None = None
    is_guest: bool = False


class GuestLoginRequest(BaseModel):
    """Legacy: creates a throwaway guest row with no firebase_uid."""
    nickname: str = Field(min_length=2, max_length=20)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    nickname: str


class MeResponse(BaseModel):
    user_id: str
    nickname: str
    photo_url: str | None
    email: str | None
    is_guest: bool


class ProfileUpdateRequest(BaseModel):
    nickname: str | None = Field(default=None, min_length=1, max_length=40)
    photo_url: str | None = None

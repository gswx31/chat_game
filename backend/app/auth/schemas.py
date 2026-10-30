from pydantic import BaseModel, Field


class GuestLoginRequest(BaseModel):
    """기기 고유 ID로 게스트 계정 find-or-create.
    같은 device_id는 항상 같은 user_id를 반환한다."""
    device_id: str = Field(min_length=8, max_length=128)


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

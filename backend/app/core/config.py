from typing import Self

from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

_PUBLIC_SECRETS = {"dev-secret-change-me", "change-me-please-make-it-long-and-random"}


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    app_env: str = "dev"
    secret_key: str = "dev-secret-change-me"
    access_token_expire_minutes: int = 60 * 24 * 7
    algorithm: str = "HS256"

    database_url: str = "postgresql+asyncpg://chatgame:chatgame@localhost:5432/chatgame"
    redis_url: str = "redis://localhost:6379/0"

    cors_origins: str = "http://localhost:5173"

    # Folder with the built web client (web/dist). Empty = API only.
    web_dist_dir: str = ""

    @field_validator("database_url", mode="before")
    @classmethod
    def _ensure_async_driver(cls, v: object) -> object:
        """Managed providers (Fly Postgres, Railway, Heroku) hand out
        ``postgres://`` URLs; SQLAlchemy 2.0 + asyncpg needs
        ``postgresql+asyncpg://``. Translate transparently so the user can
        paste the provider URL into env without thinking."""
        if not isinstance(v, str):
            return v
        if v.startswith("postgres://"):
            return "postgresql+asyncpg://" + v[len("postgres://") :]
        if v.startswith("postgresql://") and "+" not in v.split("://", 1)[0]:
            return "postgresql+asyncpg://" + v[len("postgresql://") :]
        return v

    @model_validator(mode="after")
    def _refuse_default_secret_in_production(self) -> Self:
        """The default key is public (it is in this repo). With it anyone can mint a
        valid login token for any user, so production must bring its own."""
        weak = self.secret_key in _PUBLIC_SECRETS or len(self.secret_key) < 32
        if self.app_env == "production" and weak:
            raise ValueError("SECRET_KEY must be a random value of 32+ characters in production")
        return self

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


settings = Settings()

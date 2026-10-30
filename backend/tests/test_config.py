import pytest

from app.core.config import Settings


def test_dev_may_use_the_default_secret():
    Settings(app_env="dev", secret_key="dev-secret-change-me")


@pytest.mark.parametrize("key", ["dev-secret-change-me", "short", "x" * 31])
def test_production_rejects_default_or_short_secret(key):
    with pytest.raises(ValueError, match="SECRET_KEY"):
        Settings(app_env="production", secret_key=key)


def test_production_accepts_a_long_random_secret():
    Settings(app_env="production", secret_key="k" * 48)

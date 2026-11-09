"""Centralized backend configuration and fail-fast environment validation.

Secrets are never included in validation errors or startup logs.
"""

import os
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Mapping
from urllib.parse import urlparse

from dotenv import load_dotenv


# Resolve .env from the backend directory, independent of the process CWD.
BACKEND_DIR = Path(__file__).resolve().parent
load_dotenv(dotenv_path=BACKEND_DIR / ".env", override=False)

_REQUIRED_ENV_VARS = (
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "GEMINI_API_KEY",
)

_PLACEHOLDER_VALUES = {
    "changeme",
    "change-me",
    "your_api_key",
    "your-api-key",
    "your_supabase_url",
    "your-supabase-url",
    "replace_me",
    "replace-me",
}


@dataclass(frozen=True)
class Settings:
    """Validated runtime settings. Do not log or serialize this object."""

    supabase_url: str
    supabase_service_role_key: str = field(repr=False)
    gemini_api_key: str = field(repr=False)
    cohere_api_key: str | None = field(default=None, repr=False)


def _is_missing_or_placeholder(value: str | None) -> bool:
    if value is None:
        return True

    normalized = value.strip().lower()
    if not normalized or normalized in _PLACEHOLDER_VALUES:
        return True

    if normalized.startswith(("your_", "your-", "replace_", "replace-", "change_", "change-")):
        return True

    # A sample Supabase host such as https://your-project.supabase.co is not
    # a usable project URL even though it has a syntactically valid scheme.
    parsed = urlparse(normalized)
    hostname = parsed.hostname or ""
    if hostname.startswith(("your-", "replace-")):
        return True

    # Render Blueprint interpolation is not supported. Detect unresolved
    # placeholders such as "${SUPABASE_URL}" instead of using them as secrets.
    return normalized.startswith("${") and normalized.endswith("}")


def build_settings(environ: Mapping[str, str]) -> Settings:
    """Build settings from a supplied environment mapping (easy to unit test)."""

    missing = [
        name
        for name in _REQUIRED_ENV_VARS
        if _is_missing_or_placeholder(environ.get(name))
    ]

    invalid = []
    supabase_url = (environ.get("SUPABASE_URL") or "").strip()
    if supabase_url and not _is_missing_or_placeholder(supabase_url):
        parsed = urlparse(supabase_url)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            invalid.append("SUPABASE_URL")

    if missing or invalid:
        problems = []
        if missing:
            problems.append("missing or empty: " + ", ".join(missing))
        if invalid:
            problems.append("invalid format: " + ", ".join(invalid))

        raise RuntimeError(
            "Backend startup configuration is invalid ("
            + "; ".join(problems)
            + "). Set these variables in the backend environment and restart."
        )

    raw_cohere_value = environ.get("COHERE_API_KEY")
    cohere_value = (
        raw_cohere_value.strip()
        if raw_cohere_value and not _is_missing_or_placeholder(raw_cohere_value)
        else None
    )

    return Settings(
        supabase_url=supabase_url,
        supabase_service_role_key=environ["SUPABASE_SERVICE_ROLE_KEY"].strip(),
        gemini_api_key=environ["GEMINI_API_KEY"].strip(),
        cohere_api_key=cohere_value,
    )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return process-wide settings, validating required values on first use."""

    return build_settings(os.environ)

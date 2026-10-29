"""Resolve legacy Supabase file URLs to private object paths and download safely."""
from urllib.parse import unquote, urlparse

from fastapi import HTTPException
from security import supabase_admin


def storage_path_from_reference(reference: str, bucket: str) -> str:
    value = (reference or "").strip()
    if not value:
        raise HTTPException(status_code=400, detail="Missing file reference")

    if "://" not in value and not value.startswith("/"):
        path = value.lstrip("/")
        if path.startswith(f"{bucket}/"):
            path = path[len(bucket) + 1:]
        if path:
            return path

    parsed = urlparse(value)
    segments = [unquote(segment) for segment in parsed.path.split("/") if segment]
    for i in range(len(segments) - 3):
        if (
            segments[i] == "object"
            and segments[i + 1] in {"public", "sign", "authenticated"}
            and segments[i + 2] == bucket
        ):
            path = "/".join(segments[i + 3:])
            if path:
                return path
    raise HTTPException(status_code=400, detail=f"Invalid {bucket} file reference")


def download_private_file(reference: str, bucket: str) -> bytes:
    path = storage_path_from_reference(reference, bucket)
    try:
        content = supabase_admin.storage.from_(bucket).download(path)
        if not content:
            raise HTTPException(status_code=404, detail="File not found")
        return content
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=404, detail="File not found or access denied")

"""Resolve legacy Supabase file URLs to private object paths and download safely."""

import httpx
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
    """Download one private object with a bounded timeout and safe HTTP errors."""

    path = storage_path_from_reference(reference, bucket)
    try:
        content = supabase_admin.storage.from_(bucket).download(path)
        if not content:
            raise HTTPException(status_code=404, detail="File not found")
        return content

    except HTTPException:
        raise
    except httpx.TimeoutException as exc:
        raise HTTPException(
            status_code=504,
            detail="Timed out while downloading the PDF from storage. Please retry.",
        ) from exc
    except httpx.ConnectError as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not connect to file storage. Please retry shortly.",
        ) from exc
    except httpx.RequestError as exc:
        raise HTTPException(
            status_code=502,
            detail="File storage request failed. Please retry.",
        ) from exc
    except Exception as exc:
        # Supabase Storage SDK errors may expose the upstream HTTP status.
        # Preserve useful not-found/permission statuses without returning
        # upstream response bodies or credentials to the API caller.
        status_code = getattr(exc, "status_code", None)
        if status_code == 404:
            raise HTTPException(status_code=404, detail="File not found") from exc
        if status_code in {401, 403}:
            raise HTTPException(
                status_code=403,
                detail="File storage access was denied.",
            ) from exc
        if status_code in {408, 504}:
            raise HTTPException(
                status_code=504,
                detail="Timed out while downloading the PDF from storage. Please retry.",
            ) from exc

        print(f"[Private Storage Download Error] {type(exc).__name__}")
        raise HTTPException(
            status_code=502,
            detail="Unable to download the file from storage. Please retry.",
        ) from exc

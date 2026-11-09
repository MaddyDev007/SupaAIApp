"""Download PDFs with bounded network waits and extract their text safely."""

import io

import cv2
import numpy as np
import pdfplumber
import pytesseract
import requests
from PIL import Image

from fastapi import HTTPException

from services.private_storage import download_private_file


PDF_CONNECT_TIMEOUT_SECONDS = 5
PDF_READ_TIMEOUT_SECONDS = 20


def _download_external_pdf(pdf_url: str) -> bytes:
    """Download an HTTP PDF using separate connect/read timeouts."""

    try:
        response = requests.get(
            pdf_url,
            timeout=(PDF_CONNECT_TIMEOUT_SECONDS, PDF_READ_TIMEOUT_SECONDS),
        )
        response.raise_for_status()
        if not response.content:
            raise HTTPException(
                status_code=422,
                detail="The PDF download was empty. Please upload the file again.",
            )
        return response.content

    except requests.exceptions.Timeout as exc:
        raise HTTPException(
            status_code=504,
            detail="The PDF download timed out. Please retry.",
        ) from exc
    except requests.exceptions.ConnectionError as exc:
        raise HTTPException(
            status_code=503,
            detail="Could not connect to the PDF source. Please retry shortly.",
        ) from exc
    except requests.exceptions.HTTPError as exc:
        status_code = exc.response.status_code if exc.response is not None else None
        if status_code == 404:
            raise HTTPException(
                status_code=404,
                detail="The requested PDF was not found.",
            ) from exc
        if status_code in {408, 504}:
            raise HTTPException(
                status_code=504,
                detail="The PDF source timed out. Please retry.",
            ) from exc
        raise HTTPException(
            status_code=502,
            detail="The PDF source returned an unsuccessful response.",
        ) from exc
    except requests.exceptions.RequestException as exc:
        raise HTTPException(
            status_code=502,
            detail="Unable to download the PDF. Please retry.",
        ) from exc


def extract_text_from_bytes(pdf_bytes: bytes) -> str:
    """Extract selectable text and use OCR for image-only PDF pages."""

    if not pdf_bytes:
        raise HTTPException(status_code=422, detail="The PDF file is empty.")

    try:
        text_content = []

        with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
            total_pages = len(pdf.pages)

            for index, page in enumerate(pdf.pages, start=1):
                text = page.extract_text()

                if text and text.strip():
                    text_content.append(text)
                    continue

                # OCR fallback for scanned/image-only pages.
                page_image = page.to_image(resolution=300).original
                open_cv_image = cv2.cvtColor(
                    np.array(page_image),
                    cv2.COLOR_RGB2BGR,
                )
                gray = cv2.cvtColor(open_cv_image, cv2.COLOR_BGR2GRAY)
                blur = cv2.GaussianBlur(gray, (5, 5), 0)
                threshold = cv2.adaptiveThreshold(
                    blur,
                    255,
                    cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                    cv2.THRESH_BINARY,
                    31,
                    2,
                )
                ocr_text = pytesseract.image_to_string(
                    threshold,
                    lang="eng",
                    config="--oem 1 --psm 11",
                )
                text_content.append(ocr_text)

        extracted_text = "\n".join(text_content)
        print(
            f"[PDF Extraction] Processed {total_pages} page(s); "
            f"extracted {len(extracted_text)} character(s)."
        )
        return extracted_text

    except HTTPException:
        raise
    except Exception as exc:
        print(f"[PDF Extraction Error] {type(exc).__name__}")
        raise HTTPException(
            status_code=422,
            detail="The PDF is invalid, damaged, or could not be read. Please try another PDF.",
        ) from exc


def extract_text_from_url(pdf_url: str) -> str:
    """Resolve an authorized private Storage URL or download an HTTP resource."""

    # Private lesson objects must be downloaded with the service-role client.
    # This is the active SmartClass path after the upload route checks ownership.
    if "/object/" in pdf_url and "/lessons/" in pdf_url:
        pdf_bytes = download_private_file(pdf_url, "lessons")
    else:
        pdf_bytes = _download_external_pdf(pdf_url)

    return extract_text_from_bytes(pdf_bytes)

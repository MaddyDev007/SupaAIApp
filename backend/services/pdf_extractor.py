import requests
import pdfplumber
import pytesseract
from PIL import Image
import io
import cv2
import numpy as np


def extract_text_from_url(pdf_url: str) -> str:
    print(f"[PDF Extraction] Extracting text from {pdf_url}")

    try:
        # 🧩 Download PDF with timeout
        response = requests.get(pdf_url, timeout=15)
        response.raise_for_status()

        text_content = []

        with pdfplumber.open(io.BytesIO(response.content)) as pdf:
            total_pages = len(pdf.pages)

            for i, page in enumerate(pdf.pages, start=1):
                print(f"🔍 Processing page {i}/{total_pages}...")

                text = page.extract_text()

                if text and text.strip():
                    text_content.append(text)
                else:
                    print(f"📷 OCR fallback on page {i}...")
                    page_image = page.to_image(resolution=300).original
                    
                    open_cv_image = cv2.cvtColor(
                    np.array(page_image), cv2.COLOR_RGB2BGR
                    )
                    gray = cv2.cvtColor(open_cv_image, cv2.COLOR_BGR2GRAY)
                    blur = cv2.GaussianBlur(gray, (5, 5), 0)
                    thresh = cv2.adaptiveThreshold(
                        blur,
                        255,
                        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                        cv2.THRESH_BINARY,
                        31,
                        2
                    )

                    ocr_text = pytesseract.image_to_string(
                        thresh,
                        lang="eng",
                        config="--oem 1 --psm 11"
                    )
                    print(ocr_text)
                    text_content.append(ocr_text)

        final_text = "\n".join(text_content)
        print(f"✅ Extracted {len(final_text)} characters.")
        return final_text

    except requests.exceptions.Timeout:
        print("[PDF Extraction Error] Request timed out")
        return ""

    except Exception as e:
        print(f"[PDF Extraction Error] {e}")
        return ""

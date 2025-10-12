import requests
import pdfplumber
import pytesseract
from PIL import Image
import io

def extract_text_from_url(pdf_url: str) -> str:
    print(f"[PDF Extraction] Extracting text from {pdf_url}")

    try:
        # 🧩 Download the PDF
        response = requests.get(pdf_url)
        response.raise_for_status()

        text_content = []

        # 🧠 Try extracting text page by page
        with pdfplumber.open(io.BytesIO(response.content)) as pdf:
            for i, page in enumerate(pdf.pages, start=1):
                print(f"🔍 Processing page {i}/{len(pdf.pages)}...")
                text = page.extract_text()

                if text and text.strip():
                    # Normal text-based page
                    text_content.append(text)
                else:
                    # 🧩 If no text found → apply OCR
                    print(f"📷 Running OCR on page {i}...")
                    page_image = page.to_image(resolution=300).original
                    ocr_text = pytesseract.image_to_string(page_image)
                    text_content.append(ocr_text)

        final_text = "\n".join(text_content)
        print(f"✅ Extracted {len(final_text)} characters of text.")
        return final_text

    except Exception as e:
        print(f"[PDF Extraction Error] {e}")
        return ""

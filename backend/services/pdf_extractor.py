import requests
import pdfplumber
import io

def extract_text_from_url(pdf_url: str) -> str:
    print(f"[PDF Extraction] Extracting text from {pdf_url}")
    
    try:
        response = requests.get(pdf_url)
        response.raise_for_status()
        with pdfplumber.open(io.BytesIO(response.content)) as pdf:
            
            return "\n".join(
                page.extract_text() or "" for page in pdf.pages
            )
    except Exception as e:
        print(f"[PDF Extraction Error] {e}")
        return ""


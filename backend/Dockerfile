# 1️⃣ Base Python image
FROM python:3.11-slim

# 2️⃣ Install system dependencies for Tesseract OCR
RUN apt-get update && apt-get install -y tesseract-ocr libtesseract-dev libleptonica-dev pkg-config

# 3️⃣ Set working directory
WORKDIR /app

# 4️⃣ Copy and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 5️⃣ Copy all project files
COPY . .

# 6️⃣ Expose Render port and start the FastAPI server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "10000"]

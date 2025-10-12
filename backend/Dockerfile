FROM python:3.11-slim

# Install Tesseract and dependencies
RUN apt-get update && \
    apt-get install -y tesseract-ocr libtesseract-dev libleptonica-dev pkg-config && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Python requirements and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your app
COPY . .

# Start FastAPI
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "10000"]

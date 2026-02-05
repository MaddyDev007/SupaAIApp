# SmartClass

**SmartClass** is an AI-powered educational platform that combines a Flutter mobile application with a FastAPI backend. It automates the generation of quiz questions from PDF materials, provides intelligent chatbot assistance, and tracks student results.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Prerequisites](#prerequisites)
- [Project Structure](#project-structure)
- [Installation Guide](#installation-guide)
  - [Backend Setup](#backend-setup)
  - [Frontend Setup](#frontend-setup)
- [Running the Application](#running-the-application)
- [Environment Configuration](#environment-configuration)
- [Dependencies](#dependencies)
- [API Endpoints](#api-endpoints)
- [Development Workflow](#development-workflow)
- [Troubleshooting](#troubleshooting)

---

## Project Overview

SmartClass is a comprehensive educational management system with the following features:

- **AI-Powered Question Generation**: Automatically generate MCQ questions from PDF materials using the Cohere API
- **Intelligent Chatbot**: Answer student questions based on course materials
- **Quiz Management**: Create, store, and manage quizzes for different classes
- **Student Results Tracking**: Monitor and analyze student performance
- **Multi-Platform Support**: Available as a mobile app (Flutter) and backend API

### Architecture

- **Frontend**: Flutter application (Dart) for mobile platforms (iOS, Android)
- **Backend**: FastAPI Python application for business logic and AI integration
- **Database**: Supabase (PostgreSQL) for data storage and authentication
- **Storage**: Supabase Storage for PDF and document management
- **AI Services**: Cohere API for LLM-based question generation and Google Generative AI

---

## Prerequisites

Before you begin, ensure you have the following installed on your system:

### For Backend Development:
- **Python 3.8 or higher** - [Download here](https://www.python.org/downloads/)
- **pip** (Python package manager) - Comes with Python

### For Frontend Development:
- **Flutter SDK 3.8.1 or higher** - [Download here](https://flutter.dev/docs/get-started/install)
- **Dart SDK** - Comes with Flutter
- **Android Studio** (for Android development) - [Download here](https://developer.android.com/studio)
- **Xcode** (for iOS development on macOS) - Available from App Store
- **Git** - [Download here](https://git-scm.com/downloads)

### Required API Keys and Services:
- **Supabase Account** - [Create here](https://supabase.com/)
  - Supabase URL and Anon Key for authentication and storage
  - Supabase Service Role Key for backend operations
- **Cohere API Key** - [Get here](https://cohere.com/api/)
- **Google Generative AI API Key** (optional, for enhanced AI features)

---

## Project Structure

```
smartclass/
├── backend/                    # FastAPI backend
│   ├── main.py                # Main FastAPI application
│   ├── requirements.txt        # Python dependencies
│   ├── Dockerfile             # Docker configuration
│   ├── routers/               # API route handlers
│   │   ├── chatbot.py         # Chatbot endpoint
│   │   ├── question.py        # Question generation
│   │   ├── quiz.py            # Quiz management
│   │   ├── results.py         # Student results
│   │   ├── upload.py          # PDF upload and processing
│   │   └── delete.py          # Delete operations
│   └── services/              # Business logic
│       ├── cohere_api.py      # Cohere API integration
│       ├── gemini_api.py      # Google Gemini integration
│       └── pdf_extractor.py   # PDF processing
│
├── smartclass/                # Flutter frontend
│   ├── lib/                   # Dart source code
│   │   ├── main.dart          # App entry point
│   │   ├── secrets.dart       # API keys configuration
│   │   ├── models/            # Data models
│   │   ├── screens/           # UI screens
│   │   ├── services/          # API and local services
│   │   └── widgets/           # Reusable widgets
│   ├── pubspec.yaml           # Flutter dependencies
│   ├── android/               # Android-specific code
│   └── ios/                   # iOS-specific code
│
├── API.md                     # API documentation
├── document.md                # Architecture & dataflow
├── error.md                   # Known issues
└── README.md                  # This file
```

---

## Installation Guide

### Backend Setup

#### 1. Clone the Repository
```bash
git clone <repository-url>
cd smartclass
```

#### 2. Create a Python Virtual Environment
```bash
# On Windows
python -m venv venv
venv\Scripts\activate

# On macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

#### 3. Install Python Dependencies
```bash
cd backend
pip install -r requirements.txt
```

#### 4. Configure Environment Variables
Create a `.env` file in the `backend/` directory with the following variables:

```
# Supabase Configuration
SUPABASE_URL=your_supabase_url
SUPABASE_KEY=your_supabase_service_role_key

# API Keys
COHERE_API_KEY=your_cohere_api_key
GOOGLE_GENERATIVE_AI_KEY=your_google_api_key

# Backend Configuration
DEBUG=False
ALLOWED_ORIGINS=*
```

#### 5. Verify Installation
```bash
python main.py
```

You should see: `Uvicorn running on http://127.0.0.1:8000`

---

### Frontend Setup

#### 1. Navigate to Frontend Directory
```bash
cd ../smartclass
```

#### 2. Get Flutter Dependencies
```bash
flutter pub get
```

#### 3. Configure Secrets
Update `lib/secrets.dart` with your Supabase credentials:

```dart
const String supabaseUrl = 'your_supabase_url';
const String supabaseAnonKey = 'your_supabase_anon_key';
const String backendUrl = 'http://localhost:8000';  // or your backend URL
```

#### 4. Run Flutter App
```bash
# For development on Android
flutter run -d android

# For development on iOS (macOS only)
flutter run -d ios

# For web (if configured)
flutter run -d chrome
```

---

## Running the Application

### Backend (FastAPI Server)

```bash
cd backend
source venv/bin/activate  # On Windows: venv\Scripts\activate
python main.py
```

The API will be available at: `http://localhost:8000`
- API Documentation: `http://localhost:8000/docs`
- Alternative Docs: `http://localhost:8000/redoc`

### Frontend (Flutter App)

```bash
cd smartclass
flutter run
```

---

## Environment Configuration

### Backend `.env` File

Create `backend/.env` with the following template:

```bash
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your_service_role_key_here

# Cohere API
COHERE_API_KEY=your_cohere_key_here

# Google Generative AI (Optional)
GOOGLE_GENERATIVE_AI_KEY=your_google_key_here

# Application Settings
DEBUG=False
ALLOWED_ORIGINS=*,http://localhost:3000,http://localhost:8000
```

### Frontend Configuration

Update `smartclass/lib/secrets.dart`:

```dart
const String supabaseUrl = 'https://your-project.supabase.co';
const String supabaseAnonKey = 'your_anon_key_here';
const String backendUrl = 'https://your-backend-url.com'; // or localhost:8000 for local development
```

---

## Dependencies

### Backend Dependencies

| Package | Purpose |
|---------|---------|
| `fastapi` | Web framework |
| `uvicorn` | ASGI server |
| `pdfplumber` | PDF text extraction |
| `requests` | HTTP library |
| `cohere` | LLM API client |
| `google-generativeai` | Google AI API client |
| `python-dotenv` | Environment variable management |
| `supabase` | Supabase Python client |
| `opencv-python-headless` | Image processing |
| `numpy` | Numerical computing |
| `pydantic` | Data validation |
| `reportlab` | PDF generation |
| `pytesseract` | OCR for images |
| `httpx` | Async HTTP client |
| `pillow` | Image library |
| `beautifulsoup4` | HTML/XML parsing |

### Frontend Dependencies

| Package | Purpose |
|---------|---------|
| `supabase_flutter` | Supabase integration |
| `flutter` | Flutter SDK |
| `dio` | HTTP client |
| `permission_handler` | Device permissions |
| `fl_chart` | Charts and graphs |
| `intl` | Internationalization |
| `pdfx` | PDF viewing |
| `pdf` | PDF generation |
| `hive` | Local database |
| `lottie` | Animations |
| `smooth_page_indicator` | Page indicators |
| `image_picker` | Image selection |
| `url_launcher` | URL handling |
| `connectivity_plus` | Network status |
| `sign_in_with_apple` | Apple authentication |

---

## API Endpoints

### Health Check
```
GET /
Response: { "status": "ok", "message": "SmartClass Backend running" }
```

### Upload & Question Generation
```
POST /upload/
Body: {
  "pdf_url": "https://...",
  "metadata": {
    "class_id": "...",
    "material_id": "...",
    "subject": "...",
    "teacher_id": "..."
  }
}
```

### Quiz Management
```
POST /quiz/store
Body: {
  "teacher_id": "...",
  "class_id": "...",
  "subject": "...",
  "questions": [...],
  "material_id": "...",
  "pdf_url": "...",
  "text_preview": "..."
}
```

### Chatbot
```
POST /chatbot/
Body: {
  "question": "...",
  "class_id": "...",
  "student_id": "..."
}
```

### Results
```
GET /results/getResult
Params: student_id, result_id
```

For detailed API documentation, see [API.md](API.md)

---

## Development Workflow

### 1. Creating a Feature Branch
```bash
git checkout -b feature/feature-name
```

### 2. Making Changes

**Backend Changes:**
```bash
cd backend
# Make changes to .py files
python main.py  # Test locally
```

**Frontend Changes:**
```bash
cd smartclass
# Make changes to .dart files
flutter run  # Test on device/emulator
```

### 3. Committing Changes
```bash
git add .
git commit -m "feat: description of changes"
git push origin feature/feature-name
```

### 4. Creating a Pull Request
Push your branch and create a PR on GitHub/GitLab with a clear description of your changes.

---

## Troubleshooting

### Backend Issues

#### Issue: `ModuleNotFoundError: No module named 'fastapi'`
**Solution**: Ensure virtual environment is activated and dependencies are installed
```bash
source venv/bin/activate
pip install -r requirements.txt
```

#### Issue: `SUPABASE_URL not found in environment`
**Solution**: Create `.env` file in `backend/` directory with required environment variables

#### Issue: Port 8000 already in use
**Solution**: Change the port in `main.py` or kill the process using port 8000
```bash
# On Windows
netstat -ano | findstr :8000
taskkill /PID <PID> /F

# On macOS/Linux
lsof -i :8000
kill -9 <PID>
```

### Frontend Issues

#### Issue: `Flutter command not found`
**Solution**: Add Flutter to your system PATH or reinstall Flutter SDK

#### Issue: `No connected devices`
**Solution**: 
- Connect an Android device via USB or start an Android emulator
- Or connect an iOS device and start Xcode

#### Issue: `Pub get` fails
**Solution**: Clear cache and retry
```bash
flutter clean
flutter pub get
```

#### Issue: `Build fails on first run`
**Solution**: Run these commands in sequence
```bash
flutter clean
flutter pub get
flutter run
```

### General Issues

#### Issue: CORS errors when calling backend from frontend
**Solution**: Ensure `ALLOWED_ORIGINS` in backend `.env` includes your frontend URL

#### Issue: Authentication fails
**Solution**: 
- Verify Supabase credentials in both backend and frontend
- Check that Supabase project is active and accessible
- Ensure service role key has appropriate permissions

---

## Deployment

### Backend Deployment (Render)

The backend is configured for deployment on Render. Use the provided `Dockerfile` and `render.yaml`:

```bash
# Push to GitHub and connect to Render
# Render will automatically build and deploy
```

### Frontend Deployment

For production builds:

```bash
# Android APK
flutter build apk --release

# iOS App
flutter build ios --release

# Web
flutter build web --release
```

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

---

## Support

For issues, questions, or suggestions, please:
- Check [error.md](error.md) for known issues
- Review [API.md](API.md) for API documentation
- Check [document.md](document.md) for architecture details

---

## License

[Add your license information here]

---

## Contact

[Add your contact information or team details here]

---

**Last Updated**: January 30, 2026

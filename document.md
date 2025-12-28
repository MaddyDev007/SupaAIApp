# SmartClass — Architecture & Dataflow Documentation

This document provides a high-level overview of the project architecture (frontend & backend), the REST API endpoints, data flows, and the per-screen data requirements / expectations. It is intended to help developers understand how data moves through the system and what each screen needs/produces.

---

## Quick summary 🔧
- **Frontend**: Flutter app (`smartclass/`) using `supabase_flutter` for auth and storage; screens include teacher and student dashboards, upload, quizzes, chatbot, results, etc.
- **Backend**: FastAPI app (`backend/`) with routers: `/upload`, `/quiz`, `/question`, `/chatbot`, `/results`. Uses Cohere API to generate questions and Supabase service role for storage/DB writes.
- **Storage & DB**: Supabase (storage buckets: `lessons`,`questions` and tables: `materials`, `quizzes`, `questions`, `results`, etc.)

---

## Architecture Overview 🏗️

1. Mobile app (Flutter)
   - Handles auth (Supabase), file uploads (Supabase storage), local UI state.
   - Calls backend endpoints for heavy AI generation tasks (MCQs, exams, PDF parsing).
2. Backend (FastAPI)
   - Receives `pdf_url` + `metadata` from frontend `/upload`; downloads PDF; extracts text; calls Cohere to generate MCQs; returns questions + preview.
   - `/quiz/store` persists generated quiz metadata into Supabase `quizzes` table.
   - `/question/generate-exam` generates exam PDF, uploads to Supabase `questions` bucket and records DB metadata.
   - `/chatbot` accepts `question` + `class_id`, fetches relevant documents (class-scoped `quizzes` text_preview), calls Cohere chat and returns answer.
   - `/results/getResult` scrapes third-party site and returns parsed student result.
3. Third-party services
   - **Cohere** for LLM question generation and chat.
   - **Supabase** for auth, storage, and DB.

---

## Main API endpoints (backend) 🔌

- POST /upload/
  - Request: JSON
    {
      "pdf_url": "https://...",
      "metadata": {"class_id": "<id>", "material_id": "<id>", "subject": "...", "teacher_id": "..."}
    }
  - Response: {"status":"success","questions": [...], "text_preview": "...", "metadata": {...}}
  - Behavior: Backend downloads PDF, extracts text (OCR fallback), calls Cohere `generate_questions(text)` and returns result.

- POST /quiz/store
  - Request: JSON
    {
      "teacher_id":"...", "class_id":"...", "subject":"...",
      "questions": [...], "material_id":"...", "pdf_url":"...", "text_preview":"..."
    }
  - Response: {"message":"Quiz stored successfully"}
  - Behavior: Inserts into Supabase `quizzes` table.

- POST /question/generate-exam
  - Request: JSON
    {
      "pdf_url": "...",
      "metadata": {"class_id":"...","material_id":"...","subject":"...","teacher_id":"..."}
    }
  - Response: {"message":"✅ Exam generated successfully","questions": {...}, "file_url":"..."}
  - Behavior: Generates questions, creates PDF and uploads to supabase `questions` bucket, inserts metadata into `questions` table.

- POST /chatbot/
  - Request: JSON {"question":"...","class_id":"..."}
  - Response: {"answer":"..."}
  - Behavior: Fetch class-scoped `quizzes` previews from Supabase, download PDFs, extract text and pass to Cohere chat with limited chat history.

- POST /results/getResult
  - Request: JSON {"register_number":"...","dob":"DD-MM-YYYY"}
  - Response: Parsed JSON with `subjects`, `sgpa`, `name`, etc.
  - Behavior: Scrapes `https://results.tec-edu.in/` and parses tables.

---

## Per-screen data requirements & flows (condensed) 📱

### Teacher screens
- **Teacher Dashboard (`TeacherDashboard`)**
  - Requires: `cls` map with `id` and `name` (class context). Passes class context into other screens.
  - Behavior: Filtered tiles depend on navigation selection.

- **Upload & Generate (`UploadMaterialPage`)**
  - Requires: `classId` (String), selected PDF file, `subject` text.
  - Flow:
    1. Upload file to Supabase `lessons` bucket under `materials/<classId>/`.
    2. Insert `materials` row: fields: `title`, `file_url`, `subject`, `class_id`, `uploaded_by`, `created_at`.
    3. User may trigger `generateQuiz()` → POST `/upload/` to backend with `pdf_url` + `metadata`.
    4. Backend returns `questions` & `text_preview`.
    5. Frontend POST `/quiz/store` with collected payload to persist quiz in `quizzes` table.
    6. Exam generation triggers POST `/question/generate-exam` and marks UI on success.

- **View Materials (`ViewMaterialsTeacherPage`)**
  - Requires: `classId`
  - Behavior: Lists `materials` rows for class; supports delete (storage and DB cleanup) and delete of associated question PDFs.

- **View QN Bank / Results**
  - Typical behavior: list from Supabase tables (`questions`, `results`) scoped by class or teacher where relevant.

### Student screens
- **Quiz List (`QuizListPage`)**
  - Requires: `classId`
  - Flow: Query `quizzes` table `.eq('class_id', classId)` and show quizzes; query `results` to determine attempt status per quiz for current user.

- **Quiz Page (`QuizPage`)**
  - Requires: `quizId` & `classId` (to show context)
  - Flow: Student attempts quiz; results inserted into `results` table (student_id, quiz_id, score, etc.).

- **Chatbot (`ChatbotPage`)**
  - Requires: `classId` (String) - sent to backend as `class_id` so chatbot fetches class-scoped documents.
  - Flow: Sends question to backend `/chatbot/`; receives an `answer` text.

- **Semester Result (`SemResultPage`)**
  - Inputs: `register_number`, `dob` → POST to backend `/results/getResult`; parse and show subjects & SGPA.

---

## Data model (observed important fields) 🧾
- `materials`: {id, title, file_url, subject, class_id, uploaded_by, created_at}
- `quizzes`: {id, created_by (teacher), class_id, subject, questions (json), material_id, pdf_url, text_preview}
- `questions` (exam PDFs): {id, subject, file_url, teacher_id, material_id, class_id, created_at}
- `results`: {id, quiz_id, student_id, score, created_at}
- Supabase `profiles` used for user profile; auth via Supabase.

---

## Themes & UI notes 🎨
- App uses dark/ light theming via `Theme.of(context)` everywhere; components use `cardColor`, `primaryColor`, `scaffoldBackgroundColor` and `textTheme` for consistent styling.
- Navigation and UI animations are implemented consistently with slide transitions and animated progress indicators.

---

## Operational & Security notes (quick wins) ⚠️
- Centralize backend base URL and secrets for environment switching.
- Remove hard-coded `supabaseAnonKey` from `secrets.dart` and load from secure environment or native platform secrets.
- Backend endpoints currently accept unauthenticated requests (no API key or auth check). Consider adding auth or restricting endpoints by network or API key if needed (especially `/quiz/store`, `/upload`).
- Add timeouts on backend external requests and consider concurrency limits/rate limiting for Cohere usage.

---

## Suggestions for documentation owners 📚
- Add an `API.md` listing endpoints with sample requests and responses (use examples from this doc).
- Add environment setup notes (where to put Supabase keys, Cohere key, render/Heroku/host URL) and CI/CD notes.
- Add sequence diagrams for: (a) upload + generate quiz flow, (b) chatbot flow, and (c) exam generation.

---

If you want, I can:
- Produce a `API.md` with example payloads and sample success/error responses.
- Make a prioritized TODO list derived from `error.md` (for fixes and security hardening).


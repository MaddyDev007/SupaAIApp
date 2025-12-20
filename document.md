# SmartClass — Project Documentation 📚

> Concise technical documentation summarising architecture, backend endpoints, services, Supabase schema, storage buckets, data flows, and per‑page requirements for the Flutter app.

---

## Table of Contents
- Project overview
- High-level architecture
- Environment & secrets
- Backend: routers & endpoints (request/response + side effects)
- Services (PDF extraction, Cohere integration, chatbot)
- Supabase schema & storage buckets (inferred)
- Data flow (key flows)
- Per-page documentation (UI pages, required inputs, data used & produced)
- Notes, warnings and recommended improvements

---

## 1) Project overview
SmartClass is a Flutter mobile app (frontend) with a FastAPI backend. The app uses Supabase for authentication, DB, and file storage; backend uses Cohere for question/exam generation and pdfplumber/pytesseract for PDF extraction/ocr. The app supports:
- Teacher upload of PDF materials
- Automatic MCQ quiz generation from materials
- Automatic exam (question paper) generation PDF
- Students can view materials, take quizzes, and see results
- An AI chatbot that answers user questions using uploaded materials
- External result scraping for semester results

---

## 2) High-level architecture 🔧
- Frontend: Flutter app located in `smartclass/` (lib/screens/...) 
- Backend: FastAPI app in `backend/` with routers under `backend/routers` and services in `backend/services`
- Database & Auth & Storage: Supabase
- LLMs & generation: Cohere API (via `COHERE_API_KEY`)
- OCR: pytesseract for image-based PDF pages

Flow (summary):
1. Teacher uploads PDF -> Supabase `lessons` bucket -> `materials` row
2. Frontend calls backend `/upload/` to extract text & generate MCQs
3. Frontend calls backend `/quiz/store` to save quiz to `quizzes` table
4. Teacher may generate exam via `/question/generate-exam` → PDF uploaded to `questions` bucket and `questions` table row created
5. Students view quizzes, take them (answers saved to `results` table)
6. Users ask questions to chatbot which queries Supabase previews + full PDFs and calls Cohere

---

## 3) Environment & Secrets
- `.env` keys used by backend: 
  - `COHERE_API_KEY` — Cohere API key
  - `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` — Supabase service role (used for storage & DB operations server-side)
- Frontend uses Supabase anon key + URL (in `lib/secrets.dart`)

**Security note:** Service Role key must be kept server-side only.

---

## 4) Backend endpoints (routers)
All paths are prefixed in `main.py`:
- `/upload` - Upload router
- `/quiz` - Quiz router (`/quiz/store`)
- `/question` - Question router (`/question/generate-exam`)
- `/chatbot` - Chatbot router
- `/results` - Results scraping router (`/results/getResult`)

Detailed per-endpoint:

### POST /upload/ (backend/routers/upload.py)
- Purpose: Given a public `pdf_url`, extract text, save a text preview, and generate MCQs.
- Request body (JSON):
  - `pdf_url` (string, starts with http)
  - `metadata` (object — arbitrary meta passed through)
- Behavior:
  1. Validates URL
  2. Extracts full text via `extract_text_from_url`
  3. Creates `text_preview` (first ~3000 chars)
  4. Calls `generate_questions(text)` (Cohere-based) to produce MCQs
- Response (JSON):
  - `status`: "success"
  - `questions`: list of MCQs (see MCQ schema below)
  - `text_preview`: string
  - `metadata`: echo
- Errors: 400/500 with descriptive details

### POST /quiz/store (backend/routers/quiz.py)
- Purpose: Persist a quiz to Supabase `quizzes` table
- Request body (JSON): must include keys: `teacher_id`, `department`, `year`, `subject`, `questions`, `pdf_url`, `text_preview`
- Behavior: Inserts record to `quizzes` table
- Response: `{"message": "Quiz stored successfully"}` or error

### POST /question/generate-exam (backend/routers/question.py)
- Purpose: Generate an exam PDF from a teacher PDF and upload it to Supabase `questions` bucket and `questions` table
- Request body (JSON):
  - `pdf_url` (string) and `metadata` (object with fields such as `subject`, `department`, `year`, `teacher_id`, `material_id`)
- Behavior:
  - Downloads `pdf_url`, extracts text, calls `generate_exam_questions(text)`
  - Builds a PDF in memory (using reportlab) with 2-mark and 13-mark sections
  - Uploads PDF to `questions` bucket and inserts metadata row to `questions` table
- Response: {
  - `message`: "✅ Exam generated successfully",
  - `questions`: {"2_mark": [...], "13_mark": [...]},
  - `file_url`: public URL
}

### POST /chatbot/ (backend/routers/chatbot.py)
- Purpose: Ask AI chatbot a question using contextual documents
- Request body (JSON): `{ "question": "..." }`
- Behavior: calls `ask_chatbot(question)` which:
  - Fetches previews from `quizzes` table (text_preview), scores matching PDFs by keyword overlap
  - Downloads top-k PDFs, extracts text, calls Cohere with chat history and documents
  - Maintains an in-memory `chat_history`
- Response: `{ "answer": "..." }`

### POST /results/getResult (backend/routers/results.py)
- Purpose: Scrapes results from an external site `https://results.tec-edu.in/`
- Request body (JSON): `{ "register_number": "...", "dob": "DD-MM-YYYY" }`
- Behavior: Uses httpx and BeautifulSoup to post the form and parse student info table and subject table. Computes SGPA when possible.
- Response: JSON with student fields and `subjects` list (see implementation for exact keys)

---

## 5) Services (key functions)
### PDF extraction (backend/services/pdf_extractor.py)
- Function: `extract_text_from_url(pdf_url) -> str`
- Approach: Download PDF, iterate pages using `pdfplumber`; if page.extract_text() empty, uses `pytesseract.image_to_string` on page images.
- Returns full concatenated text. Returns empty string on error.
- Used by: `/upload` flow and `/question/generate-exam`

### Cohere integration (backend/services/cohere_api.py)
- Key functions:
  - `generate_questions(text)` → Sends prompt to Cohere to return exactly 10 MCQs (JSON array). Expected MCQ item format: {
      "question": "...",
      "options": ["A","B","C","D"],
      "answer": 0 // index of correct option
    }
  - `generate_all_questions(full_text)` → splits into chunks and calls `generate_questions` per chunk
  - `generate_exam_questions(text)` → returns `{"2_mark": [...], "13_mark": [...]}` based on single prompt
  - `fetch_relevant_documents(question, top_k=2)` → finds top-k documents from `quizzes` table by keyword overlap in `text_preview`, downloads PDFs, extracts text
  - `ask_chatbot(question)` → maintains global `chat_history`, calls Cohere chat with documents & history
- Error handling: converts malformed Cohere responses into JSON or raises HTTPException

---

## 6) Supabase schema & storage (inferred) 🗄️
**Tables** (fields found in code):

- `profiles`:
  - `id` (UUID), `email`, `name`, `role` ("teacher" | "student"), `department`, `year`, `reg_no`, `subjects` ?
- `materials`:
  - `id`, `title`, `file_url`, `subject`, `department`, `year`, `teacher_id`, `created_at`
- `quizzes`:
  - `id`, `created_by` (teacher id), `department`, `year`, `subject`, `questions` (JSON or text), `pdf_url`, `text_preview`
- `questions` (exam PDFs table):
  - `id`, `subject`, `department`, `year`, `teacher_id`, `material_id`, `file_url`, `created_at`
- `results`:
  - `id`, `quiz_id`, `student_id`, `student_name`, `score`, `subject`, `department`, `year`, `answers` (json), `created_at`

**Storage buckets**:
- `lessons` — teacher uploaded PDFs
- `questions` — generated exam PDFs

---

## 7) Key data flows (step-by-step) 🔁

### A) Upload Material + Generate Quiz
1. Teacher chooses PDF in app and uploads to Supabase `lessons` bucket (via `SupabaseUploadService` in Flutter). App inserts a `materials` record with `file_url`.
2. After upload, the frontend sends POST `/upload/` with `{ "pdf_url": uploadedFileUrl, "metadata": {...}}`.
3. Backend: extracts text (pdf_extractor), constructs `text_preview`, calls Cohere to generate MCQs (10 items), returns `{ questions, text_preview, metadata }`.
4. Frontend then sends POST `/quiz/store` with {teacher_id, department, year, subject, questions, pdf_url, text_preview} to persist the quiz in `quizzes`.

### B) Generate Exam Paper
1. After uploading material, frontend calls `POST /question/generate-exam` with `pdf_url` and `metadata`.
2. Backend extracts text → `generate_exam_questions` (2_mark, 13_mark) → builds a PDF → uploads to `questions` bucket → inserts row to `questions` table with `file_url` and metadata → returns `file_url`.

### C) Student taking quiz
1. App lists available quizzes from `quizzes` table filtered by `department` and `year`.
2. Student opens quiz: app fetches `questions` field (JSON) and timers start.
3. On submit: app calculates score locally then inserts a `results` row with `quiz_id`, `student_id`, `student_name`, `score`, `answers` (json), `subject`, department/year.

### D) Chatbot Q&A
1. User types question in the chatbot UI.
2. Frontend posts to `/chatbot/` with `{ "question": "..." }`.
3. Backend: selects relevant `quizzes` via keyword overlap on `text_preview`, downloads top PDFs, extracts texts, calls Cohere with documents + `chat_history` and returns `answer`.

### E) Results scraping
1. Student provides reg number & DOB in app; frontend posts to `/results/getResult`.
2. Backend posts form to external website, parses HTML tables to extract student info and subjects, computes SGPA, returns structured JSON.

---

## 8) Per-page / Per-screen documentation (what data each page needs) 🧭
Below are key screens and their data requirements, validation and backend/supabase interactions.

### Signup (`/signup`) — `SignupPage`
- Inputs: `name`, `register number`, `email`, `password`, `confirm password`, `department`, `year`
- Actions: calls `Supabase.auth.signUp` then inserts row to `profiles` with `id`, `name`, `email`, `role` (teacher if email ends with `@myclg.edu`), `department`, `year`, `reg_no`
- Errors: email validity, password length, signup failures

### Login (`/login`) — `LoginPage`
- Inputs: `email`, `password`
- Actions: `supabase.auth.signInWithPassword`, fetch `profiles` row (by user id), writes offline Hive profile and redirects to teacher/student dashboard

### Upload Material (`/upload`) — `UploadMaterialPage`
- Inputs/UI: pick PDF file, select Department, select Year, Subject text
- Upload steps:
  - Upload binary to Supabase `lessons` bucket (folder: `materials/{dept}/{year}`) using `SupabaseUploadService`
  - Insert into `materials` table with `title`, `file_url`, `subject`, `department`, `year`, `teacher_id` and set `uploadedMaterialId` and `uploadedFileUrl`
  - `Generate Quiz` button does: POST `/upload/` with `pdf_url` and `metadata` (teacher id etc.) → receives `questions` & `text_preview` → POST `/quiz/store`
  - `Generate Exam` button does: POST `/question/generate-exam` with `pdf_url` & metadata → receives `file_url` for generated exam pdf
- Required data for endpoints: `pdf_url` (public), `metadata` with `teacher_id`, `department`, `year`, `subject`, `material_id`

### View Materials (student) — `ViewMaterialsPage`
- Reads `materials` table filtered by `department` & `year` and shows `subject`, `file_url`.
- Actions: open file URL (in-app viewer), download, open externally

### View Question PDFs (student) — `ViewMaterialsQNPage`
- Reads `questions` table filtered by `department` & `year` and shows generated exam PDFs

### Quiz Page — `QuizPage` (route `/quiz`)
- Parameters (route args): `quizId`, `department`, `year`
- Data required: fetch from `quizzes` table `id, subject, questions`
- Local UI: questions as list of objects (MCQs with `options`, `answer` index). The app expects `questions` either as JSON string or list.
- On submit: compute score, write to `results` table: `quiz_id`, `student_id`, `student_name`, `score`, `subject`, `department`, `year`, `answers` (json)

### Teacher View Materials — `ViewMaterialsTeacherPage`
- Data: `materials` where `teacher_id = current user`.
- Actions: delete material → also deletes related `questions` table rows and files in `questions` bucket; deletes file from `lessons` bucket.

### Teacher Results — `ResultPage`
- Data: fetch `results` joined with `profiles` and `quizzes`, filters by `quizzes.created_by` = teacher id. Displays student name, score, subject and profile info.

### Chatbot — `ChatbotPage`
- Input: question text
- Action: POST `/chatbot/` with `{question}`; displays `answer` returned
- Chat history is stored in global `chatHistory` list client-side and backend maintains its own `chat_history` (server memory)

### Semester Result Lookup — `SemResultPage`
- Inputs: `register number`, `dob` (DD-MM-YYYY)
- Action: POST `/results/getResult` with `{ register_number, dob }`, receives JSON with student info and `subjects` list and `sgpa`

---

## 9) Data models & expected formats
**MCQ object (expected)**
```json
{
  "question": "...",
  "options": ["optA", "optB", "optC", "optD"],
  "answer": 0
}
```
- `questions` field (stored in `quizzes`) can be either a JSON-serializable list or a stringified JSON. Frontend handles both.

**Quiz store payload (frontend → /quiz/store)**
```json
{
  "teacher_id": "...",
  "department": "CSE",
  "year": "2nd year",
  "subject": "Data Structures",
  "questions": [ /* list of MCQ objects */ ],
  "pdf_url": "https://...",
  "text_preview": "..."
}
```

**Exam generate payload (frontend → /question/generate-exam)**
```json
{
  "pdf_url": "https://...",
  "metadata": { "subject": "...", "department": "...", "year": "...", "teacher_id": "...", "material_id": "..." }
}
```

**Chatbot payload**: `{ "question": "..." }` → response `{ "answer": "..." }`

**Results scrape payload**: `{ "register_number": "...", "dob": "DD-MM-YYYY" }` → response includes `subjects` list and `sgpa`

---

## 10) Notes, warnings & suggested improvements ⚠️
- Cohere responses can be malformed — backend attempts to recover JSON but add robust checks and retries.
- Service Role key usage: ensure the server-only keys are not accidentally embedded in frontend builds.
- Timeouts: long PDF downloads or Cohere calls should have careful timeout config and user feedback (already present in places). Consider background jobs for heavy tasks.
- Scalability: `fetch_relevant_documents` does naive keyword overlap on `text_preview` — replace with vector search (Supabase/pgvector or OpenAI embeddings) for better retrieval quality and performance.
- DB schema enforcement: Ensure columns types: `questions` stored as JSONB makes operations easier.
- Chat history: backend keeps `chat_history` in global memory — this is ephemeral and should be scoped per-user session or persisted cautiously.

---

## 11) Quick API reference (summary table)
- POST `/upload/` — generate quiz & text_preview from `pdf_url`
- POST `/quiz/store` — store a quiz (required fields: `teacher_id`, `department`, `year`, `subject`, `questions`, `pdf_url`, `text_preview`)
- POST `/question/generate-exam` — generate & upload exam PDF, returns `file_url`
- POST `/chatbot/` — ask chatbot (`{question}`) → `{answer}`
- POST `/results/getResult` — scrape external results site (`{register_number, dob}`)

---

If you want, I can:
- Export a more formal ER diagram and a sample Supabase SQL migration for these inferred tables ✅
- Add example request/response JSON snippets for each endpoint in a separate `api_examples.md` file ✅

Would you like me to add either of those next? 🔧

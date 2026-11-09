# API — SmartClass Backend

This document summarizes the backend endpoints and shows example request and response payloads to make integration and testing straightforward.

Base URL (example): `https://supaaiapp-1.onrender.com`

---

## Health
GET /
- Description: Simple health endpoint.
- Response (200):

```json
{ "status": "ok", "message": "SmartClass Backend running" }
```

---

## 1) Upload Material and Generate Questions
POST /upload/
- Description: Accepts a PDF URL and metadata, extracts text, generates MCQs and a preview.
- Headers: `Content-Type: application/json`

Request body example:

```json
{
  "pdf_url": "https://storage.example.com/materials/classA/lesson1.pdf",
  "metadata": {
    "class_id": "classA",
    "material_id": "mat-123",
    "subject": "Thermodynamics",
    "teacher_id": "teacher-456"
  }
}
```

Success response (200):

```json
{
  "status": "success",
  "questions": [
    {
      "question": "What is...",
      "options": ["A","B","C","D"],
      "answer": 1
    },
    ...
  ],
  "text_preview": "First ~3000 characters of extracted text...",
  "metadata": { "class_id": "classA", "material_id": "mat-123", ... }
}
```

Errors:
- 400 Bad Request: missing metadata keys or invalid `pdf_url` (e.g., not starting with `http`).
- 500 Server Error: text extraction or question generation failed.

Notes:
- `metadata` must include `class_id`, `material_id`, `subject`, and `teacher_id`.
- Long PDFs may be chunked for question generation.

---

## 2) Store Quiz
POST /quiz/store
- Description: Stores a generated quiz in Supabase.
- Headers: `Content-Type: application/json`

Request body example:

```json
{
  "teacher_id": "teacher-456",
  "class_id": "classA",
  "subject": "Thermodynamics",
  "questions": [ /* array of question objects from /upload */ ],
  "material_id": "mat-123",
  "pdf_url": "https://storage.example.com/materials/classA/lesson1.pdf",
  "text_preview": "First ~3000 characters..."
}
```

Success response (200):

```json
{ "message": "Quiz stored successfully" }
```

Errors:
- 400: Missing required fields (see required list).

Notes:
- Backend expects `class_id` to be provided and will store `created_by` using `teacher_id`.

---

## 3) Chatbot (Persistent, class-scoped conversation)

All chatbot endpoints require:
- `Authorization: Bearer <Supabase access token>`
- `Content-Type: application/json` for POST requests.

The backend keeps one persistent conversation session per authenticated user + class. Reopening the chatbot retrieves the same session and its saved messages. Session IDs are not interchangeable between users or classes.

### Open or retrieve the current session
POST /chatbot/session

Request:
```json
{ "class_id": "<class UUID>" }
```

Response (200):
```json
{ "session_id": "<session UUID>" }
```

The caller must own the class or be a student member of it.

### Load saved messages
GET /chatbot/history?class_id=<class UUID>&session_id=<session UUID>

Response (200):
```json
{
  "messages": [
    { "role": "user", "msg": "Explain entropy." },
    { "role": "bot", "msg": "Entropy is ..." }
  ]
}
```

Only the authenticated user's session for that class can be read. The response includes up to the latest 100 messages.

### Stream a new answer
POST /chatbot/stream

Request:
```json
{
  "question": "Explain entropy in simple terms.",
  "class_id": "<class UUID>",
  "session_id": "<session UUID>"
}
```

Response: streamed plain-text assistant content. The user prompt is saved before generation, and the assistant answer is saved after the stream completes. Gemini receives the latest 20 saved messages as conversation context.

### Clear saved messages
DELETE /chatbot/history?class_id=<class UUID>&session_id=<session UUID>

Response (200):
```json
{ "status": "cleared" }
```

This deletes the messages in the current session but keeps the session itself. The next prompt starts a fresh conversation in that same user/class session.

Errors:
- 401: Missing or invalid Supabase access token.
- 403: Caller does not own or belong to the requested class.
- 404: Session does not belong to the authenticated user and requested class.
- 400/422: Missing or invalid request fields.
- 500: Session persistence or chatbot generation failure.

Notes:
- Chat messages are stored in private database tables with RLS enabled. The Flutter app accesses them only through these authenticated backend endpoints.
- There is one active persistent session per user/class pair. Separate users and separate classes never share conversation history.

---

## 4) Generate Exam (Question Paper)
POST /question/generate-exam
- Description: Generates a formatted exam PDF and stores it in Supabase storage and the `questions` table.
- Headers: `Content-Type: application/json`

Request body example:

```json
{
  "pdf_url": "https://storage.example.com/materials/classA/lesson1.pdf",
  "metadata": {
    "class_id": "classA",
    "material_id": "mat-123",
    "subject": "Thermodynamics",
    "teacher_id": "teacher-456"
  }
}
```

Success response (200):

```json
{
  "message": "✅ Exam generated successfully",
  "questions": {
    "2_mark": ["Q1","Q2","Q3","Q4","Q5"],
    "13_mark": ["Q1","Q2"]
  },
  "file_url": "https://ifacstaqz...supabase.co/storage/v1/object/public/questions/exam_abc.pdf"
}
```

Errors:
- 400: Missing required metadata or PDF fetch/extraction failed.
- 500: Exam generation or storage failed.

Notes:
- The endpoint downloads the PDF, extracts text, calls the model, generates a PDF, uploads it to the `questions` bucket, and stores metadata in `questions` table (including `class_id`).
- Confirm `get_public_url` SDK return type (string vs object) when interacting with Supabase SDK.

---

## 5) Get Student Result (Screen-scrape remote site)
POST /results/getResult
- Description: Proxy to remote results site; returns parsed student info and subject table.
- Headers: `Content-Type: application/json`

Request body example:

```json
{ "register_number": "123456", "dob": "01-01-2000" }
```

Success response (200):

```json
{
  "status": "success",
  "register_number": "123456",
  "name": "John Doe",
  "degree": "B.Tech",
  "exam_month": "May 2025",
  "sgpa": 8.21,
  "subjects": [
    {
      "semester": "1",
      "course_name": "Maths",
      "code": "MTH101",
      "credits": "3",
      "grade": "A",
      "grade_point": "9.0",
      "result": "Pass"
    },
    ...
  ]
}
```

Errors:
- 404: Result or subjects not found.
- 500: Parsing or network error while scraping.

Notes:
- The API scrapes an external website and extracts two tables. The `sgpa` calculation handles parse errors and will return `"Not Available"` if it cannot compute.

---

## Error semantics & general notes
- All endpoints return HTTP status codes appropriate to the error: 4xx for client errors (bad input, missing fields) and 5xx for server errors.
- The backend often raises `HTTPException` with a `detail` string — clients should handle `detail` in error responses.
- Timeouts: Not all external HTTP calls currently specify timeouts; consider adding timeouts to external downloads.
- Auth: Backend routes are currently unauthenticated; ensure Supabase-fronted flows protect user-specific actions on the client side.

---

## Integration tips
- Centralize backend base URL in frontend config to easily switch between local dev and production.
- Validate that the Supabase storage SDK returns a string URL for `get_public_url` (some SDKs return an object). Normalize before storing in DB.

---

If you'd like, I can add a `curl` or Postman collection for these endpoints next.
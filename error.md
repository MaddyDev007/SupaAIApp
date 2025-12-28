# Error Report — SmartClass

This file lists discovered issues (logic, data-flow, security, UX, and reliability) across the repository. It documents where the issue exists, a short description, severity, and notes. I did not change any code; this is a collected audit.

---

## 1) Hard-coded production secrets and URLs (Security / Maintainability) — HIGH
- Files:
  - `smartclass/lib/secrets.dart`
  - `smartclass/lib/screens/teacher_screen/upload_material_page.dart` (https URLs)
  - `smartclass/lib/screens/common_screen/chatbot_page.dart` (https URL)
  - `smartclass/lib/screens/student_screen/sem_result.dart` (https URL)
- Description: Supabase credentials (`supabaseAnonKey`) are hard-coded in `secrets.dart`. Backend URL `https://supaaiapp-1.onrender.com` is repeated across the frontend. Storing secrets/URLs this way risks leakage and complicates environment switching.
- Impact: Exposes credentials publicly; makes it hard to run tests locally and rotate keys.

---

## 2) Global in-memory chat history (Data isolation / multi-tenant bug) — HIGH
- Files:
  - `backend/services/cohere_api.py` (`chat_history` global)
  - `smartclass/lib/screens/common_screen/chatbot_page.dart` (`chatHistory` global in client)
- Description: Backend keeps a single global `chat_history` for all classes and users. Although `ask_chatbot` receives `class_id` and fetches class-scoped documents, the chat history is shared across all classes and sessions. This can leak context across classes and users.
- Impact: Cross-tenant data leakage; inconsistent or incorrect chatbot responses.

---

## 3) Navigation 'People' destination not reflected in selected state (UX bug, minor) — MEDIUM
- File: `smartclass/lib/screens/teacher_screen/teacher_dashboard.dart`
- Location: `_onNavTapped(int index)` and `NavigationBar` destinations
- Description: When the last destination (index 4, People) is tapped, code pushes `ListStudentPage` and returns early without updating `_selectedIndex`. This means the navigation bar will not show the People destination as selected. Other destinations update `_selectedIndex` normally.
- Impact: Slight UX inconsistency that may confuse users.

---

## 4) Backend external requests without timeouts (Reliability) — MEDIUM
- Files:
  - `backend/services/pdf_extractor.py` (requests.get without timeout)
  - `backend/routers/question.py` (requests.get(req.pdf_url) -- no timeout)
- Description: HTTP requests (PDF download) are performed without timeouts; network stalls could hang worker threads.
- Impact: Degraded responsiveness, possible worker exhaustion under slow networks.

---

## 5) Cohere / API key usage without validation (Robustness) — MEDIUM
- File: `backend/services/cohere_api.py`
- Description: `COHERE_KEY` is read from env and `co = Client(COHERE_KEY)` is created without verifying presence of key. If missing or invalid, runtime errors may occur.
- Impact: Startup/runtime errors; unclear errors returned to API clients.

---

## 6) Potential mismatch for `get_public_url` return value (Supabase storage API change) — LOW
- File: `backend/routers/question.py`
- Line: `file_url = bucket.get_public_url(file_name)`
- Description: SDKs vary in return types; some versions return an object/dict like `{ 'publicURL': '...' }`. The code treats `file_url` as a string. Confirm the SDK version and actual return type.
- Impact: `file_url` may not be usable as expected, leading to invalid URLs stored in DB.

---

## 7) Insufficient validation of payload contents at endpoints — LOW
- Files:
  - `backend/routers/quiz.py` (checks for presence of keys only; does not validate types or non-empty `questions`)
  - `backend/routers/upload.py` (assumes `metadata` keys exist; checks presence, good; but `pdf_url` validity check is minimal `startswith("http")`)
- Description: Inputs are checked for presence, but not types/structure. For example, `questions` could be present but invalid or empty.
- Impact: Invalid data stored in DB; downstream failures.

---

## 8) Use of blocking or synchronous Supabase client inside async context (Potential performance issue) — LOW
- Files: `backend/services/cohere_api.py` (calls `.execute()` synchronously; may be blocking depending on SDK)
- Description: Some supabase operations are synchronous and may block the event loop. Consider async/safe client or running in thread for heavy ops.
- Impact: Reduced throughput under load.

---

## 9) Repetition of backend URL across frontend (Maintainability) — LOW
- Files: various (see item #1)
- Description: Multiple files have literal `https://supaaiapp-1.onrender.com/` occurrences (upload, quiz, chatbot, question, results). Should centralize.
- Impact: Error-prone; harder to switch environments.

---

## 10) Missing robust error logging policy & tracing (Observability) — INFO
- Files: multiple (backend printed errors; generic HTTPExceptions)
- Description: Exceptions are caught and generic HTTP 500 returned; internal logs printed with print(). Consider structured logging and request IDs.
- Impact: Harder to debug production issues.

---

If you want, I can now produce a prioritized actionable list or create `document.md` describing architecture, API surface, per-screen data requirements, and data flows (frontend ↔ backend ↔ Supabase). Let me know if you want add more detail to any error entry.
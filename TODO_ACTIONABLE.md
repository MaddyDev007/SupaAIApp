# Actionable TODOs (PR-friendly)

This document converts the issues in `error.md` into small, testable, and reviewable tasks organized by priority. Each task includes: description, files to change, suggested implementation steps, tests/acceptance criteria, recommended PR size, and suggested commit message.

---

Priority legend
- P0: Security / Privacy / Data leakage — fix immediately (blocking)
- P1: High reliability / correctness — fix soon
- P2: UX / maintainability — medium priority
- P3: Documentation / observation / low impact

---

## P0 — Critical

### P0-1: Remove hard-coded Supabase anon key and centralize environment config
- Files:
  - `smartclass/lib/secrets.dart`
  - Any frontend files with literal backend URLs (search `https://supaaiapp-1.onrender.com`)
- Suggested changes:
  1. Replace `secrets.dart` with an environment-based loader (e.g., `.env` + `flutter_dotenv`) or use build-time config.
  2. Centralize backend base URL into `lib/config.dart` (e.g., `AppConfig.apiBaseUrl`) and replace hard-coded occurrences.
  3. Add a README section describing env variables (e.g., `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `BACKEND_URL`).
- Tests / Acceptance criteria:
  - App compiles with config loaded.
  - No secrets remain in repo (`grep` for keys and URLs).
  - README updated with local dev instructions.
- PR guidance: Small, single-responsibility PR. Suggested message: `chore(config): move secrets and backend URL to environment-driven config`.
- Est. effort: 1–2 hours.

### P0-2: Fix global in-memory chat history / ensure class-scoped or session-scoped chat memory
- Files:
  - `backend/services/cohere_api.py` (global `chat_history`)
  - `smartclass/lib/screens/common_screen/chatbot_page.dart` (global `chatHistory` - client-side)
- Suggested changes:
  1. Change backend to maintain chat history per (session-id | class_id | user_id). Use an in-memory dict keyed by `session_id` with a size cap, or persist short-term state in Supabase (table `chat_sessions`) if needed.
  2. Update API to accept optional `session_id`; generate one on the client and send it with each chat message (or scope by `class_id` + `user_id`).
  3. On client, avoid global `chatHistory` and tie messages to a `ChatSession` object stored in StatefulWidget state or local DB.
- Tests / Acceptance criteria:
  - Chat responses do not mix across different class or user sessions in manual tests.
  - Unit test for `ask_chatbot` verifying that `chat_history` data is isolated by key.
- PR guidance: Break into two PRs if large: backend change + client change. Suggest message: `fix(chatbot): scope chat history per session to prevent cross-class leakage`.
- Est. effort: 3–6 hours (may be larger depending on persistence choice).

---

## P1 — High

### P1-1: Add timeouts and error handling to external PDF HTTP requests
- Files:
  - `backend/services/pdf_extractor.py`
  - `backend/routers/question.py` (requests.get(req.pdf_url))
- Suggested changes:
  1. Add a sensible timeout (e.g., `timeout=20`) to `requests.get` calls.
  2. Catch timeout and connection errors and return 4xx/5xx with clear messages.
- Tests / Acceptance criteria:
  - Simulate slow / non-responsive endpoints in tests; code should not hang and should return an error.
- PR guidance: Small PR. Message: `fix(pdf): add timeouts and resilient error handling to PDF downloads`.
- Est. effort: 1 hour.

### P1-2: Validate presence of critical env vars (Cohere key, Supabase keys) with explicit errors
- Files:
  - `backend/services/cohere_api.py`
  - `backend/routers/quiz.py` (supabase client init)
- Suggested changes:
  1. On startup, assert/raise a descriptive error if `COHERE_API_KEY` or `SUPABASE_SERVICE_ROLE_KEY` are missing.
  2. Add healthcheck endpoint `/health` or improve root to indicate missing configs.
- Tests / Acceptance criteria:
  - Running container without required env vars should fail fast with a readable message.
- PR guidance: Small PR. Message: `chore(env): validate critical environment variables at startup`.
- Est. effort: 1 hour.

### P1-3: Improve input validation on backend endpoints
- Files:
  - `backend/routers/quiz.py`, `backend/routers/upload.py`, `backend/routers/question.py`
- Suggested changes:
  1. Use Pydantic models for request bodies across endpoints with explicit field types and validators (e.g., non-empty `questions` list).
  2. Add unit tests for invalid payloads.
- Tests / Acceptance criteria:
  - Endpoint returns 400 for malformed/empty required fields.
- PR guidance: Medium PR. Message: `feat(api): add stricter pydantic validation for upload/quiz/question endpoints`.
- Est. effort: 1–3 hours.

---

## P2 — Medium

### P2-1: Fix TeacherDashboard navigation selection UX for People tab
- Files:
  - `smartclass/lib/screens/teacher_screen/teacher_dashboard.dart`
- Suggested changes:
  1. When `index == 4`, set `_selectedIndex = 4` before performing navigation OR after returning from the pushed page on pop.
- Tests / Acceptance criteria:
  - Tapping People shows it highlighted until return.
- PR guidance: Tiny PR. Message: `fix(ui): mark People tab as selected in TeacherDashboard`.
- Est. effort: 15–30 minutes.

### P2-2: Confirm `get_public_url` return and adjust code
- Files:
  - `backend/routers/question.py` (bucket.get_public_url)
- Suggested changes:
  1. Check SDK docs; ensure the returned value is a string. If an object is returned, adapt to use the correct key (e.g., `.publicURL`).
- Tests / Acceptance criteria:
  - Unit test mocking SDK response to assert stored `file_url` is a string URL.
- PR guidance: Tiny PR. Message: `fix(storage): normalize get_public_url response to string`.
- Est. effort: 30–60 minutes.

---

## P3 — Low / Cosmetic / Docs

### P3-1: Centralize BACKEND_URL string in frontend and document in README
- Files:
  - All frontend files using `https://supaaiapp-1.onrender.com`
- Suggested changes:
  1. Replace literals with `AppConfig.apiBaseUrl` and use `Uri.parse('${AppConfig.apiBaseUrl}/upload/')` etc.
  2. Document usage in README and add `.env.example`.
- PR guidance: Small PR. Message: `chore(config): centralize backend URL and add README examples`.
- Est. effort: 30–90 minutes.

### P3-2: Improve logging and observability
- Files:
  - `backend/*` (especially error handlers)
- Suggested changes:
  1. Replace `print()` with structured logging via `logging` module and include request ids in responses.
  2. Add small README section on how to view logs when deployed.
- PR guidance: Medium PR. Message: `chore(logging): add structured logging and improved error messages`.
- Est. effort: 1–3 hours.

---

## Notes for reviewers
- Keep PRs small and focused (one issue per PR where possible).
- Each PR should include unit tests or a manual QA checklist.
- Prefer feature branches: `fix/<area>-<short-desc>` (e.g., `fix/chatbot-session-isolation`).

---

If you'd like, I can now:
- Create the first PR branch for a chosen P0 or P1 item and prepare a draft PR description, or
- Break down an item into smaller sub-tasks and allocate quick unit tests for them.

Tell me which item you want me to start next.
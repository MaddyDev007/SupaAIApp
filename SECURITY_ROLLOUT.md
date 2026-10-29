# SmartClassAI security hardening — rollout notes

## Current status

- The main security changes from PR #1 have been merged and the migration `20261029000000_smartclass_security_hardening.sql` has been applied to the connected Supabase project.
- All nine application tables now have RLS enabled. The `lessons`, `questions`, and `notes` buckets are private.
- Existing table row counts were preserved. The migration backfilled missing profile/user rows and preserved verified existing class-owner access.
- Follow-up migration `20261029091500_restrict_security_definer_rpc.sql` is staged in this PR. It moves internal policy/trigger helper functions into the non-exposed `private` schema, rewrites policy and trigger references, and revokes direct RPC execution from old public helper functions. It has been tested in a rolled-back transaction but is not yet applied to the live database.

## Main security changes already applied

- Least-privilege RLS for profiles, users, classes, memberships, materials, question banks, quizzes, results, and owner-only notes.
- Private Storage policies and signed URLs for lessons, questions, and note images.
- Authenticated backend endpoints with class-owner/membership checks.
- Authenticated class-code join RPC instead of exposing class codes through a broad SELECT policy.
- Sanitized `get_class_quizzes` RPC removes the answer key from student-readable payloads.
- Database result trigger computes scores rather than trusting client-provided scores.
- Auth trigger creates profile/user rows; existing classroom owners are preserved during profile backfill.

## Validation performed

- Ran the main migration against the live schema inside a transaction and explicitly rolled it back before applying it.
- Simulated an authenticated class member: direct reads of `public.quizzes` returned zero rows, the authorized RPC returned a quiz list, and answer keys were not exposed.
- Inserted a forged quiz-result payload within a rolled-back transaction; the database replaced the requested score, question count, subject, name, and avatar with computed/database-owned values.
- Verified the same behavior again after preparing the follow-up migration, without persisting test rows.
- After the main migration, verified that all nine application tables had RLS enabled, all three Storage buckets were private, and counts for classes, memberships, materials, quizzes, questions, notes, and results were unchanged.

## Remaining release work

1. Apply the follow-up security-definer hardening migration after reviewing PR #2.
2. Check the Supabase security advisor after the follow-up. The authenticated `join_class_by_code` and `get_class_quizzes` RPCs are intentionally exposed; internal helpers and trigger functions should no longer be directly callable through PostgREST.
3. Run `flutter analyze`, Python tests/compile checks, and end-to-end tests; these automated suites have not been run in this environment.
4. Coordinate the updated Flutter build with the backend/database cutover. Existing installed builds do not send the new Bearer headers and still query quiz rows directly, so old clients will not work correctly after the new security rules.
5. Enable leaked-password protection, shorten email OTP expiry, and schedule the supported PostgreSQL security-patch upgrade. These separate advisor warnings are not changed by these migrations.

# SmartClassAI security hardening — rollout notes

## Status

This branch is a review draft. The migration has NOT been applied to Supabase. No production database settings, policies, or bucket visibility have been changed by this branch.

The application has active users and only one Supabase project is currently available. Do not apply the migration directly to that live project until the complete matrix below has passed in an isolated test environment and a recoverable database backup has been confirmed.

## What this change proposes

- Enable RLS on public application tables and replace broad/duplicate policies with least-privilege rules.
- Restrict profiles and user records to the owner, with limited teacher access to students in classes they own.
- Restrict classes, memberships, materials, question-bank rows, quizzes, results, and notes according to class ownership/membership.
- Make the lessons, questions, and notes buckets private and use short-lived signed URLs for Flutter file viewing and downloads.
- Move privileged class deletion and student-removal operations behind authenticated FastAPI endpoints. The backend verifies the Bearer token and teacher ownership before using its service-role client.
- Create profiles and users records in an auth trigger; teacher role is derived from a verified @myclg.edu email.
- Stop direct student reads of the public.quizzes table. The get_class_quizzes RPC checks class access and omits the answer key from student quiz payloads.
- Calculate results.score and results.total_questions in a database trigger, instead of trusting values sent by a Flutter client.
- Use a class-code RPC for joining a class rather than exposing all class codes through a broad SELECT policy.

## Required release checks

Run these in a temporary Supabase project/branch and a non-production application deployment first.

1. Apply the migration to the isolated database; verify it completes cleanly and the security advisor no longer reports the eight previously unprotected application tables.
2. Check unauthenticated direct REST reads/writes against all application tables are denied.
3. Check a student can read only their own profile, their own notes, and quizzes/materials/question files for classes they joined. Confirm note images are inaccessible to other students and teachers.
4. Confirm students cannot select from public.quizzes directly and cannot retrieve answer keys through get_class_quizzes.
5. Submit a quiz with correct, incorrect, malformed, and altered score payloads. Verify the database stores the score it computes from the protected answer key and rejects invalid answer arrays.
6. Check a teacher can create a class, join as its teacher membership, upload materials, generate quizzes/exam files, list their class students, remove a student, and delete their own class only.
7. Check a teacher cannot access another teacher's classes, materials, quiz records, results, or files.
8. Check private lesson/question file open, external open, download, replacement, and deletion; check owner-only note image upload, open, replacement, and deletion.
9. Check signup before email confirmation, email confirmation, Google OAuth, profile updates, class join by code, expired sessions, and backend requests without a Bearer token.
10. Run flutter analyze, available Flutter tests, and Python compile/unit tests. Review the migration and all generated changes before any production change.

## Coordinated deployment warning

Existing installed Flutter clients do not send Bearer tokens to every backend endpoint and directly read quiz rows. After this change, older clients may fail against the new backend/database rules. Plan a coordinated release and distribution of the updated client; do not deploy only the backend or only the database migration.

## Validation performed

- Executed the full migration against the connected schema inside a transaction that was explicitly rolled back.
- Inside separate rolled-back transactions, simulated an authenticated class member and an existing class owner: direct student reads of the base quizzes table returned zero rows, authorized RPC access returned class quizzes, and the RPC did not expose the answer key.
- In a rolled-back result insert, a client-supplied score of 999 and forged metadata were replaced by the database-computed score, question count, subject, and stored user profile values.
- Verified after rollback that the live database still has the original RLS state and all three Storage buckets remain public. No persistent database changes were made by these tests.

## Known limitations of this review

- The SQL tests above validate the migration and selected policy/trigger paths in a transaction, but do not replace complete end-to-end testing.
- Flutter analysis, Python test execution, and full app end-to-end tests have not been run in this environment.
- Existing data has 19 classes whose creator IDs do not yet have profile rows; the migration explicitly backfills their profiles and preserves verified existing class-owner access.
- Review the coordinated client/backend release: older installed Flutter builds do not send the newly required Bearer headers or call the sanitized quiz RPC.

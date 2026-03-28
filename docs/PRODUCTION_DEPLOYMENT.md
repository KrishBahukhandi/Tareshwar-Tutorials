# Production Deployment Guide

## 1. Runtime configuration

Student mobile app and teacher/admin web must be built with:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `AUTH_REDIRECT_URL`

Use `.env.production.example` as the source-of-truth template for app runtime values.

Supabase auth email setup must provide:

- `SMTP_USER`
- `SMTP_PASS`
- `SMTP_ADMIN_EMAIL`

## 2. Supabase rollout

Run all SQL migrations in `supabase/migrations` in order, including:

- `lecture_progress.sql`
- `analytics_events.sql`
- `live_classes.sql`
- `doubt_discussion.sql`
- `announcements_push_sent.sql`
- `production_hardening.sql`
- `audit_logs.sql`

Verify after migration:

- RLS is enabled on core tables
- storage buckets exist and match app constants
- email confirmation settings match the signup flow
- `site_url` and allowed redirect URLs in Supabase Auth match `AUTH_REDIRECT_URL`
- OTP and reset-password emails are delivered successfully

## 2.5 Edge function rollout

Deploy the teacher creation function:

`supabase functions deploy admin-create-teacher`

Provide function secrets for:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `SMTP_HOST`
- `SMTP_PORT`
- `SMTP_USER`
- `SMTP_PASS`
- `SMTP_ADMIN_EMAIL`
- `SMTP_SENDER_NAME`
- `PUBLIC_APP_URL`

## 3. Android release

1. Copy `android/key.properties.example` to `android/key.properties`
2. Fill real keystore values
3. Export runtime values:
   `export SUPABASE_URL=...`
   `export SUPABASE_ANON_KEY=...`
   `export AUTH_REDIRECT_URL=https://your-domain.com`
4. Build with:
   `sh scripts/build_android_release.sh`
5. Verify:
   - login/signup
   - video playback
   - downloads
   - notes
   - test flow
   - doubts
   - live class list

## 4. Web deployment

Build teacher/admin web with:

`sh scripts/build_web_release.sh`

Verify on the deployed domain:

- admin login
- teacher login
- navigation and responsive layout on laptop widths
- course/batch/user management
- announcements
- live classes
- analytics screens

## 5. Final pre-launch checks

- `flutter analyze`
- `flutter test`
- Android release build succeeds
- web build succeeds
- SMTP works in production
- one real admin, teacher, and student account are tested end-to-end

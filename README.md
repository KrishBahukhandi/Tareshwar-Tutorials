# Tareshwar Tutorials

Flutter + Supabase platform for coaching institutes running online batches, lectures, tests, doubts, downloads, live classes, and admin operations.

## Local Setup

1. Install Flutter and project dependencies:
   `flutter pub get`
2. Provide Supabase credentials with dart defines:
   `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
3. Provide an auth redirect URL for email verification and password reset flows when testing auth emails:
   `--dart-define=AUTH_REDIRECT_URL=https://your-domain.com`
4. For local Supabase email flows, export SMTP env vars before starting Supabase:
   `SMTP_USER`, `SMTP_PASS`, `SMTP_ADMIN_EMAIL`
5. Apply database migrations from the `supabase/migrations` directory or run the schema files in Supabase SQL editor.

## Release Setup

Use `.env.production.example` as a checklist for the production runtime values.

### Android signing

Create `android/key.properties` with:

```properties
storeFile=../keystore/upload-keystore.jks
storePassword=your-store-password
keyAlias=upload
keyPassword=your-key-password
```

Release builds are expected to use a real signing key. Debug signing is no longer used for release.

### Release build helpers

- Android: `sh scripts/build_android_release.sh`
- Web: `sh scripts/build_web_release.sh`

## Production Notes

- Supabase credentials are read from `--dart-define`, not hardcoded in source.
- Auth email redirects are controlled through `AUTH_REDIRECT_URL`.
- Student signup assumes email verification is enabled.
- Student test delivery uses server-side RPCs for safer question access and scoring.
- Students are not allowed to self-enroll into batches; enrollment is managed by institute staff.
- Admin actions can be audited through the `audit_logs` table after migrations are applied.

## Delivery Docs

- Deployment: `docs/PRODUCTION_DEPLOYMENT.md`
- Admin operations: `docs/ADMIN_OPERATIONS.md`
- Soft launch UAT: `docs/SOFT_LAUNCH_UAT.md`
- Role-based QA: `docs/ROLE_BASED_QA_RUNBOOK.md`
- Launch signoff: `docs/LAUNCH_SIGNOFF.md`
- Client handoff: `docs/CLIENT_HANDOFF.md`

## Verification

- Static analysis: `flutter analyze`
- Tests: `flutter test`

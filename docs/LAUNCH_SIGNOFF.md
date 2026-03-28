# Launch Signoff Sheet

Complete this before handing the project to the client for soft launch.

## Build and environment

- [ ] Production `SUPABASE_URL` is configured in mobile and web builds
- [ ] Production `SUPABASE_ANON_KEY` is configured in mobile and web builds
- [ ] SMTP credentials are configured and tested
- [ ] Android release build is signed with the real keystore
- [ ] Teacher/admin web build is deployed to the final domain

## Database and backend

- [ ] all required migrations are applied
- [ ] `production_hardening.sql` is confirmed in production
- [ ] `audit_logs.sql` is confirmed in production
- [ ] storage buckets exist and access rules are verified
- [ ] email verification and reset-password flows are tested in production

## Functional QA

- [ ] student QA completed
- [ ] teacher QA completed
- [ ] admin QA completed
- [ ] downloads verified on a real Android device
- [ ] test submission and result review verified on production data

## Client delivery

- [ ] client received Android app artifact or install method
- [ ] client received teacher/admin web URL
- [ ] client received admin credentials
- [ ] client received [ADMIN_OPERATIONS.md](/Users/krish/Documents/Documents_Krish_MacBook_Air/Projects/TareshwarTutorialPlatform/Tareshwar-Tutorials/docs/ADMIN_OPERATIONS.md)
- [ ] client received [CLIENT_HANDOFF.md](/Users/krish/Documents/Documents_Krish_MacBook_Air/Projects/TareshwarTutorialPlatform/Tareshwar-Tutorials/docs/CLIENT_HANDOFF.md)
- [ ] client agreed on support window for soft launch

## Known v1 limitations acknowledged

- [ ] payment gateway is intentionally out of scope
- [ ] offline downloads use access checks but not full DRM
- [ ] only a single institute is supported in this release

## Final approval

- Delivery owner:
- Date:
- Client representative:
- Soft launch go/no-go:

# Client Handoff Package

## Delivery contents

- Android student app release artifact
- Teacher/admin web deployment URL
- Supabase project with all required migrations applied
- Admin credentials for first institute operator
- Production environment template
- Production deployment guide
- Admin operations guide
- Soft launch UAT checklist
- Role-based QA runbook
- Launch signoff sheet

## Client-facing scope for this release

- student mobile access for lectures, notes, tests, doubts, live classes, notifications, and downloads
- teacher web access for content, doubts, live classes, and analytics
- admin web access for users, courses, batches, enrollments, announcements, and analytics
- email-verification based signup for students

## Not included in this release

- payment gateway and revenue collection
- multi-institute tenancy
- DRM-grade offline protection

## Final handoff checklist

1. Confirm production `SUPABASE_URL` and `SUPABASE_ANON_KEY` are used in shipped builds.
2. Confirm `production_hardening.sql` and `audit_logs.sql` are applied in the production Supabase project.
3. Confirm SMTP is configured and password reset plus signup verification emails are delivered successfully.
4. Confirm Android release is signed with the institute delivery keystore.
5. Confirm admin, teacher, and student UAT each pass without blocker defects.
6. Share the operations docs with the client owner/admin team.

## Recommended soft-launch support window

- keep one developer available during the first 3-5 working days after launch
- review audit logs, failed auth cases, and support-reported issues daily
- freeze non-critical feature work until launch defects are closed

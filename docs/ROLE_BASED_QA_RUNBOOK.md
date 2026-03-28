# Role-Based QA Runbook

Use this runbook during final internal QA and again during client-side UAT.

## Test accounts to prepare

- 1 admin account
- 2 teacher accounts
- 3-5 student accounts for hands-on QA
- 1 disabled student account
- 1 disabled teacher account

## Minimum data to prepare

- 2 published courses
- 2 active batches
- 1 inactive batch
- 6-10 lectures across the batches
- notes/PDFs attached to at least 2 lectures
- 2 published tests with questions
- 2 live classes
- 3-5 announcements
- 3-5 doubts, with at least 2 answered

## Student QA

### Authentication

- sign up with a new email and confirm the verification email is received
- confirm login does not work before verification if production auth requires verification
- sign in after verification and confirm landing on the student area
- request password reset and confirm email delivery
- sign in as a disabled student and confirm access is blocked

### Learning access

- confirm only enrolled batch content is visible
- open course detail, chapter list, lecture list, and lecture player
- open lecture notes/PDFs
- confirm unenrolled course content is not accessible by direct navigation

### Tests

- open test instructions and start a test
- complete a test attempt and submit successfully
- open the result screen and confirm review data loads only after submission
- confirm answer keys are not exposed before submission

### Doubts and live classes

- create a doubt with and without an image
- open a doubt detail page and confirm replies appear correctly
- open live class list and live class detail

### Notifications and downloads

- open notifications and mark items as read
- download a lecture and confirm playback works
- remove student enrollment or disable the account, then confirm offline playback is rejected on next access

## Teacher QA

### Authentication

- sign in on web with a valid teacher account
- create a teacher from the admin panel and confirm the credentials email is received
- confirm a disabled teacher account cannot continue using the app

### Course and content management

- confirm only owned courses are visible
- create or edit subject/chapter/lecture content
- upload or edit a test
- confirm direct access to another teacher's resources is blocked

### Operations

- reply to doubts assigned to owned content
- schedule, update, and delete a live class for an owned batch
- confirm managing another teacher's live class is blocked
- open analytics screens and confirm data loads without crashes

## Admin QA

### Authentication and dashboard

- sign in on web and confirm dashboard loads
- verify navigation works on normal laptop width

### Institute operations

- create or edit course and batch records
- enroll and remove a student from a batch
- change a user active state and confirm access behavior changes
- create and delete an announcement

### Audit and support checks

- verify important admin actions create rows in `audit_logs`
- confirm payment screens are not exposed in this release
- confirm disabled users cannot continue after sign-out/session refresh

## Pass criteria

- no blocker issue in any critical role flow
- no unauthorized cross-role or cross-owner access
- no broken navigation dead ends in delivered areas
- all verification emails and reset emails are delivered
- Android student build and deployed web build both match the tested version

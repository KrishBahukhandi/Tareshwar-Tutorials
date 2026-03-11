-- ═══════════════════════════════════════════════════════════════════
--  TARESHWAR TUTORIALS  –  Complete Supabase PostgreSQL Schema
--  Version: 3.0 (Production Ready)
--
--  Learning Hierarchy:
--    Course → Batch → Subject → Chapter → Lecture
--
--  Roles:  student | teacher | admin
--
--  HOW TO RUN:
--    1. Open Supabase Dashboard → SQL Editor
--    2. Paste this entire file and click "Run"
--    3. Then create Storage Buckets (Section 17 at the bottom)
--
--  Tables created:
--    01. users               – profiles linked to auth.users
--    02. courses             – course catalogue
--    03. batches             – scheduled cohorts of a course
--    04. enrollments         – student ↔ batch membership
--    05. subjects            – subjects inside a batch/course
--    06. chapters            – chapters inside a subject
--    07. lectures            – lectures inside a chapter
--    08. watch_progress      – per-student lecture watch state
--    09. tests               – MCQ tests per chapter
--    10. questions           – questions inside a test
--    11. test_attempts       – student test submissions
--    12. doubts              – student questions
--    13. doubt_replies       – threaded replies on doubts
--    14. notifications       – in-app notification inbox
--    15. announcements       – batch or platform-wide messages
--    16. payments            – course purchase records
--    17. refund_requests     – refund workflow
--    18. live_classes        – scheduled live/virtual class sessions
-- ═══════════════════════════════════════════════════════════════════

-- ── Safety: drop everything cleanly before re-creating ───────────
-- (Safe to run on a fresh project; on existing data, skip this block)

drop trigger  if exists on_auth_user_created    on auth.users;
drop function if exists public.handle_new_user  cascade;
drop function if exists public.is_admin         cascade;
drop function if exists public.is_teacher       cascade;
drop function if exists public.update_updated_at cascade;

drop table if exists public.refund_requests    cascade;
drop table if exists public.payments           cascade;
drop table if exists public.announcements      cascade;
drop table if exists public.notifications      cascade;
drop table if exists public.doubt_replies      cascade;
drop table if exists public.doubts             cascade;
drop table if exists public.test_attempts      cascade;
drop table if exists public.questions          cascade;
drop table if exists public.tests              cascade;
drop table if exists public.watch_progress     cascade;
drop table if exists public.live_classes       cascade;
drop table if exists public.lectures           cascade;
drop table if exists public.chapters           cascade;
drop table if exists public.subjects           cascade;
drop table if exists public.enrollments        cascade;
drop table if exists public.batches            cascade;
drop table if exists public.courses            cascade;
drop table if exists public.users              cascade;

-- ── Extension ─────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";


-- ═══════════════════════════════════════════════════════════════════
--  1. USERS
--  Mirror of auth.users with extra profile fields.
--  Auto-created by trigger on signup.
-- ═══════════════════════════════════════════════════════════════════
create table public.users (
  id          uuid        primary key references auth.users(id) on delete cascade,
  name        text        not null,
  email       text        not null unique,
  phone       text,
  role        text        not null default 'student'
                          check (role in ('student','teacher','admin')),
  avatar_url  text,
  is_active   boolean     not null default true,
  created_at  timestamptz not null default now()
);

-- ── Trigger: auto-create public profile on auth signup ────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name',  'Student'),
    new.email,
    coalesce(new.raw_user_meta_data->>'role',  'student')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ═══════════════════════════════════════════════════════════════════
--  2. COURSES
--  Top-level content unit. Students enroll via Batches, not directly.
-- ═══════════════════════════════════════════════════════════════════
create table public.courses (
  id             uuid           primary key default uuid_generate_v4(),
  title          text           not null,
  description    text           not null default '',
  teacher_id     uuid           not null references public.users(id) on delete restrict,
  price          numeric(10,2)  not null default 0  check (price >= 0),
  thumbnail_url  text,
  category_tag   text,
  is_published   boolean        not null default false,
  -- Maintained by triggers (cannot use subqueries in generated columns)
  total_lectures int            not null default 0,
  total_students int            not null default 0,
  rating         numeric(3,2)   default null  check (rating between 0 and 5),
  created_at     timestamptz    not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  3. BATCHES
--  A scheduled cohort under a Course.
--  Students always enroll in a Batch, never a Course directly.
-- ═══════════════════════════════════════════════════════════════════
create table public.batches (
  id            uuid        primary key default uuid_generate_v4(),
  course_id     uuid        not null references public.courses(id) on delete cascade,
  batch_name    text        not null,
  description   text,
  start_date    date        not null,
  end_date      date,
  max_students  int         not null default 50  check (max_students > 0),
  is_active     boolean     not null default true,
  created_at    timestamptz not null default now(),
  check (end_date is null or end_date >= start_date)
);


-- ═══════════════════════════════════════════════════════════════════
--  4. ENROLLMENTS
--  Student ↔ Batch many-to-many.
--  progress_percent is updated whenever lecture progress changes.
-- ═══════════════════════════════════════════════════════════════════
create table public.enrollments (
  id               uuid           primary key default uuid_generate_v4(),
  student_id       uuid           not null references public.users(id)   on delete cascade,
  batch_id         uuid           not null references public.batches(id) on delete cascade,
  enrolled_at      timestamptz    not null default now(),
  progress_percent numeric(5,2)   not null default 0
                                  check (progress_percent between 0 and 100),
  unique (student_id, batch_id)
);


-- ═══════════════════════════════════════════════════════════════════
--  5. SUBJECTS
--  Belong to a Course. Optionally scoped to one Batch.
--  (batch_id = null means shared across all batches of the course)
-- ═══════════════════════════════════════════════════════════════════
create table public.subjects (
  id          uuid        primary key default uuid_generate_v4(),
  course_id   uuid        not null references public.courses(id) on delete cascade,
  batch_id    uuid        references public.batches(id) on delete cascade,  -- null = shared
  name        text        not null,
  sort_order  int         not null default 0,
  created_at  timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  6. CHAPTERS
--  Belong to a Subject.
-- ═══════════════════════════════════════════════════════════════════
create table public.chapters (
  id          uuid        primary key default uuid_generate_v4(),
  subject_id  uuid        not null references public.subjects(id) on delete cascade,
  name        text        not null,
  sort_order  int         not null default 0,
  created_at  timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  7. LECTURES
--  Belong to a Chapter.
--  attachments stores an array of {name, url, file_type} objects.
-- ═══════════════════════════════════════════════════════════════════
create table public.lectures (
  id                uuid        primary key default uuid_generate_v4(),
  chapter_id        uuid        not null references public.chapters(id) on delete cascade,
  title             text        not null,
  description       text,
  video_url         text,
  notes_url         text,
  attachments       jsonb       not null default '[]',
  duration_seconds  int         check (duration_seconds >= 0),
  is_free           boolean     not null default false,
  sort_order        int         not null default 0,
  created_at        timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  8. WATCH PROGRESS
--  Per-student, per-lecture playback state.
-- ═══════════════════════════════════════════════════════════════════
create table public.watch_progress (
  id               uuid        primary key default uuid_generate_v4(),
  student_id       uuid        not null references public.users(id)    on delete cascade,
  lecture_id       uuid        not null references public.lectures(id) on delete cascade,
  watched_seconds  int         not null default 0  check (watched_seconds >= 0),
  completed        boolean     not null default false,
  updated_at       timestamptz not null default now(),
  unique (student_id, lecture_id)
);

-- Auto-update updated_at on watch_progress
create or replace function public.update_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_watch_progress_updated_at
  before update on public.watch_progress
  for each row execute function public.update_updated_at();


-- ═══════════════════════════════════════════════════════════════════
--  COUNTER TRIGGERS
--  Keep courses.total_lectures and courses.total_students in sync.
--  Avoids subqueries in generated columns (not supported in PG).
-- ═══════════════════════════════════════════════════════════════════

-- ── total_lectures: recalculate for a course ─────────────────────
create or replace function public.refresh_course_lecture_count()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_course_id uuid;
begin
  -- Determine the affected course_id from the changed lecture's chapter
  if (tg_op = 'DELETE') then
    select s.course_id into v_course_id
      from public.chapters ch
      join public.subjects  s on s.id = ch.subject_id
     where ch.id = old.chapter_id;
  else
    select s.course_id into v_course_id
      from public.chapters ch
      join public.subjects  s on s.id = ch.subject_id
     where ch.id = new.chapter_id;
  end if;

  if v_course_id is not null then
    update public.courses
       set total_lectures = (
             select count(*)::int
               from public.lectures  l
               join public.chapters ch on ch.id = l.chapter_id
               join public.subjects  s  on  s.id = ch.subject_id
              where s.course_id = v_course_id
           )
     where id = v_course_id;
  end if;
  return null;
end;
$$;

create trigger trg_course_lecture_count
  after insert or update or delete on public.lectures
  for each row execute function public.refresh_course_lecture_count();

-- ── total_students: recalculate for a course ─────────────────────
create or replace function public.refresh_course_student_count()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_course_id uuid;
begin
  if (tg_op = 'DELETE') then
    select b.course_id into v_course_id
      from public.batches b where b.id = old.batch_id;
  else
    select b.course_id into v_course_id
      from public.batches b where b.id = new.batch_id;
  end if;

  if v_course_id is not null then
    update public.courses
       set total_students = (
             select count(distinct e.student_id)::int
               from public.enrollments e
               join public.batches     b on b.id = e.batch_id
              where b.course_id = v_course_id
           )
     where id = v_course_id;
  end if;
  return null;
end;
$$;

create trigger trg_course_student_count
  after insert or delete on public.enrollments
  for each row execute function public.refresh_course_student_count();


-- ═══════════════════════════════════════════════════════════════════
--  9. TESTS
--  MCQ quiz attached to a Chapter.
-- ═══════════════════════════════════════════════════════════════════
create table public.tests (
  id                uuid        primary key default uuid_generate_v4(),
  chapter_id        uuid        not null references public.chapters(id) on delete cascade,
  title             text        not null,
  duration_minutes  int         not null default 60   check (duration_minutes > 0),
  total_marks       int         not null default 100  check (total_marks > 0),
  negative_marks    numeric(4,2) not null default 0.25 check (negative_marks >= 0),
  is_published      boolean     not null default true,
  created_at        timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  10. QUESTIONS
--  MCQ questions inside a Test.
--  options is a text[] array of 4 answer choices.
-- ═══════════════════════════════════════════════════════════════════
create table public.questions (
  id                    uuid    primary key default uuid_generate_v4(),
  test_id               uuid    not null references public.tests(id) on delete cascade,
  question              text    not null,
  question_image_url    text,
  options               text[]  not null,
  correct_option_index  int     not null  check (correct_option_index >= 0),
  marks                 int     not null default 4  check (marks > 0),
  explanation           text,
  created_at            timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  11. TEST ATTEMPTS
--  Student's submitted answers for a test.
--  answers is a JSONB map of {questionId: selectedOptionIndex}.
-- ═══════════════════════════════════════════════════════════════════
create table public.test_attempts (
  id                  uuid        primary key default uuid_generate_v4(),
  test_id             uuid        not null references public.tests(id)  on delete cascade,
  student_id          uuid        not null references public.users(id)  on delete cascade,
  score               int         not null,
  total_marks         int         not null,
  correct_answers     int         not null default 0,
  wrong_answers       int         not null default 0,
  skipped             int         not null default 0,
  time_taken_seconds  int         not null default 0  check (time_taken_seconds >= 0),
  answers             jsonb       not null default '{}',
  attempted_at        timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  12. DOUBTS
--  Student questions, optionally tied to a lecture.
-- ═══════════════════════════════════════════════════════════════════
create table public.doubts (
  id           uuid        primary key default uuid_generate_v4(),
  student_id   uuid        not null references public.users(id)    on delete cascade,
  lecture_id   uuid        references public.lectures(id)          on delete set null,
  question     text        not null,
  image_url    text,
  answer       text,
  answered_by  uuid        references public.users(id)             on delete set null,
  is_answered  boolean     not null default false,
  reply_count  int         not null default 0,
  created_at   timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  13. DOUBT REPLIES
--  Threaded reply chain under a Doubt.
-- ═══════════════════════════════════════════════════════════════════
create table public.doubt_replies (
  id          uuid        primary key default uuid_generate_v4(),
  doubt_id    uuid        not null references public.doubts(id) on delete cascade,
  author_id   uuid        not null references public.users(id)  on delete cascade,
  role        text        not null default 'student'
                          check (role in ('student','teacher','admin')),
  body        text        not null,
  image_url   text,
  created_at  timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  14. NOTIFICATIONS
--  In-app notification inbox per user.
--  user_id = null  →  broadcast to all (platform-wide).
--  type: 'lecture' | 'test' | 'announcement' | 'general'
-- ═══════════════════════════════════════════════════════════════════
create table public.notifications (
  id            uuid        primary key default uuid_generate_v4(),
  user_id       uuid        references public.users(id) on delete cascade,  -- null = broadcast
  title         text        not null,
  body          text        not null,
  type          text        not null default 'general'
                            check (type in ('lecture','test','announcement','general')),
  reference_id  uuid,       -- links to a lecture/test/batch etc.
  is_read       boolean     not null default false,
  created_at    timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  15. ANNOUNCEMENTS
--  Admin / teacher posts. batch_id = null means platform-wide.
-- ═══════════════════════════════════════════════════════════════════
create table public.announcements (
  id          uuid        primary key default uuid_generate_v4(),
  author_id   uuid        not null references public.users(id)   on delete cascade,
  batch_id    uuid        references public.batches(id)          on delete cascade,  -- null = platform-wide
  title       text        not null,
  body        text        not null,
  created_at  timestamptz not null default now()
);


-- ═══════════════════════════════════════════════════════════════════
--  16. PAYMENTS
--  Records a student's course purchase.
--  payment_status: 'completed' | 'pending' | 'failed' | 'refunded'
-- ═══════════════════════════════════════════════════════════════════
create table public.payments (
  id                uuid           primary key default uuid_generate_v4(),
  student_id        uuid           not null references public.users(id)   on delete restrict,
  course_id         uuid           not null references public.courses(id) on delete restrict,
  amount            numeric(10,2)  not null  check (amount >= 0),
  payment_status    text           not null default 'pending'
                                   check (payment_status in ('completed','pending','failed','refunded')),
  payment_method    text,          -- 'upi' | 'card' | 'netbanking' | 'cash' | etc.
  transaction_id    text,
  notes             text,
  created_at        timestamptz    not null default now(),
  updated_at        timestamptz    not null default now()
);

create trigger trg_payments_updated_at
  before update on public.payments
  for each row execute function public.update_updated_at();


-- ═══════════════════════════════════════════════════════════════════
--  17. REFUND REQUESTS
--  Student requests refund; admin approves / rejects.
--  status: 'pending' | 'approved' | 'rejected'
-- ═══════════════════════════════════════════════════════════════════
create table public.refund_requests (
  id          uuid        primary key default uuid_generate_v4(),
  payment_id  uuid        not null references public.payments(id) on delete cascade,
  student_id  uuid        not null references public.users(id)    on delete cascade,
  reason      text        not null default '',
  status      text        not null default 'pending'
                          check (status in ('pending','approved','rejected')),
  admin_note  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create trigger trg_refund_requests_updated_at
  before update on public.refund_requests
  for each row execute function public.update_updated_at();


-- ═══════════════════════════════════════════════════════════════════
--  18. LIVE CLASSES
--  Scheduled virtual/live sessions for a batch.
--  status is derived at query time from start_time + duration_minutes.
-- ═══════════════════════════════════════════════════════════════════
create table public.live_classes (
  id                 uuid        primary key default uuid_generate_v4(),
  batch_id           uuid        not null references public.batches(id)  on delete cascade,
  teacher_id         uuid        not null references public.users(id)    on delete restrict,
  title              text        not null,
  description        text,
  meeting_link       text        not null,
  start_time         timestamptz not null,
  duration_minutes   int         not null default 60  check (duration_minutes > 0),
  notification_sent  boolean     not null default false,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create trigger trg_live_classes_updated_at
  before update on public.live_classes
  for each row execute function public.update_updated_at();


-- ═══════════════════════════════════════════════════════════════════
--  INDEXES  (performance-critical FK and filter columns)
-- ═══════════════════════════════════════════════════════════════════

-- Users
create index idx_users_role             on public.users(role);
create index idx_users_email            on public.users(email);

-- Courses
create index idx_courses_teacher        on public.courses(teacher_id);
create index idx_courses_published      on public.courses(is_published);
create index idx_courses_category       on public.courses(category_tag);

-- Batches
create index idx_batches_course         on public.batches(course_id);
create index idx_batches_active         on public.batches(is_active);

-- Enrollments
create index idx_enrollments_student    on public.enrollments(student_id);
create index idx_enrollments_batch      on public.enrollments(batch_id);

-- Subjects
create index idx_subjects_course        on public.subjects(course_id);
create index idx_subjects_batch         on public.subjects(batch_id);

-- Chapters
create index idx_chapters_subject       on public.chapters(subject_id);

-- Lectures
create index idx_lectures_chapter       on public.lectures(chapter_id);
create index idx_lectures_is_free       on public.lectures(is_free);

-- Watch progress
create index idx_watch_student          on public.watch_progress(student_id);
create index idx_watch_lecture          on public.watch_progress(lecture_id);

-- Tests
create index idx_tests_chapter          on public.tests(chapter_id);
create index idx_tests_published        on public.tests(is_published);

-- Questions
create index idx_questions_test         on public.questions(test_id);

-- Test attempts
create index idx_attempts_test          on public.test_attempts(test_id);
create index idx_attempts_student       on public.test_attempts(student_id);
create index idx_attempts_at            on public.test_attempts(attempted_at desc);

-- Doubts
create index idx_doubts_student         on public.doubts(student_id);
create index idx_doubts_lecture         on public.doubts(lecture_id);
create index idx_doubts_answered        on public.doubts(is_answered);

-- Doubt replies
create index idx_replies_doubt          on public.doubt_replies(doubt_id);

-- Notifications
create index idx_notif_user             on public.notifications(user_id);
create index idx_notif_read             on public.notifications(is_read);
create index idx_notif_created          on public.notifications(created_at desc);

-- Announcements
create index idx_announce_batch         on public.announcements(batch_id);
create index idx_announce_created       on public.announcements(created_at desc);

-- Payments
create index idx_payments_student       on public.payments(student_id);
create index idx_payments_course        on public.payments(course_id);
create index idx_payments_status        on public.payments(payment_status);
create index idx_payments_created       on public.payments(created_at desc);

-- Refund requests
create index idx_refunds_payment        on public.refund_requests(payment_id);
create index idx_refunds_student        on public.refund_requests(student_id);
create index idx_refunds_status         on public.refund_requests(status);

-- Live classes
create index idx_live_classes_batch     on public.live_classes(batch_id);
create index idx_live_classes_teacher   on public.live_classes(teacher_id);
create index idx_live_classes_start     on public.live_classes(start_time);


-- ═══════════════════════════════════════════════════════════════════
--  HELPER FUNCTIONS
--  Security definer so they bypass RLS when called from policies.
-- ═══════════════════════════════════════════════════════════════════

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.users
     where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_teacher()
returns boolean
language sql
security definer
stable
set search_path = public
as $$
  select exists (
    select 1 from public.users
     where id = auth.uid() and role in ('teacher','admin')
  );
$$;


-- ═══════════════════════════════════════════════════════════════════
--  ROW LEVEL SECURITY
--  Enable RLS on every table, then add granular policies.
-- ═══════════════════════════════════════════════════════════════════
alter table public.users             enable row level security;
alter table public.courses           enable row level security;
alter table public.batches           enable row level security;
alter table public.enrollments       enable row level security;
alter table public.subjects          enable row level security;
alter table public.chapters          enable row level security;
alter table public.lectures          enable row level security;
alter table public.watch_progress    enable row level security;
alter table public.tests             enable row level security;
alter table public.questions         enable row level security;
alter table public.test_attempts     enable row level security;
alter table public.doubts            enable row level security;
alter table public.doubt_replies     enable row level security;
alter table public.notifications     enable row level security;
alter table public.announcements     enable row level security;
alter table public.payments          enable row level security;
alter table public.refund_requests   enable row level security;
alter table public.live_classes      enable row level security;


-- ─────────────────────────────────────────────────────────────────
--  USERS
-- ─────────────────────────────────────────────────────────────────
-- Own profile + admin sees all
create policy "users: select own or admin"
  on public.users for select
  using (auth.uid() = id or public.is_admin());

-- Own profile update + admin updates any
create policy "users: update own or admin"
  on public.users for update
  using (auth.uid() = id or public.is_admin());

-- Trigger creates profile on signup; also allow admin manual inserts
create policy "users: insert own or admin"
  on public.users for insert
  with check (auth.uid() = id or public.is_admin());

-- Only admin can hard-delete
create policy "users: delete admin only"
  on public.users for delete
  using (public.is_admin());


-- ─────────────────────────────────────────────────────────────────
--  COURSES
-- ─────────────────────────────────────────────────────────────────
-- Published courses visible to all; teacher sees own unpublished; admin sees all
create policy "courses: select"
  on public.courses for select
  using (
    is_published = true
    or auth.uid() = teacher_id
    or public.is_admin()
  );

create policy "courses: insert"
  on public.courses for insert
  with check (auth.uid() = teacher_id or public.is_admin());

create policy "courses: update"
  on public.courses for update
  using (auth.uid() = teacher_id or public.is_admin());

create policy "courses: delete"
  on public.courses for delete
  using (auth.uid() = teacher_id or public.is_admin());


-- ─────────────────────────────────────────────────────────────────
--  BATCHES
-- ─────────────────────────────────────────────────────────────────
create policy "batches: select"
  on public.batches for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.courses c
       where c.id = batches.course_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.enrollments e
       where e.batch_id = batches.id and e.student_id = auth.uid()
    )
  );

create policy "batches: insert"
  on public.batches for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.courses c
       where c.id = course_id and c.teacher_id = auth.uid()
    )
  );

create policy "batches: update"
  on public.batches for update
  using (
    public.is_admin()
    or exists (
      select 1 from public.courses c
       where c.id = batches.course_id and c.teacher_id = auth.uid()
    )
  );

create policy "batches: delete"
  on public.batches for delete
  using (public.is_admin());


-- ─────────────────────────────────────────────────────────────────
--  ENROLLMENTS
-- ─────────────────────────────────────────────────────────────────
create policy "enrollments: select"
  on public.enrollments for select
  using (
    auth.uid() = student_id
    or public.is_admin()
    or exists (
      select 1 from public.batches b
      join  public.courses c on c.id = b.course_id
       where b.id = enrollments.batch_id and c.teacher_id = auth.uid()
    )
  );

create policy "enrollments: insert"
  on public.enrollments for insert
  with check (
    public.is_admin()
    or auth.uid() = student_id
    or exists (
      select 1 from public.batches b
      join  public.courses c on c.id = b.course_id
       where b.id = batch_id and c.teacher_id = auth.uid()
    )
  );

-- Student can update own progress; teacher / admin can also update
create policy "enrollments: update"
  on public.enrollments for update
  using (
    auth.uid() = student_id
    or public.is_admin()
    or exists (
      select 1 from public.batches b
      join  public.courses c on c.id = b.course_id
       where b.id = enrollments.batch_id and c.teacher_id = auth.uid()
    )
  );

create policy "enrollments: delete"
  on public.enrollments for delete
  using (public.is_admin() or auth.uid() = student_id);


-- ─────────────────────────────────────────────────────────────────
--  SUBJECTS
-- ─────────────────────────────────────────────────────────────────
create policy "subjects: select"
  on public.subjects for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.courses c
       where c.id = subjects.course_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.enrollments e
      join  public.batches b on b.id = e.batch_id
       where e.student_id = auth.uid() and b.course_id = subjects.course_id
    )
  );

create policy "subjects: insert"
  on public.subjects for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.courses c
       where c.id = course_id and c.teacher_id = auth.uid()
    )
  );

create policy "subjects: update"
  on public.subjects for update
  using (
    public.is_admin()
    or exists (
      select 1 from public.courses c
       where c.id = subjects.course_id and c.teacher_id = auth.uid()
    )
  );

create policy "subjects: delete"
  on public.subjects for delete
  using (
    public.is_admin()
    or exists (
      select 1 from public.courses c
       where c.id = subjects.course_id and c.teacher_id = auth.uid()
    )
  );


-- ─────────────────────────────────────────────────────────────────
--  CHAPTERS
-- ─────────────────────────────────────────────────────────────────
create policy "chapters: select"
  on public.chapters for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.subjects s
      join  public.courses c on c.id = s.course_id
       where s.id = chapters.subject_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.subjects s
      join  public.enrollments e on true
      join  public.batches     b on b.id = e.batch_id
       where s.id = chapters.subject_id
         and e.student_id = auth.uid()
         and b.course_id  = s.course_id
    )
  );

create policy "chapters: insert"
  on public.chapters for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.subjects s
      join  public.courses c on c.id = s.course_id
       where s.id = subject_id and c.teacher_id = auth.uid()
    )
  );

create policy "chapters: update"
  on public.chapters for update
  using (
    public.is_admin()
    or exists (
      select 1 from public.subjects s
      join  public.courses c on c.id = s.course_id
       where s.id = chapters.subject_id and c.teacher_id = auth.uid()
    )
  );

create policy "chapters: delete"
  on public.chapters for delete
  using (
    public.is_admin()
    or exists (
      select 1 from public.subjects s
      join  public.courses c on c.id = s.course_id
       where s.id = chapters.subject_id and c.teacher_id = auth.uid()
    )
  );


-- ─────────────────────────────────────────────────────────────────
--  LECTURES
-- ─────────────────────────────────────────────────────────────────
create policy "lectures: select"
  on public.lectures for select
  using (
    is_free = true
    or public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join  public.subjects s on s.id = ch.subject_id
      join  public.courses  c on c.id = s.course_id
       where ch.id = lectures.chapter_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.chapters ch
      join  public.subjects     s on s.id  = ch.subject_id
      join  public.enrollments  e on true
      join  public.batches      b on b.id  = e.batch_id
       where ch.id           = lectures.chapter_id
         and e.student_id    = auth.uid()
         and b.course_id     = s.course_id
    )
  );

create policy "lectures: insert"
  on public.lectures for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join  public.subjects s on s.id = ch.subject_id
      join  public.courses  c on c.id = s.course_id
       where ch.id = chapter_id and c.teacher_id = auth.uid()
    )
  );

create policy "lectures: update"
  on public.lectures for update
  using (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join  public.subjects s on s.id = ch.subject_id
      join  public.courses  c on c.id = s.course_id
       where ch.id = lectures.chapter_id and c.teacher_id = auth.uid()
    )
  );

create policy "lectures: delete"
  on public.lectures for delete
  using (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join  public.subjects s on s.id = ch.subject_id
      join  public.courses  c on c.id = s.course_id
       where ch.id = lectures.chapter_id and c.teacher_id = auth.uid()
    )
  );


-- ─────────────────────────────────────────────────────────────────
--  WATCH PROGRESS
-- ─────────────────────────────────────────────────────────────────
-- Students fully own their own watch records; admin can view all
create policy "watch_progress: student own"
  on public.watch_progress for all
  using (auth.uid() = student_id or public.is_admin());


-- ─────────────────────────────────────────────────────────────────
--  TESTS
-- ─────────────────────────────────────────────────────────────────
create policy "tests: select"
  on public.tests for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join  public.subjects s on s.id = ch.subject_id
      join  public.courses  c on c.id = s.course_id
       where ch.id = tests.chapter_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.chapters ch
      join  public.subjects     s on s.id = ch.subject_id
      join  public.enrollments  e on true
      join  public.batches      b on b.id = e.batch_id
       where ch.id           = tests.chapter_id
         and e.student_id    = auth.uid()
         and b.course_id     = s.course_id
         and tests.is_published = true
    )
  );

create policy "tests: insert"
  on public.tests for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join  public.subjects s on s.id = ch.subject_id
      join  public.courses  c on c.id = s.course_id
       where ch.id = chapter_id and c.teacher_id = auth.uid()
    )
  );

create policy "tests: update"
  on public.tests for update
  using (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join  public.subjects s on s.id = ch.subject_id
      join  public.courses  c on c.id = s.course_id
       where ch.id = tests.chapter_id and c.teacher_id = auth.uid()
    )
  );

create policy "tests: delete"
  on public.tests for delete
  using (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join  public.subjects s on s.id = ch.subject_id
      join  public.courses  c on c.id = s.course_id
       where ch.id = tests.chapter_id and c.teacher_id = auth.uid()
    )
  );


-- ─────────────────────────────────────────────────────────────────
--  QUESTIONS
-- ─────────────────────────────────────────────────────────────────
create policy "questions: select"
  on public.questions for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.tests t
      join  public.chapters ch on ch.id = t.chapter_id
      join  public.subjects  s on  s.id = ch.subject_id
      join  public.courses   c on  c.id = s.course_id
       where t.id = questions.test_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.tests t
      join  public.chapters     ch on ch.id = t.chapter_id
      join  public.subjects      s on  s.id = ch.subject_id
      join  public.enrollments   e on true
      join  public.batches       b on  b.id = e.batch_id
       where t.id = questions.test_id
         and e.student_id = auth.uid()
         and b.course_id  = s.course_id
    )
  );

create policy "questions: insert"
  on public.questions for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.tests t
      join  public.chapters ch on ch.id = t.chapter_id
      join  public.subjects  s on  s.id = ch.subject_id
      join  public.courses   c on  c.id = s.course_id
       where t.id = test_id and c.teacher_id = auth.uid()
    )
  );

create policy "questions: update"
  on public.questions for update
  using (
    public.is_admin()
    or exists (
      select 1 from public.tests t
      join  public.chapters ch on ch.id = t.chapter_id
      join  public.subjects  s on  s.id = ch.subject_id
      join  public.courses   c on  c.id = s.course_id
       where t.id = questions.test_id and c.teacher_id = auth.uid()
    )
  );

create policy "questions: delete"
  on public.questions for delete
  using (
    public.is_admin()
    or exists (
      select 1 from public.tests t
      join  public.chapters ch on ch.id = t.chapter_id
      join  public.subjects  s on  s.id = ch.subject_id
      join  public.courses   c on  c.id = s.course_id
       where t.id = questions.test_id and c.teacher_id = auth.uid()
    )
  );


-- ─────────────────────────────────────────────────────────────────
--  TEST ATTEMPTS
-- ─────────────────────────────────────────────────────────────────
create policy "test_attempts: select"
  on public.test_attempts for select
  using (
    auth.uid() = student_id
    or public.is_admin()
    or exists (
      select 1 from public.tests t
      join  public.chapters ch on ch.id = t.chapter_id
      join  public.subjects  s on  s.id = ch.subject_id
      join  public.courses   c on  c.id = s.course_id
       where t.id = test_attempts.test_id and c.teacher_id = auth.uid()
    )
  );

-- Students submit their own attempts only
create policy "test_attempts: insert"
  on public.test_attempts for insert
  with check (auth.uid() = student_id);


-- ─────────────────────────────────────────────────────────────────
--  DOUBTS
-- ─────────────────────────────────────────────────────────────────
create policy "doubts: select"
  on public.doubts for select
  using (
    auth.uid() = student_id
    or public.is_teacher()
    or public.is_admin()
  );

create policy "doubts: insert"
  on public.doubts for insert
  with check (auth.uid() = student_id);

-- Teachers and admins can answer (update) doubts
create policy "doubts: update"
  on public.doubts for update
  using (public.is_teacher() or public.is_admin());

create policy "doubts: delete"
  on public.doubts for delete
  using (auth.uid() = student_id or public.is_admin());


-- ─────────────────────────────────────────────────────────────────
--  DOUBT REPLIES
-- ─────────────────────────────────────────────────────────────────
create policy "doubt_replies: select"
  on public.doubt_replies for select
  using (
    public.is_teacher()
    or public.is_admin()
    or exists (
      select 1 from public.doubts d
       where d.id = doubt_replies.doubt_id and d.student_id = auth.uid()
    )
  );

create policy "doubt_replies: insert"
  on public.doubt_replies for insert
  with check (auth.uid() = author_id);

create policy "doubt_replies: delete"
  on public.doubt_replies for delete
  using (auth.uid() = author_id or public.is_admin());


-- ─────────────────────────────────────────────────────────────────
--  NOTIFICATIONS
-- ─────────────────────────────────────────────────────────────────
-- Own notifications OR broadcast (user_id IS NULL)
create policy "notifications: select"
  on public.notifications for select
  using (user_id = auth.uid() or user_id is null);

create policy "notifications: insert"
  on public.notifications for insert
  with check (public.is_teacher() or public.is_admin());

-- Students mark their own as read
create policy "notifications: update"
  on public.notifications for update
  using (user_id = auth.uid() or public.is_admin());

create policy "notifications: delete"
  on public.notifications for delete
  using (public.is_admin());


-- ─────────────────────────────────────────────────────────────────
--  ANNOUNCEMENTS
-- ─────────────────────────────────────────────────────────────────
create policy "announcements: select"
  on public.announcements for select
  using (
    batch_id is null          -- platform-wide always visible
    or public.is_admin()
    or public.is_teacher()
    or exists (
      select 1 from public.enrollments e
       where e.batch_id = announcements.batch_id and e.student_id = auth.uid()
    )
  );

create policy "announcements: insert"
  on public.announcements for insert
  with check (auth.uid() = author_id and public.is_teacher());

create policy "announcements: delete"
  on public.announcements for delete
  using (auth.uid() = author_id or public.is_admin());


-- ─────────────────────────────────────────────────────────────────
--  PAYMENTS
-- ─────────────────────────────────────────────────────────────────
-- Student sees own payments; admin sees all
create policy "payments: select"
  on public.payments for select
  using (auth.uid() = student_id or public.is_admin());

-- Admin inserts payments (manual entry / webhook handler)
create policy "payments: insert"
  on public.payments for insert
  with check (public.is_admin() or auth.uid() = student_id);

-- Only admin can update status (e.g. mark completed / refunded)
create policy "payments: update"
  on public.payments for update
  using (public.is_admin());

create policy "payments: delete"
  on public.payments for delete
  using (public.is_admin());


-- ─────────────────────────────────────────────────────────────────
--  REFUND REQUESTS
-- ─────────────────────────────────────────────────────────────────
-- Student sees own; admin sees all
create policy "refund_requests: select"
  on public.refund_requests for select
  using (auth.uid() = student_id or public.is_admin());

-- Students submit their own refund requests
create policy "refund_requests: insert"
  on public.refund_requests for insert
  with check (auth.uid() = student_id);

-- Only admin can approve/reject
create policy "refund_requests: update"
  on public.refund_requests for update
  using (public.is_admin());

create policy "refund_requests: delete"
  on public.refund_requests for delete
  using (public.is_admin());


-- ─────────────────────────────────────────────────────────────────
--  LIVE CLASSES
-- ─────────────────────────────────────────────────────────────────
-- Enrolled students can read live classes for their batches;
-- teachers read their own; admin reads all.
create policy "live_classes: select"
  on public.live_classes for select
  using (
    public.is_admin()
    or auth.uid() = teacher_id
    or exists (
      select 1 from public.enrollments e
       where e.batch_id = live_classes.batch_id
         and e.student_id = auth.uid()
    )
  );

-- Only the owning teacher (or admin) may schedule a class
create policy "live_classes: insert"
  on public.live_classes for insert
  with check (auth.uid() = teacher_id or public.is_admin());

-- Only the owning teacher (or admin) may edit
create policy "live_classes: update"
  on public.live_classes for update
  using (auth.uid() = teacher_id or public.is_admin());

-- Only admin or owning teacher may delete
create policy "live_classes: delete"
  on public.live_classes for delete
  using (auth.uid() = teacher_id or public.is_admin());


-- ═══════════════════════════════════════════════════════════════════
--  REALTIME  (enable for tables that the app subscribes to)
-- ═══════════════════════════════════════════════════════════════════
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.announcements;
alter publication supabase_realtime add table public.doubts;
alter publication supabase_realtime add table public.doubt_replies;
alter publication supabase_realtime add table public.watch_progress;
alter publication supabase_realtime add table public.live_classes;


-- ═══════════════════════════════════════════════════════════════════
--  STORAGE BUCKETS
--  Run these separately in Supabase Dashboard → Storage
--  OR paste into SQL Editor — both work.
-- ═══════════════════════════════════════════════════════════════════
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('videos',          'videos',          false, 524288000,  array['video/mp4','video/webm','video/ogg']),
  ('lecture-videos',  'lecture-videos',  false, 524288000,  array['video/mp4','video/webm','video/ogg']),
  ('pdfs',            'pdfs',            false, 52428800,   array['application/pdf']),
  ('notes',           'notes',           false, 52428800,   array['application/pdf','image/jpeg','image/png']),
  ('doubt-images',    'doubt-images',    false, 10485760,   array['image/jpeg','image/png','image/webp']),
  ('profile-images',  'profile-images',  true,  5242880,    array['image/jpeg','image/png','image/webp']),
  ('thumbnails',      'thumbnails',      true,  5242880,    array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

-- Storage policies: authenticated read for private buckets
create policy "videos: authenticated read"
  on storage.objects for select
  using (bucket_id = 'videos' and auth.role() = 'authenticated');

create policy "lecture-videos: authenticated read"
  on storage.objects for select
  using (bucket_id = 'lecture-videos' and auth.role() = 'authenticated');

create policy "pdfs: authenticated read"
  on storage.objects for select
  using (bucket_id = 'pdfs' and auth.role() = 'authenticated');

create policy "notes: authenticated read"
  on storage.objects for select
  using (bucket_id = 'notes' and auth.role() = 'authenticated');

create policy "doubt-images: authenticated read"
  on storage.objects for select
  using (bucket_id = 'doubt-images' and auth.role() = 'authenticated');

-- Upload policies: only teachers/admins upload course content
create policy "videos: teacher upload"
  on storage.objects for insert
  with check (bucket_id in ('videos','lecture-videos','pdfs','notes') and public.is_teacher());

create policy "thumbnails: teacher upload"
  on storage.objects for insert
  with check (bucket_id = 'thumbnails' and public.is_teacher());

-- Students can upload doubt images and profile images
create policy "doubt-images: student upload"
  on storage.objects for insert
  with check (bucket_id = 'doubt-images' and auth.role() = 'authenticated');

create policy "profile-images: own upload"
  on storage.objects for insert
  with check (bucket_id = 'profile-images' and auth.role() = 'authenticated');


-- ═══════════════════════════════════════════════════════════════════
--  DONE ✓
--  After running this script:
--
--  1. Copy your Project URL & anon key from:
--       Supabase Dashboard → Settings → API
--
--  2. Paste them into:
--       lib/core/constants/app_constants.dart
--         supabaseUrl  = 'https://XXXX.supabase.co'
--         supabaseAnonKey = 'eyJhbGci...'
--
--  3. (Optional) Create a first admin user:
--       a. Sign up normally in the app
--       b. In Supabase → Table Editor → users
--          find the row and set role = 'admin'
-- ═══════════════════════════════════════════════════════════════════

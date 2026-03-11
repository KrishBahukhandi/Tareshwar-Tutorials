-- ═══════════════════════════════════════════════════════════
--  Tareshwar Tutorials  –  Supabase PostgreSQL Schema  v2
--
--  Learning Hierarchy:
--    Course → Batch → Subject → Chapter → Lecture
--
--  Roles:
--    student  – view enrolled content
--    teacher  – manage assigned courses
--    admin    – full platform control
--
--  Run in: Supabase Dashboard → SQL Editor
--  NOTE: Drop old tables first if migrating from v1.
-- ═══════════════════════════════════════════════════════════

-- ── Extensions ───────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ══════════════════════════════════════════════════════════════
--  1. USERS
-- ══════════════════════════════════════════════════════════════
create table public.users (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null,
  email       text not null unique,
  phone       text,
  role        text not null default 'student'
                check (role in ('student','teacher','admin')),
  avatar_url  text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now()
);

-- Trigger: auto-create public profile on auth signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', 'Student'),
    new.email,
    coalesce(new.raw_user_meta_data->>'role', 'student')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ══════════════════════════════════════════════════════════════
--  2. COURSES
--  A course is the top-level catalogue entry created by a teacher.
--  Students never enroll in a course directly – they enroll in
--  a *batch* that belongs to a course.
-- ══════════════════════════════════════════════════════════════
create table public.courses (
  id             uuid primary key default uuid_generate_v4(),
  title          text not null,
  description    text not null default '',
  teacher_id     uuid not null references public.users(id) on delete restrict,
  price          numeric(10,2) not null default 0,
  thumbnail_url  text,
  category_tag   text,
  is_published   boolean not null default false,
  -- Derived: how many lectures exist across ALL subjects/chapters
  total_lectures int generated always as (
    (select count(*)
       from public.lectures l
       join public.chapters ch on ch.id = l.chapter_id
       join public.subjects s  on s.id  = ch.subject_id
      where s.course_id = courses.id)
  ) stored,
  rating         numeric(3,2) default null,
  created_at     timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  3. BATCHES
--  Each batch is a scheduled cohort of a course (e.g.
--  "JEE 2025 Batch A"). Students enroll in batches, NOT courses.
-- ══════════════════════════════════════════════════════════════
create table public.batches (
  id            uuid primary key default uuid_generate_v4(),
  course_id     uuid not null references public.courses(id) on delete cascade,
  batch_name    text not null,
  description   text,
  start_date    date not null,
  end_date      date,
  max_students  int not null default 50,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  4. ENROLLMENTS
--  Student ↔ Batch (many-to-many via this join table).
-- ══════════════════════════════════════════════════════════════
create table public.enrollments (
  id               uuid primary key default uuid_generate_v4(),
  student_id       uuid not null references public.users(id) on delete cascade,
  batch_id         uuid not null references public.batches(id) on delete cascade,
  enrolled_at      timestamptz not null default now(),
  progress_percent numeric(5,2) not null default 0,
  unique(student_id, batch_id)
);

-- ══════════════════════════════════════════════════════════════
--  5. SUBJECTS
--  Subjects belong to a course. They may optionally be scoped
--  to a specific batch (batch_id = NULL means the subject is
--  shared across all batches of the course).
-- ══════════════════════════════════════════════════════════════
create table public.subjects (
  id          uuid primary key default uuid_generate_v4(),
  course_id   uuid not null references public.courses(id) on delete cascade,
  batch_id    uuid references public.batches(id) on delete cascade,  -- null = shared
  name        text not null,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  6. CHAPTERS
--  Chapters belong to a subject.
-- ══════════════════════════════════════════════════════════════
create table public.chapters (
  id          uuid primary key default uuid_generate_v4(),
  subject_id  uuid not null references public.subjects(id) on delete cascade,
  name        text not null,
  sort_order  int not null default 0,
  created_at  timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  7. LECTURES
--  Lectures belong to a chapter.
-- ══════════════════════════════════════════════════════════════
create table public.lectures (
  id                uuid primary key default uuid_generate_v4(),
  chapter_id        uuid not null references public.chapters(id) on delete cascade,
  title             text not null,
  description       text,
  video_url         text,
  notes_url         text,
  attachments       jsonb not null default '[]',
  duration_seconds  int,
  is_free           boolean not null default false,
  sort_order        int not null default 0,
  created_at        timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  8. WATCH PROGRESS
-- ══════════════════════════════════════════════════════════════
create table public.watch_progress (
  id               uuid primary key default uuid_generate_v4(),
  student_id       uuid not null references public.users(id) on delete cascade,
  lecture_id       uuid not null references public.lectures(id) on delete cascade,
  watched_seconds  int not null default 0,
  completed        boolean not null default false,
  updated_at       timestamptz not null default now(),
  unique(student_id, lecture_id)
);

-- ══════════════════════════════════════════════════════════════
--  9. TESTS
-- ══════════════════════════════════════════════════════════════
create table public.tests (
  id                uuid primary key default uuid_generate_v4(),
  chapter_id        uuid not null references public.chapters(id) on delete cascade,
  title             text not null,
  duration_minutes  int not null default 60,
  total_marks       int not null default 100,
  negative_marks    numeric(4,2) not null default 0.25,
  is_published      boolean not null default true,
  created_at        timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  10. QUESTIONS
-- ══════════════════════════════════════════════════════════════
create table public.questions (
  id                    uuid primary key default uuid_generate_v4(),
  test_id               uuid not null references public.tests(id) on delete cascade,
  question              text not null,
  question_image_url    text,
  options               text[] not null,
  correct_option_index  int not null,
  marks                 int not null default 4,
  explanation           text,
  created_at            timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  11. TEST ATTEMPTS
-- ══════════════════════════════════════════════════════════════
create table public.test_attempts (
  id                  uuid primary key default uuid_generate_v4(),
  test_id             uuid not null references public.tests(id) on delete cascade,
  student_id          uuid not null references public.users(id) on delete cascade,
  score               int not null,
  total_marks         int not null,
  correct_answers     int not null default 0,
  wrong_answers       int not null default 0,
  skipped             int not null default 0,
  time_taken_seconds  int not null default 0,
  answers             jsonb not null default '{}',
  attempted_at        timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  12. DOUBTS
-- ══════════════════════════════════════════════════════════════
create table public.doubts (
  id           uuid primary key default uuid_generate_v4(),
  student_id   uuid not null references public.users(id) on delete cascade,
  lecture_id   uuid references public.lectures(id) on delete set null,
  question     text not null,
  image_url    text,
  answer       text,
  answered_by  uuid references public.users(id) on delete set null,
  is_answered  boolean not null default false,
  reply_count  int not null default 0,
  created_at   timestamptz not null default now()
);

-- ── Doubt Replies ─────────────────────────────────────────────
create table public.doubt_replies (
  id           uuid primary key default uuid_generate_v4(),
  doubt_id     uuid not null references public.doubts(id) on delete cascade,
  author_id    uuid not null references public.users(id) on delete cascade,
  role         text not null default 'student' check (role in ('student','teacher','admin')),
  body         text not null,
  image_url    text,
  created_at   timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  13. NOTIFICATIONS
-- ══════════════════════════════════════════════════════════════
create table public.notifications (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid references public.users(id) on delete cascade,
  title        text not null,
  body         text not null,
  type         text not null check (type in ('lecture','test','announcement')),
  reference_id uuid,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  14. ANNOUNCEMENTS
--  Admin/teacher can broadcast messages to a batch or all users.
-- ══════════════════════════════════════════════════════════════
create table public.announcements (
  id          uuid primary key default uuid_generate_v4(),
  author_id   uuid not null references public.users(id) on delete cascade,
  batch_id    uuid references public.batches(id) on delete cascade,  -- null = platform-wide
  title       text not null,
  body        text not null,
  created_at  timestamptz not null default now()
);

-- ══════════════════════════════════════════════════════════════
--  15. LIVE CLASSES
--  Scheduled virtual/live sessions for a batch.
--  Status (upcoming | live | ended) is derived at app level
--  from start_time + duration_minutes.
-- ══════════════════════════════════════════════════════════════
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

-- ══════════════════════════════════════════════════════════════
--  INDEXES
-- ══════════════════════════════════════════════════════════════
create index idx_courses_teacher      on public.courses(teacher_id);
create index idx_batches_course       on public.batches(course_id);
create index idx_subjects_course      on public.subjects(course_id);
create index idx_subjects_batch       on public.subjects(batch_id);
create index idx_chapters_subject     on public.chapters(subject_id);
create index idx_lectures_chapter     on public.lectures(chapter_id);
create index idx_enrollments_student  on public.enrollments(student_id);
create index idx_enrollments_batch    on public.enrollments(batch_id);
create index idx_doubts_student       on public.doubts(student_id);
create index idx_doubts_lecture       on public.doubts(lecture_id);
create index idx_replies_doubt        on public.doubt_replies(doubt_id);
create index idx_attempts_test        on public.test_attempts(test_id);
create index idx_attempts_student     on public.test_attempts(student_id);
create index idx_watch_student        on public.watch_progress(student_id);
create index idx_notif_user           on public.notifications(user_id);
create index idx_announce_batch       on public.announcements(batch_id);
create index idx_live_classes_batch   on public.live_classes(batch_id);
create index idx_live_classes_teacher on public.live_classes(teacher_id);
create index idx_live_classes_start   on public.live_classes(start_time);

-- ══════════════════════════════════════════════════════════════
--  HELPER: is_admin()  &  is_teacher()
--  Used in RLS policies to avoid repeated sub-selects.
-- ══════════════════════════════════════════════════════════════
create or replace function public.is_admin()
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.users
     where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_teacher()
returns boolean language sql security definer stable as $$
  select exists (
    select 1 from public.users
     where id = auth.uid() and role in ('teacher','admin')
  );
$$;

-- ══════════════════════════════════════════════════════════════
--  ROW LEVEL SECURITY
-- ══════════════════════════════════════════════════════════════
alter table public.users          enable row level security;
alter table public.courses        enable row level security;
alter table public.batches        enable row level security;
alter table public.enrollments    enable row level security;
alter table public.subjects       enable row level security;
alter table public.chapters       enable row level security;
alter table public.lectures       enable row level security;
alter table public.watch_progress enable row level security;
alter table public.tests          enable row level security;
alter table public.questions      enable row level security;
alter table public.test_attempts  enable row level security;
alter table public.doubts         enable row level security;
alter table public.doubt_replies  enable row level security;
alter table public.notifications  enable row level security;
alter table public.announcements  enable row level security;
alter table public.live_classes   enable row level security;

-- ── USERS ─────────────────────────────────────────────────────
-- Every user can read and update their own profile.
-- Admins can read & update any profile.
create policy "users: own read"
  on public.users for select
  using (auth.uid() = id or public.is_admin());

create policy "users: own update"
  on public.users for update
  using (auth.uid() = id or public.is_admin());

create policy "users: admin insert"
  on public.users for insert
  with check (public.is_admin() or auth.uid() = id);

create policy "users: admin delete"
  on public.users for delete
  using (public.is_admin());

-- ── COURSES ───────────────────────────────────────────────────
-- Published courses are visible to everyone (for the catalogue).
-- Teachers can manage (CRUD) their own courses.
-- Admins can manage everything.
create policy "courses: published read"
  on public.courses for select
  using (is_published = true or auth.uid() = teacher_id or public.is_admin());

create policy "courses: teacher insert"
  on public.courses for insert
  with check (auth.uid() = teacher_id or public.is_admin());

create policy "courses: teacher update"
  on public.courses for update
  using (auth.uid() = teacher_id or public.is_admin());

create policy "courses: admin delete"
  on public.courses for delete
  using (auth.uid() = teacher_id or public.is_admin());

-- ── BATCHES ───────────────────────────────────────────────────
-- Teachers see batches for their courses; enrolled students see their batch.
create policy "batches: teacher/admin select"
  on public.batches for select
  using (
    public.is_admin()
    or exists (select 1 from public.courses c
               where c.id = batches.course_id and c.teacher_id = auth.uid())
    or exists (select 1 from public.enrollments e
               where e.batch_id = batches.id and e.student_id = auth.uid())
  );

create policy "batches: teacher insert"
  on public.batches for insert
  with check (
    public.is_admin()
    or exists (select 1 from public.courses c
               where c.id = course_id and c.teacher_id = auth.uid())
  );

create policy "batches: teacher update"
  on public.batches for update
  using (
    public.is_admin()
    or exists (select 1 from public.courses c
               where c.id = batches.course_id and c.teacher_id = auth.uid())
  );

create policy "batches: admin delete"
  on public.batches for delete
  using (public.is_admin());

-- ── ENROLLMENTS ───────────────────────────────────────────────
-- Students see their own enrollments; teachers see their batch's enrollments.
create policy "enrollments: own or teacher select"
  on public.enrollments for select
  using (
    auth.uid() = student_id
    or public.is_admin()
    or exists (
      select 1 from public.batches b
      join public.courses c on c.id = b.course_id
      where b.id = enrollments.batch_id and c.teacher_id = auth.uid()
    )
  );

create policy "enrollments: admin/teacher insert"
  on public.enrollments for insert
  with check (
    public.is_admin()
    or auth.uid() = student_id  -- student self-enroll (if allowed)
    or exists (
      select 1 from public.batches b
      join public.courses c on c.id = b.course_id
      where b.id = batch_id and c.teacher_id = auth.uid()
    )
  );

create policy "enrollments: admin delete"
  on public.enrollments for delete
  using (public.is_admin() or auth.uid() = student_id);

-- ── SUBJECTS ──────────────────────────────────────────────────
-- Only enrolled students (via batch→course) or the course teacher or admin.
create policy "subjects: enrolled or teacher select"
  on public.subjects for select
  using (
    public.is_admin()
    or exists (select 1 from public.courses c
               where c.id = subjects.course_id and c.teacher_id = auth.uid())
    or exists (
      select 1 from public.enrollments e
      join public.batches b on b.id = e.batch_id
      where e.student_id = auth.uid() and b.course_id = subjects.course_id
    )
  );

create policy "subjects: teacher write"
  on public.subjects for insert
  with check (
    public.is_admin()
    or exists (select 1 from public.courses c
               where c.id = course_id and c.teacher_id = auth.uid())
  );

create policy "subjects: teacher update"
  on public.subjects for update
  using (
    public.is_admin()
    or exists (select 1 from public.courses c
               where c.id = subjects.course_id and c.teacher_id = auth.uid())
  );

create policy "subjects: teacher delete"
  on public.subjects for delete
  using (
    public.is_admin()
    or exists (select 1 from public.courses c
               where c.id = subjects.course_id and c.teacher_id = auth.uid())
  );

-- ── CHAPTERS ──────────────────────────────────────────────────
create policy "chapters: enrolled or teacher select"
  on public.chapters for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.subjects s
      join public.courses c on c.id = s.course_id
      where s.id = chapters.subject_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.subjects s
      join public.enrollments e on true
      join public.batches b on b.id = e.batch_id
      where s.id = chapters.subject_id
        and e.student_id = auth.uid()
        and b.course_id = s.course_id
    )
  );

create policy "chapters: teacher write"
  on public.chapters for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.subjects s
      join public.courses c on c.id = s.course_id
      where s.id = subject_id and c.teacher_id = auth.uid()
    )
  );

create policy "chapters: teacher update/delete"
  on public.chapters for update
  using (
    public.is_admin()
    or exists (
      select 1 from public.subjects s
      join public.courses c on c.id = s.course_id
      where s.id = chapters.subject_id and c.teacher_id = auth.uid()
    )
  );

-- ── LECTURES ──────────────────────────────────────────────────
create policy "lectures: free or enrolled or teacher"
  on public.lectures for select
  using (
    is_free = true
    or public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join public.subjects s on s.id = ch.subject_id
      join public.courses c on c.id = s.course_id
      where ch.id = lectures.chapter_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.chapters ch
      join public.subjects s on s.id = ch.subject_id
      join public.enrollments e on true
      join public.batches b on b.id = e.batch_id
      where ch.id = lectures.chapter_id
        and e.student_id = auth.uid()
        and b.course_id = s.course_id
    )
  );

create policy "lectures: teacher write"
  on public.lectures for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join public.subjects s on s.id = ch.subject_id
      join public.courses c on c.id = s.course_id
      where ch.id = chapter_id and c.teacher_id = auth.uid()
    )
  );

create policy "lectures: teacher update"
  on public.lectures for update
  using (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join public.subjects s on s.id = ch.subject_id
      join public.courses c on c.id = s.course_id
      where ch.id = lectures.chapter_id and c.teacher_id = auth.uid()
    )
  );

-- ── WATCH PROGRESS ────────────────────────────────────────────
create policy "watch_progress: own all"
  on public.watch_progress for all
  using (auth.uid() = student_id);

-- ── TESTS ─────────────────────────────────────────────────────
create policy "tests: enrolled or teacher select"
  on public.tests for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join public.subjects s on s.id = ch.subject_id
      join public.courses c on c.id = s.course_id
      where ch.id = tests.chapter_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.chapters ch
      join public.subjects s on s.id = ch.subject_id
      join public.enrollments e on true
      join public.batches b on b.id = e.batch_id
      where ch.id = tests.chapter_id
        and e.student_id = auth.uid()
        and b.course_id = s.course_id
        and tests.is_published = true
    )
  );

create policy "tests: teacher write"
  on public.tests for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join public.subjects s on s.id = ch.subject_id
      join public.courses c on c.id = s.course_id
      where ch.id = chapter_id and c.teacher_id = auth.uid()
    )
  );

-- ── QUESTIONS ─────────────────────────────────────────────────
create policy "questions: enrolled or teacher select"
  on public.questions for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.tests t
      join public.chapters ch on ch.id = t.chapter_id
      join public.subjects s on s.id = ch.subject_id
      join public.courses c on c.id = s.course_id
      where t.id = questions.test_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.tests t
      join public.chapters ch on ch.id = t.chapter_id
      join public.subjects s on s.id = ch.subject_id
      join public.enrollments e on true
      join public.batches b on b.id = e.batch_id
      where t.id = questions.test_id
        and e.student_id = auth.uid()
        and b.course_id = s.course_id
    )
  );

create policy "questions: teacher write"
  on public.questions for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.tests t
      join public.chapters ch on ch.id = t.chapter_id
      join public.subjects s on s.id = ch.subject_id
      join public.courses c on c.id = s.course_id
      where t.id = test_id and c.teacher_id = auth.uid()
    )
  );

-- ── TEST ATTEMPTS ─────────────────────────────────────────────
create policy "test_attempts: own or teacher select"
  on public.test_attempts for select
  using (
    auth.uid() = student_id
    or public.is_admin()
    or exists (
      select 1 from public.tests t
      join public.chapters ch on ch.id = t.chapter_id
      join public.subjects s on s.id = ch.subject_id
      join public.courses c on c.id = s.course_id
      where t.id = test_attempts.test_id and c.teacher_id = auth.uid()
    )
  );

create policy "test_attempts: own insert"
  on public.test_attempts for insert
  with check (auth.uid() = student_id);

-- ── DOUBTS ────────────────────────────────────────────────────
create policy "doubts: own or teacher select"
  on public.doubts for select
  using (
    auth.uid() = student_id
    or public.is_teacher()
    or public.is_admin()
  );

create policy "doubts: student insert"
  on public.doubts for insert
  with check (auth.uid() = student_id);

create policy "doubts: teacher update (answer)"
  on public.doubts for update
  using (public.is_teacher() or public.is_admin());

-- ── DOUBT REPLIES ─────────────────────────────────────────────
create policy "doubt_replies: participants select"
  on public.doubt_replies for select
  using (
    public.is_teacher()
    or exists (select 1 from public.doubts d
               where d.id = doubt_replies.doubt_id
                 and d.student_id = auth.uid())
  );

create policy "doubt_replies: insert own"
  on public.doubt_replies for insert
  with check (auth.uid() = author_id);

-- ── NOTIFICATIONS ─────────────────────────────────────────────
create policy "notifications: own or broadcast"
  on public.notifications for select
  using (user_id = auth.uid() or user_id is null);

create policy "notifications: admin/teacher insert"
  on public.notifications for insert
  with check (public.is_teacher() or public.is_admin());

create policy "notifications: own update (mark read)"
  on public.notifications for update
  using (user_id = auth.uid());

-- ── ANNOUNCEMENTS ─────────────────────────────────────────────
create policy "announcements: enrolled or all select"
  on public.announcements for select
  using (
    batch_id is null   -- platform-wide
    or public.is_admin()
    or public.is_teacher()
    or exists (select 1 from public.enrollments e
               where e.batch_id = announcements.batch_id
                 and e.student_id = auth.uid())
  );

create policy "announcements: teacher insert"
  on public.announcements for insert
  with check (auth.uid() = author_id and public.is_teacher());

-- ── LIVE CLASSES ──────────────────────────────────────────────
-- Enrolled students see their batch's classes; teacher sees own; admin sees all.
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

create policy "live_classes: insert"
  on public.live_classes for insert
  with check (auth.uid() = teacher_id or public.is_admin());

create policy "live_classes: update"
  on public.live_classes for update
  using (auth.uid() = teacher_id or public.is_admin());

create policy "live_classes: delete"
  on public.live_classes for delete
  using (auth.uid() = teacher_id or public.is_admin());

-- ══════════════════════════════════════════════════════════════
--  STORAGE BUCKETS  (run in Supabase Storage settings)
-- ══════════════════════════════════════════════════════════════
-- insert into storage.buckets (id, name, public) values
--   ('videos',          'videos',          false),
--   ('pdfs',            'pdfs',            false),
--   ('doubt-images',    'doubt-images',    false),
--   ('profile-images',  'profile-images',  true),
--   ('thumbnails',      'thumbnails',      true);

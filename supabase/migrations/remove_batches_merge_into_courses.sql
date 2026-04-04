-- ═══════════════════════════════════════════════════════════════
--  remove_batches_merge_into_courses.sql
--
--  Merges the Batch concept into Course.
--  Courses now carry: class_level, max_students, start_date,
--  end_date, subjects_overview, is_active (all formerly on batches).
--  Students enroll directly into courses (enrollments.course_id).
--
--  Run order:
--    1. Add new columns to courses
--    2. Add new trigger to maintain enrolled_count on courses
--    3. Migrate enrollments: add course_id, backfill via batches
--    4. Remove batch_id from subjects, announcements
--    5. Update live_classes: batch_id → course_id
--    6. Drop batches table
--    7. Drop old RLS policies; add new ones
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────────────────────
--  STEP 1 — New columns on courses
-- ─────────────────────────────────────────────────────────────
alter table public.courses
  add column if not exists class_level       text,          -- 'Class 8'..'Class 12'
  add column if not exists max_students      int  not null default 50,
  add column if not exists start_date        date,
  add column if not exists end_date          date,
  add column if not exists subjects_overview text[] not null default '{}',
  add column if not exists is_active         boolean not null default true;

-- enrolled_count replaces total_students (same semantic, cleaner name)
-- Keep total_students as alias for backwards compat with existing queries.
-- We'll maintain both via trigger. Only add if not already present.
alter table public.courses
  add column if not exists enrolled_count int not null default 0;

-- Sync enrolled_count = total_students on existing rows
update public.courses set enrolled_count = coalesce(total_students, 0);

-- ─────────────────────────────────────────────────────────────
--  STEP 2 — Trigger to auto-maintain enrolled_count on courses
--           (replaces the old batch-based total_students trigger)
-- ─────────────────────────────────────────────────────────────
create or replace function public.refresh_course_enrolled_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_course_id uuid;
begin
  if (tg_op = 'DELETE') then
    v_course_id := old.course_id;
  else
    v_course_id := new.course_id;
  end if;

  if v_course_id is not null then
    update public.courses
       set enrolled_count  = (
             select count(*)::int
               from public.enrollments
              where course_id = v_course_id
           ),
           total_students  = (
             select count(*)::int
               from public.enrollments
              where course_id = v_course_id
           )
     where id = v_course_id;
  end if;

  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_course_enrolled_count on public.enrollments;
create trigger trg_course_enrolled_count
  after insert or delete on public.enrollments
  for each row execute function public.refresh_course_enrolled_count();

-- ─────────────────────────────────────────────────────────────
--  STEP 3 — Migrate enrollments: course_id direct FK
-- ─────────────────────────────────────────────────────────────

-- 3a. Add course_id column (nullable during migration)
alter table public.enrollments
  add column if not exists course_id uuid references public.courses(id) on delete cascade;

-- 3b. Backfill course_id from batches join (if batches table still exists)
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema = 'public' and table_name = 'batches') then
    update public.enrollments e
       set course_id = b.course_id
      from public.batches b
     where b.id = e.batch_id
       and e.course_id is null;
  end if;
end$$;

-- 3c. Make course_id non-nullable now that it's backfilled
-- (If any rows are still null from orphaned batches, point them nowhere — delete them)
delete from public.enrollments where course_id is null;
alter table public.enrollments alter column course_id set not null;

-- 3d. Drop ALL old RLS policies that reference batch_id before dropping the column.
--     (Policies on enrollments AND any cross-table policies that join through batch_id)
drop policy if exists "enrollments: select"               on public.enrollments;
drop policy if exists "enrollments: insert"               on public.enrollments;
drop policy if exists "enrollments: update"               on public.enrollments;
drop policy if exists "enrollments: delete"               on public.enrollments;
drop policy if exists "enrollments: admin/teacher insert"  on public.enrollments;
drop policy if exists "enrollments: admin delete"          on public.enrollments;
drop policy if exists "subjects: select"                   on public.subjects;
drop policy if exists "chapters: select"                   on public.chapters;
drop policy if exists "lectures: select"                   on public.lectures;
drop policy if exists "tests: select"                      on public.tests;
drop policy if exists "questions: select"                  on public.questions;
drop policy if exists "announcements: select"              on public.announcements;
drop policy if exists "live_classes: select"               on public.live_classes;
drop policy if exists "live_classes: insert"               on public.live_classes;
drop policy if exists "live_classes: update"               on public.live_classes;
drop policy if exists "live_classes: delete"               on public.live_classes;
drop policy if exists "watch_progress: teacher read"       on public.watch_progress;

-- 3e. Add unique constraint: one enrollment per student per course
alter table public.enrollments
  drop constraint if exists enrollments_student_id_batch_id_key;
alter table public.enrollments
  add constraint enrollments_student_id_course_id_key
  unique (student_id, course_id);

-- 3f. Now safe to drop the old batch_id column
alter table public.enrollments drop column if exists batch_id;

-- ─────────────────────────────────────────────────────────────
--  STEP 4 — Clean up subjects: remove batch_id
-- ─────────────────────────────────────────────────────────────
alter table public.subjects drop column if exists batch_id;

-- ─────────────────────────────────────────────────────────────
--  STEP 5 — Announcements: batch_id → course_id (nullable)
-- ─────────────────────────────────────────────────────────────
alter table public.announcements
  add column if not exists course_id uuid references public.courses(id) on delete cascade;

-- Backfill course_id from batch_id (via batches)
do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema = 'public' and table_name = 'batches')
     and exists (select 1 from information_schema.columns
                 where table_schema = 'public'
                   and table_name   = 'announcements'
                   and column_name  = 'batch_id') then
    update public.announcements a
       set course_id = b.course_id
      from public.batches b
     where b.id = a.batch_id;
  end if;
end$$;

alter table public.announcements drop column if exists batch_id;

-- ─────────────────────────────────────────────────────────────
--  STEP 6 — live_classes: batch_id → course_id
-- ─────────────────────────────────────────────────────────────
alter table public.live_classes
  add column if not exists course_id uuid references public.courses(id) on delete cascade;

do $$
begin
  if exists (select 1 from information_schema.tables
             where table_schema = 'public' and table_name = 'batches')
     and exists (select 1 from information_schema.columns
                 where table_schema = 'public'
                   and table_name   = 'live_classes'
                   and column_name  = 'batch_id') then
    update public.live_classes lc
       set course_id = b.course_id
      from public.batches b
     where b.id = lc.batch_id;
  end if;
end$$;

-- Make non-nullable (delete orphaned rows)
delete from public.live_classes where course_id is null;
alter table public.live_classes alter column course_id set not null;
alter table public.live_classes drop column if exists batch_id;

-- ─────────────────────────────────────────────────────────────
--  STEP 7 — Drop the batches table
-- ─────────────────────────────────────────────────────────────
drop table if exists public.batches cascade;

-- ─────────────────────────────────────────────────────────────
--  STEP 8 — Indexes
-- ─────────────────────────────────────────────────────────────
create index if not exists idx_enrollments_course    on public.enrollments(course_id);
create index if not exists idx_enrollments_student   on public.enrollments(student_id);
create index if not exists idx_live_classes_course   on public.live_classes(course_id);
create index if not exists idx_courses_class_level   on public.courses(class_level);
create index if not exists idx_courses_is_active     on public.courses(is_active);

-- ─────────────────────────────────────────────────────────────
--  STEP 9 — Remove old batch-referencing helper functions
-- ─────────────────────────────────────────────────────────────
drop function if exists public.teacher_owns_batch(uuid);
drop function if exists public.student_enrolled_in_batch(uuid);

-- ─────────────────────────────────────────────────────────────
--  STEP 10 — New helper: check if student is enrolled in course
-- ─────────────────────────────────────────────────────────────
create or replace function public.student_enrolled_in_course(target_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.enrollments
    where course_id  = target_course_id
      and student_id = auth.uid()
  );
$$;

create or replace function public.teacher_owns_course(target_course_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.courses
    where id         = target_course_id
      and teacher_id = auth.uid()
  );
$$;

-- ─────────────────────────────────────────────────────────────
--  STEP 11 — Drop all old batch-referencing RLS policies
--             and recreate clean ones
-- ─────────────────────────────────────────────────────────────

-- ENROLLMENTS (policies were already dropped in step 3d above)
create policy "enrollments: select"
  on public.enrollments for select
  using (
    auth.uid() = student_id
    or public.is_admin()
    or public.teacher_owns_course(course_id)
  );

create policy "enrollments: insert"
  on public.enrollments for insert
  with check (
    public.is_admin()
    or public.teacher_owns_course(course_id)
  );

create policy "enrollments: update"
  on public.enrollments for update
  using (
    auth.uid() = student_id
    or public.is_admin()
    or public.teacher_owns_course(course_id)
  );

create policy "enrollments: delete"
  on public.enrollments for delete
  using (
    public.is_admin()
    or public.teacher_owns_course(course_id)
  );

-- SUBJECTS (removed batch_id; now just course-scoped)
create policy "subjects: select"
  on public.subjects for select
  using (
    public.is_admin()
    or exists (
      select 1 from public.courses c
       where c.id = subjects.course_id and c.teacher_id = auth.uid()
    )
    or public.student_enrolled_in_course(subjects.course_id)
  );

-- ANNOUNCEMENTS (now course-scoped instead of batch-scoped)
create policy "announcements: select"
  on public.announcements for select
  using (
    public.is_admin()
    or course_id is null   -- platform-wide
    or public.student_enrolled_in_course(course_id)
    or public.teacher_owns_course(course_id)
  );

-- LIVE CLASSES (now course-scoped)
create policy "live_classes: select"
  on public.live_classes for select
  using (
    public.is_admin()
    or auth.uid() = teacher_id
    or public.student_enrolled_in_course(course_id)
  );

create policy "live_classes: insert"
  on public.live_classes for insert
  with check (
    public.is_admin()
    or (auth.uid() = teacher_id and public.teacher_owns_course(course_id))
  );

create policy "live_classes: update"
  on public.live_classes for update
  using (public.is_admin() or auth.uid() = teacher_id);

create policy "live_classes: delete"
  on public.live_classes for delete
  using (public.is_admin() or auth.uid() = teacher_id);

-- CHAPTERS & LECTURES — update the student enrollment check
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
       where s.id = chapters.subject_id
         and public.student_enrolled_in_course(s.course_id)
    )
  );

create policy "lectures: select"
  on public.lectures for select
  using (
    is_free = true
    or public.is_admin()
    or exists (
      select 1 from public.chapters ch
      join  public.subjects s on s.id = ch.subject_id
      join  public.courses c  on c.id = s.course_id
       where ch.id = lectures.chapter_id and c.teacher_id = auth.uid()
    )
    or exists (
      select 1 from public.chapters ch
      join  public.subjects s on s.id = ch.subject_id
       where ch.id = lectures.chapter_id
         and public.student_enrolled_in_course(s.course_id)
    )
  );

-- TESTS (was batch-scoped, now uses student_enrolled_in_course)
drop policy if exists "tests: select" on public.tests;

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
      join  public.subjects s on s.id = ch.subject_id
       where ch.id = tests.chapter_id
         and tests.is_published = true
         and public.student_enrolled_in_course(s.course_id)
    )
  );

-- QUESTIONS (was batch-scoped, now uses student_enrolled_in_course)
drop policy if exists "questions: select" on public.questions;

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
      join  public.chapters ch on ch.id = t.chapter_id
      join  public.subjects  s on  s.id = ch.subject_id
       where t.id = questions.test_id
         and public.student_enrolled_in_course(s.course_id)
    )
  );

-- WATCH_PROGRESS: teacher read (was batch-scoped, now uses course_id directly)
create policy "watch_progress: teacher read"
  on public.watch_progress for select
  using (
    public.is_teacher()
    and exists (
      select 1
        from public.enrollments e
        join public.courses     c on c.id = e.course_id
       where e.student_id = watch_progress.student_id
         and c.teacher_id = auth.uid()
    )
  );

-- ─────────────────────────────────────────────────────────────
--  STEP 12 — Refresh enrolled_count for all courses from
--             current enrollment data (post-migration sync)
-- ─────────────────────────────────────────────────────────────
update public.courses c
   set enrolled_count = (
         select count(*)::int from public.enrollments e
          where e.course_id = c.id
       ),
       total_students  = (
         select count(*)::int from public.enrollments e
          where e.course_id = c.id
       );

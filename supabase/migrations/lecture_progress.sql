-- ═══════════════════════════════════════════════════════════════════
--  MIGRATION: lecture_progress  (alias: watch_progress)
--
--  The `watch_progress` table already exists from the base schema.
--  This migration:
--    1. Ensures the table and all columns exist (idempotent via IF NOT EXISTS)
--    2. Adds any missing columns to existing installations
--    3. Creates/refreshes the updated_at trigger
--    4. Creates/refreshes indexes
--    5. Enables RLS and (re)creates all policies
--    6. Adds the table to realtime
--
--  Safe to run on a fresh DB OR on top of the base schema.
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. Ensure table exists ────────────────────────────────────────
--  The canonical name is `watch_progress` (matches the Flutter service).
--  If your project still uses `lecture_progress`, create it as an alias
--  or rename – this migration normalises to `watch_progress`.
create table if not exists public.watch_progress (
  id               uuid        primary key default uuid_generate_v4(),
  student_id       uuid        not null references public.users(id)    on delete cascade,
  lecture_id       uuid        not null references public.lectures(id) on delete cascade,
  watched_seconds  int         not null default 0,
  completed        boolean     not null default false,
  updated_at       timestamptz not null default now(),
  unique(student_id, lecture_id)
);

-- ── 2. Add missing columns to existing installations ─────────────
-- (safe no-ops when columns already exist)
alter table public.watch_progress
  add column if not exists id               uuid        default uuid_generate_v4(),
  add column if not exists watched_seconds  int         not null default 0,
  add column if not exists completed        boolean     not null default false,
  add column if not exists updated_at       timestamptz not null default now();

-- ── 3. Auto-update updated_at ─────────────────────────────────────
drop trigger if exists trg_watch_progress_updated_at on public.watch_progress;
create trigger trg_watch_progress_updated_at
  before update on public.watch_progress
  for each row execute function public.update_updated_at();

-- ── 4. Indexes ────────────────────────────────────────────────────
create index if not exists idx_watch_progress_student
  on public.watch_progress(student_id);

create index if not exists idx_watch_progress_lecture
  on public.watch_progress(lecture_id);

-- Composite: most common query pattern
create index if not exists idx_watch_progress_student_lecture
  on public.watch_progress(student_id, lecture_id);

-- For "continue learning" – find most recently watched lecture
create index if not exists idx_watch_progress_updated
  on public.watch_progress(student_id, updated_at desc);

-- ── 5. Row Level Security ─────────────────────────────────────────
alter table public.watch_progress enable row level security;

drop policy if exists "watch_progress: own select"   on public.watch_progress;
drop policy if exists "watch_progress: own upsert"   on public.watch_progress;
drop policy if exists "watch_progress: teacher read" on public.watch_progress;
drop policy if exists "watch_progress: admin read"   on public.watch_progress;
drop policy if exists "watch_progress: own delete"   on public.watch_progress;

-- Students can read and write their own progress rows
create policy "watch_progress: own select"
  on public.watch_progress for select
  using (auth.uid() = student_id or public.is_admin());

create policy "watch_progress: own upsert"
  on public.watch_progress for insert
  with check (auth.uid() = student_id);

create policy "watch_progress: own update"
  on public.watch_progress for update
  using (auth.uid() = student_id);

-- Teachers can read progress for students enrolled in their batches
create policy "watch_progress: teacher read"
  on public.watch_progress for select
  using (
    public.is_teacher()
    and exists (
      select 1
        from public.enrollments  e
        join public.batches      b on b.id = e.batch_id
        join public.courses      c on c.id = b.course_id
       where e.student_id = watch_progress.student_id
         and c.teacher_id = auth.uid()
    )
  );

create policy "watch_progress: own delete"
  on public.watch_progress for delete
  using (auth.uid() = student_id or public.is_admin());

-- ── 6. Realtime subscription ──────────────────────────────────────
-- Allows the Flutter app to receive live progress updates.
-- (Fails silently if the table is already published.)
do $$
begin
  alter publication supabase_realtime add table public.watch_progress;
exception when others then
  -- Already in publication – ignore
end;
$$;

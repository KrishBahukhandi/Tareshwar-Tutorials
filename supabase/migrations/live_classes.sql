-- ═══════════════════════════════════════════════════════════════════
--  MIGRATION: live_classes
--  Adds the live_classes table, indexes, RLS, and realtime subscription.
--
--  Run in: Supabase Dashboard → SQL Editor
--  Safe to run multiple times (idempotent via IF NOT EXISTS / IF EXISTS).
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. Table ──────────────────────────────────────────────────────
create table if not exists public.live_classes (
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

-- ── 2. Auto-update updated_at on every write ──────────────────────
-- Reuse the generic update_updated_at() function (already in schema).
drop trigger if exists trg_live_classes_updated_at on public.live_classes;
create trigger trg_live_classes_updated_at
  before update on public.live_classes
  for each row execute function public.update_updated_at();

-- ── 3. Indexes ────────────────────────────────────────────────────
create index if not exists idx_live_classes_batch
  on public.live_classes(batch_id);

create index if not exists idx_live_classes_teacher
  on public.live_classes(teacher_id);

create index if not exists idx_live_classes_start
  on public.live_classes(start_time);

-- ── 4. Row Level Security ─────────────────────────────────────────
alter table public.live_classes enable row level security;

-- Drop existing policies (idempotent)
drop policy if exists "live_classes: select" on public.live_classes;
drop policy if exists "live_classes: insert" on public.live_classes;
drop policy if exists "live_classes: update" on public.live_classes;
drop policy if exists "live_classes: delete" on public.live_classes;

-- Enrolled students can see their batch's classes;
-- owning teacher can see / manage their own; admin sees all.
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

-- Only the owning teacher (or admin) may schedule a new class
create policy "live_classes: insert"
  on public.live_classes for insert
  with check (auth.uid() = teacher_id or public.is_admin());

-- Only the owning teacher (or admin) may edit details
create policy "live_classes: update"
  on public.live_classes for update
  using (auth.uid() = teacher_id or public.is_admin());

-- Only the owning teacher (or admin) may delete
create policy "live_classes: delete"
  on public.live_classes for delete
  using (auth.uid() = teacher_id or public.is_admin());

-- ── 5. Realtime subscription ──────────────────────────────────────
-- Allows Flutter Supabase client to stream changes in real time.
alter publication supabase_realtime add table public.live_classes;

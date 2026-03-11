-- ═══════════════════════════════════════════════════════════
--  Migration: announcements_push_sent.sql
--
--  Adds push_sent column to announcements table and updates
--  RLS policies to allow full admin control.
--
--  Run in: Supabase Dashboard → SQL Editor
-- ═══════════════════════════════════════════════════════════

-- ── 1. Add push_sent column (idempotent) ─────────────────────
alter table public.announcements
  add column if not exists push_sent boolean not null default false;

-- ── 2. RLS policies ──────────────────────────────────────────

-- Admins can select all announcements
drop policy if exists "announcements: admin full select" on public.announcements;
create policy "announcements: admin full select"
  on public.announcements for select
  using (public.is_admin());

-- Admins can insert announcements
drop policy if exists "announcements: admin insert" on public.announcements;
create policy "announcements: admin insert"
  on public.announcements for insert
  with check (public.is_admin());

-- Admins can update (e.g. set push_sent = true)
drop policy if exists "announcements: admin update" on public.announcements;
create policy "announcements: admin update"
  on public.announcements for update
  using (public.is_admin());

-- Admins can delete announcements
drop policy if exists "announcements: admin delete" on public.announcements;
create policy "announcements: admin delete"
  on public.announcements for delete
  using (public.is_admin());

-- Students/teachers can read announcements they are eligible for:
--   Platform-wide (batch_id IS NULL) OR enrolled in the batch
drop policy if exists "announcements: enrolled or all select" on public.announcements;
create policy "announcements: enrolled or all select"
  on public.announcements for select
  using (
    batch_id is null
    or exists (
      select 1 from public.enrollments e
       where e.student_id = auth.uid()
         and e.batch_id   = announcements.batch_id
    )
  );

-- ── 3. Index on push_sent for efficient querying ─────────────
create index if not exists idx_announce_push_sent
  on public.announcements(push_sent);

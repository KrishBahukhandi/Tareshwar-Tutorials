-- ─────────────────────────────────────────────────────────────
--  fix_batches_rls_recursion.sql
--
--  Problem: infinite recursion (code 42P17) when querying batches.
--
--  Root cause — circular RLS dependency:
--    • "batches: select" policy contains a raw subquery on `enrollments`
--    • "enrollments: select" policy contains a raw subquery on `batches`
--    → PostgreSQL detects the cycle and raises 42P17 before any
--      OR short-circuit evaluation can prevent it.
--
--  Fix: wrap the enrollment-membership check inside a SECURITY DEFINER
--  function. SECURITY DEFINER functions bypass RLS, so when the
--  batches policy calls student_enrolled_in_batch() the inner query
--  on enrollments never triggers the enrollments RLS policy, breaking
--  the cycle entirely.
-- ─────────────────────────────────────────────────────────────

-- 1. Helper: check whether the current user is enrolled in a batch
--    without touching RLS (SECURITY DEFINER bypasses row-level security).
create or replace function public.student_enrolled_in_batch(target_batch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.enrollments
    where batch_id   = target_batch_id
      and student_id = auth.uid()
  );
$$;

-- 2. Replace the batches select policy with a version that uses the
--    helper instead of a raw correlated subquery on enrollments.
drop policy if exists "batches: select" on public.batches;

create policy "batches: select"
  on public.batches for select
  using (
    -- admin always sees everything
    public.is_admin()
    -- teacher sees batches for their own courses
    or exists (
      select 1 from public.courses c
       where c.id = batches.course_id
         and c.teacher_id = auth.uid()
    )
    -- enrolled student sees their batch (via SECURITY DEFINER — no RLS recursion)
    or public.student_enrolled_in_batch(batches.id)
  );

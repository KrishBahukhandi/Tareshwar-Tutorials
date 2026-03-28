-- ─────────────────────────────────────────────────────────────
--  audit_logs.sql
--  Basic admin audit trail for production support.
-- ─────────────────────────────────────────────────────────────

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references public.users(id) on delete set null,
  actor_role text not null default 'admin',
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_audit_logs_actor_id on public.audit_logs(actor_id);
create index if not exists idx_audit_logs_action on public.audit_logs(action);
create index if not exists idx_audit_logs_created_at on public.audit_logs(created_at desc);

alter table public.audit_logs enable row level security;

drop policy if exists "audit_logs: admin read" on public.audit_logs;
create policy "audit_logs: admin read"
  on public.audit_logs for select
  using (public.is_admin());

drop policy if exists "audit_logs: admin insert" on public.audit_logs;
create policy "audit_logs: admin insert"
  on public.audit_logs for insert
  with check (public.is_admin());

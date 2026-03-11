-- ═══════════════════════════════════════════════════════════════════
--  MIGRATION: analytics_events
--
--  Stores platform-wide behavioural events fired from the Flutter app:
--    lecture_started  | lecture_completed
--    test_attempted   | course_completed
--    live_class_joined
--
--  Schema:
--    id          – UUID PK
--    user_id     – FK → users (nullable: anonymous future support)
--    event_type  – enum-like text, indexed
--    event_data  – JSONB arbitrary payload
--    created_at  – auto timestamp, indexed
--
--  Safe to run on fresh DB OR on top of existing schema.
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. Table ──────────────────────────────────────────────────────
create table if not exists public.analytics_events (
  id          uuid        primary key default uuid_generate_v4(),
  user_id     uuid        references public.users(id) on delete set null,
  event_type  text        not null,
  event_data  jsonb       not null default '{}',
  created_at  timestamptz not null default now()
);

-- ── 2. Indexes ────────────────────────────────────────────────────
-- Fast lookup by user
create index if not exists idx_analytics_user
  on public.analytics_events(user_id);

-- Fast lookup by event type (for admin aggregations)
create index if not exists idx_analytics_event_type
  on public.analytics_events(event_type);

-- Time-series queries (dashboards, charts)
create index if not exists idx_analytics_created_at
  on public.analytics_events(created_at desc);

-- Composite: event_type + time (most common admin query pattern)
create index if not exists idx_analytics_type_time
  on public.analytics_events(event_type, created_at desc);

-- GIN index on JSONB payload for flexible filtering
create index if not exists idx_analytics_event_data
  on public.analytics_events using gin(event_data);

-- ── 3. Row Level Security ─────────────────────────────────────────
alter table public.analytics_events enable row level security;

drop policy if exists "analytics: insert own"   on public.analytics_events;
drop policy if exists "analytics: admin read"   on public.analytics_events;
drop policy if exists "analytics: own read"     on public.analytics_events;

-- Any authenticated user can insert their own events
create policy "analytics: insert own"
  on public.analytics_events for insert
  with check (auth.uid() = user_id or user_id is null);

-- Students can read their own events (for personal analytics)
create policy "analytics: own read"
  on public.analytics_events for select
  using (auth.uid() = user_id);

-- Admins and teachers can read all events
create policy "analytics: admin read"
  on public.analytics_events for select
  using (public.is_admin() or public.is_teacher());

-- ── 4. Realtime ───────────────────────────────────────────────────
do $$
begin
  alter publication supabase_realtime add table public.analytics_events;
exception when others then null;
end;
$$;

-- ── 5. Convenience views for admin dashboards ─────────────────────

-- Daily event counts (last 30 days) – used by activity chart
create or replace view public.v_daily_event_counts as
select
  date_trunc('day', created_at at time zone 'UTC') as day,
  event_type,
  count(*) as event_count
from public.analytics_events
where created_at >= now() - interval '30 days'
group by 1, 2
order by 1 desc;

-- Per-event totals (all time)
create or replace view public.v_event_totals as
select
  event_type,
  count(*)                                               as total,
  count(*) filter (where created_at >= now() - interval '7 days')  as last_7d,
  count(*) filter (where created_at >= now() - interval '30 days') as last_30d
from public.analytics_events
group by event_type
order by total desc;

-- Top 10 most-watched lectures
create or replace view public.v_top_lectures as
select
  (event_data->>'lecture_id')  as lecture_id,
  (event_data->>'lecture_title') as lecture_title,
  count(*)                     as start_count,
  count(*) filter (
    where event_type = 'lecture_completed'
  )                            as completed_count
from public.analytics_events
where event_type in ('lecture_started', 'lecture_completed')
  and event_data->>'lecture_id' is not null
group by 1, 2
order by start_count desc
limit 10;

-- Top 10 most-attempted tests
create or replace view public.v_top_tests as
select
  (event_data->>'test_id')    as test_id,
  (event_data->>'test_title') as test_title,
  count(*)                    as attempt_count,
  avg((event_data->>'score')::numeric) as avg_score
from public.analytics_events
where event_type = 'test_attempted'
  and event_data->>'test_id' is not null
group by 1, 2
order by attempt_count desc
limit 10;

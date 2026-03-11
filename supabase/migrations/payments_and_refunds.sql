-- ─────────────────────────────────────────────────────────────
--  payments_and_refunds.sql
--  Creates payments and refund_requests tables with RLS.
-- ─────────────────────────────────────────────────────────────

-- ── payments ──────────────────────────────────────────────────
create table if not exists payments (
  id               uuid primary key default gen_random_uuid(),
  student_id       uuid not null references users(id) on delete cascade,
  course_id        uuid not null references courses(id) on delete cascade,
  amount           numeric(12, 2) not null check (amount >= 0),
  payment_status   text not null default 'completed'
                     check (payment_status in ('completed', 'pending', 'failed', 'refunded')),
  payment_method   text,          -- 'razorpay' | 'stripe' | 'manual' | etc.
  transaction_id   text unique,   -- gateway transaction/order id
  notes            text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- updated_at trigger
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists payments_updated_at on payments;
create trigger payments_updated_at
  before update on payments
  for each row execute procedure set_updated_at();

-- Indexes
create index if not exists idx_payments_student_id on payments(student_id);
create index if not exists idx_payments_course_id  on payments(course_id);
create index if not exists idx_payments_status     on payments(payment_status);
create index if not exists idx_payments_created_at on payments(created_at desc);

-- Row Level Security
alter table payments enable row level security;

-- Admins can read/write everything
create policy "admin_full_access_payments"
  on payments for all
  using (
    exists (
      select 1 from users
      where id = auth.uid() and role = 'admin'
    )
  );

-- Students can only see their own payments
create policy "student_read_own_payments"
  on payments for select
  using (student_id = auth.uid());

-- ── refund_requests ───────────────────────────────────────────
create table if not exists refund_requests (
  id           uuid primary key default gen_random_uuid(),
  payment_id   uuid not null references payments(id) on delete cascade,
  student_id   uuid not null references users(id) on delete cascade,
  reason       text not null,
  status       text not null default 'pending'
                 check (status in ('pending', 'approved', 'rejected')),
  resolved_by  uuid references users(id),
  resolved_at  timestamptz,
  created_at   timestamptz not null default now()
);

create index if not exists idx_refund_requests_payment_id  on refund_requests(payment_id);
create index if not exists idx_refund_requests_student_id  on refund_requests(student_id);
create index if not exists idx_refund_requests_status      on refund_requests(status);

alter table refund_requests enable row level security;

create policy "admin_full_access_refunds"
  on refund_requests for all
  using (
    exists (
      select 1 from users
      where id = auth.uid() and role = 'admin'
    )
  );

create policy "student_read_own_refunds"
  on refund_requests for select
  using (student_id = auth.uid());

create policy "student_insert_refund"
  on refund_requests for insert
  with check (student_id = auth.uid());

-- ── Seed example data (dev only — remove for production) ──────
-- insert into payments (student_id, course_id, amount, payment_status, payment_method, transaction_id)
-- select
--   s.id,
--   c.id,
--   c.price,
--   'completed',
--   'razorpay',
--   'txn_' || substr(gen_random_uuid()::text, 1, 12)
-- from users s
-- cross join courses c
-- where s.role = 'student'
-- limit 20
-- on conflict do nothing;

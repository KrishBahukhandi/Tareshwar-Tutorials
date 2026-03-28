-- ─────────────────────────────────────────────────────────────
--  production_hardening.sql
--  Tightens production-critical auth/content-access policies.
-- ─────────────────────────────────────────────────────────────

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.users
  where id = auth.uid();
$$;

create or replace function public.teacher_owns_batch(target_batch_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.batches b
    join public.courses c on c.id = b.course_id
    where b.id = target_batch_id
      and c.teacher_id = auth.uid()
  );
$$;

create or replace function public.teacher_can_manage_doubt(target_doubt_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.doubts d
    join public.lectures l on l.id = d.lecture_id
    join public.chapters ch on ch.id = l.chapter_id
    join public.subjects s on s.id = ch.subject_id
    join public.courses c on c.id = s.course_id
    where d.id = target_doubt_id
      and c.teacher_id = auth.uid()
  );
$$;

create or replace function public.can_access_test(target_test_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.tests t
    join public.chapters ch on ch.id = t.chapter_id
    join public.subjects s on s.id = ch.subject_id
    join public.courses c on c.id = s.course_id
    where t.id = target_test_id
      and (
        public.is_admin()
        or c.teacher_id = auth.uid()
        or (
          t.is_published = true
          and exists (
            select 1
            from public.enrollments e
            join public.batches b on b.id = e.batch_id
            where e.student_id = auth.uid()
              and b.course_id = c.id
          )
        )
      )
  );
$$;

create or replace function public.get_student_test_questions(p_test_id uuid)
returns table (
  id uuid,
  test_id uuid,
  question text,
  question_image_url text,
  options text[],
  marks integer,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select q.id,
         q.test_id,
         q.question,
         q.question_image_url,
         q.options,
         q.marks,
         q.created_at
  from public.questions q
  join public.tests t on t.id = q.test_id
  where q.test_id = p_test_id
    and auth.uid() is not null
    and t.is_published = true
    and exists (
      select 1
      from public.chapters ch
      join public.subjects s on s.id = ch.subject_id
      join public.enrollments e on true
      join public.batches b on b.id = e.batch_id
      where ch.id = t.chapter_id
        and e.student_id = auth.uid()
        and b.course_id = s.course_id
    )
  order by q.created_at;
$$;

create or replace function public.get_student_test_review_questions(p_test_id uuid)
returns table (
  id uuid,
  test_id uuid,
  question text,
  question_image_url text,
  options text[],
  correct_option_index integer,
  marks integer,
  explanation text,
  created_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  select q.id,
         q.test_id,
         q.question,
         q.question_image_url,
         q.options,
         q.correct_option_index,
         q.marks,
         q.explanation,
         q.created_at
  from public.questions q
  where q.test_id = p_test_id
    and auth.uid() is not null
    and exists (
      select 1
      from public.test_attempts ta
      where ta.test_id = p_test_id
        and ta.student_id = auth.uid()
    )
  order by q.created_at;
$$;

create or replace function public.submit_test_attempt(
  p_test_id uuid,
  p_answers jsonb,
  p_time_taken_seconds integer
)
returns public.test_attempts
language plpgsql
security definer
set search_path = public
as $$
declare
  question_row record;
  selected_option integer;
  neg_marks numeric(4, 2);
  score integer := 0;
  total_marks integer := 0;
  correct_answers integer := 0;
  wrong_answers integer := 0;
  skipped_answers integer := 0;
  inserted_attempt public.test_attempts;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not public.can_access_test(p_test_id) then
    raise exception 'You do not have access to this test';
  end if;

  select t.negative_marks
  into neg_marks
  from public.tests t
  where t.id = p_test_id
    and t.is_published = true;

  if neg_marks is null then
    raise exception 'Published test not found';
  end if;

  for question_row in
    select q.id, q.marks, q.correct_option_index
    from public.questions q
    where q.test_id = p_test_id
    order by q.created_at
  loop
    total_marks := total_marks + coalesce(question_row.marks, 0);

    if p_answers ? question_row.id::text then
      selected_option := nullif(p_answers ->> question_row.id::text, '')::integer;
    else
      selected_option := null;
    end if;

    if selected_option is null then
      skipped_answers := skipped_answers + 1;
    elsif selected_option = question_row.correct_option_index then
      score := score + question_row.marks;
      correct_answers := correct_answers + 1;
    else
      score := score - round(neg_marks * question_row.marks);
      wrong_answers := wrong_answers + 1;
    end if;
  end loop;

  score := greatest(score, 0);

  insert into public.test_attempts (
    test_id,
    student_id,
    score,
    total_marks,
    correct_answers,
    wrong_answers,
    skipped,
    time_taken_seconds,
    answers,
    attempted_at
  )
  values (
    p_test_id,
    auth.uid(),
    score,
    total_marks,
    correct_answers,
    wrong_answers,
    skipped_answers,
    greatest(coalesce(p_time_taken_seconds, 0), 0),
    coalesce(p_answers, '{}'::jsonb),
    now()
  )
  returning *
  into inserted_attempt;

  return inserted_attempt;
end;
$$;

drop policy if exists "enrollments: admin/teacher insert" on public.enrollments;
create policy "enrollments: admin/teacher insert"
  on public.enrollments for insert
  with check (
    public.is_admin()
    or exists (
      select 1 from public.batches b
      join public.courses c on c.id = b.course_id
      where b.id = batch_id and c.teacher_id = auth.uid()
    )
  );

drop policy if exists "enrollments: admin delete" on public.enrollments;
create policy "enrollments: admin delete"
  on public.enrollments for delete
  using (
    public.is_admin()
    or exists (
      select 1 from public.batches b
      join public.courses c on c.id = b.course_id
      where b.id = enrollments.batch_id and c.teacher_id = auth.uid()
    )
  );

drop policy if exists "questions: enrolled or teacher select" on public.questions;
create policy "questions: teacher/admin select"
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
  );

drop policy if exists "doubts: own or teacher select" on public.doubts;
create policy "doubts: own or teacher select"
  on public.doubts for select
  using (
    auth.uid() = student_id
    or public.is_admin()
    or public.teacher_can_manage_doubt(id)
  );

drop policy if exists "doubts: teacher update (answer)" on public.doubts;
create policy "doubts: teacher update (answer)"
  on public.doubts for update
  using (public.is_admin() or public.teacher_can_manage_doubt(id));

drop policy if exists "announcements: teacher insert" on public.announcements;
create policy "announcements: admin insert"
  on public.announcements for insert
  with check (auth.uid() = author_id and public.is_admin());

drop policy if exists "announcements: admin update" on public.announcements;
create policy "announcements: admin update"
  on public.announcements for update
  using (public.is_admin());

drop policy if exists "announcements: admin delete" on public.announcements;
create policy "announcements: admin delete"
  on public.announcements for delete
  using (public.is_admin());

drop policy if exists "live_classes: insert" on public.live_classes;
create policy "live_classes: insert"
  on public.live_classes for insert
  with check (
    public.is_admin()
    or (auth.uid() = teacher_id and public.teacher_owns_batch(batch_id))
  );

drop policy if exists "live_classes: update" on public.live_classes;
create policy "live_classes: update"
  on public.live_classes for update
  using (
    public.is_admin()
    or auth.uid() = teacher_id
  );

drop policy if exists "live_classes: delete" on public.live_classes;
create policy "live_classes: delete"
  on public.live_classes for delete
  using (
    public.is_admin()
    or auth.uid() = teacher_id
  );

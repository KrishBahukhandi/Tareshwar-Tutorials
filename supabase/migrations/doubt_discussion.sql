-- ─────────────────────────────────────────────────────────────
--  Supabase migration: Doubt Discussion System
--  Run this in your Supabase SQL editor.
-- ─────────────────────────────────────────────────────────────

-- 1. doubts table (if not already present; adds reply_count column)
CREATE TABLE IF NOT EXISTS public.doubts (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id      uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    lecture_id      uuid REFERENCES public.lectures(id) ON DELETE SET NULL,
    question        text NOT NULL,
    image_url       text,
    answer          text,          -- legacy single-answer field
    answered_by     uuid REFERENCES public.users(id) ON DELETE SET NULL,
    is_answered     boolean NOT NULL DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- 2. doubt_replies table
CREATE TABLE IF NOT EXISTS public.doubt_replies (
    id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    doubt_id    uuid NOT NULL REFERENCES public.doubts(id) ON DELETE CASCADE,
    author_id   uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    role        text NOT NULL DEFAULT 'student' CHECK (role IN ('student', 'teacher')),
    body        text NOT NULL,
    image_url   text,
    created_at  timestamptz NOT NULL DEFAULT now()
);

-- 3. Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_doubts_student_id
    ON public.doubts(student_id);

CREATE INDEX IF NOT EXISTS idx_doubts_lecture_id
    ON public.doubts(lecture_id);

CREATE INDEX IF NOT EXISTS idx_doubt_replies_doubt_id
    ON public.doubt_replies(doubt_id);

CREATE INDEX IF NOT EXISTS idx_doubt_replies_author_id
    ON public.doubt_replies(author_id);

-- 4. RLS policies
ALTER TABLE public.doubts       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doubt_replies ENABLE ROW LEVEL SECURITY;

-- doubts: any authenticated user can read
CREATE POLICY "doubts_select_authenticated"
    ON public.doubts FOR SELECT
    USING (auth.role() = 'authenticated');

-- doubts: only the owning student can insert
CREATE POLICY "doubts_insert_own"
    ON public.doubts FOR INSERT
    WITH CHECK (student_id = auth.uid());

-- doubts: owner or teacher can update (answer / mark resolved)
CREATE POLICY "doubts_update_own_or_teacher"
    ON public.doubts FOR UPDATE
    USING (
        student_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.users
            WHERE id = auth.uid() AND role IN ('teacher', 'admin')
        )
    );

-- doubts: only owner can delete
CREATE POLICY "doubts_delete_own"
    ON public.doubts FOR DELETE
    USING (student_id = auth.uid());

-- doubt_replies: any authenticated user can read
CREATE POLICY "replies_select_authenticated"
    ON public.doubt_replies FOR SELECT
    USING (auth.role() = 'authenticated');

-- doubt_replies: authenticated users can insert
CREATE POLICY "replies_insert_authenticated"
    ON public.doubt_replies FOR INSERT
    WITH CHECK (author_id = auth.uid());

-- doubt_replies: only author can delete their reply
CREATE POLICY "replies_delete_own"
    ON public.doubt_replies FOR DELETE
    USING (author_id = auth.uid());

-- 5. Enable Realtime on both tables
-- (Run in Supabase Dashboard → Database → Replication,
--  or with the management API)
-- ALTER PUBLICATION supabase_realtime ADD TABLE public.doubts;
ALTER PUBLICATION supabase_realtime ADD TABLE public.doubt_replies;

-- 6. Storage bucket (doubt-images) must already exist.
--    If not, create it from Supabase Dashboard → Storage.

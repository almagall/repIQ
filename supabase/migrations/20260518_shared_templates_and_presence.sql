-- Two additions wired in the same migration since they're both small and
-- ship together in the v1.5 social-expansion batch:
--   1. Templates can be marked shareable. When `is_shared = true`, friends
--      can view the template from the owner's friend profile and clone it
--      into their own templates.
--   2. `user_presence` table for "training now" status in the Gym Hub.
--      Rows are short-lived (TTL via `expires_at`); the client writes one
--      when a workout begins, refreshes it on stepper interactions, and
--      deletes/expires it on completion or abandon.

-- ============================================================
-- 1. Shareable templates
-- ============================================================
ALTER TABLE public.templates
    ADD COLUMN IF NOT EXISTS is_shared boolean NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_templates_shared
    ON public.templates(is_shared)
    WHERE is_shared = true;

-- Friends-of-owner can read a shareable template + its days/exercises.
-- The existing RLS policy `users_own_templates_only` blocks cross-user
-- reads; add a permissive policy specifically for shared rows.
CREATE POLICY shared_templates_readable_by_friends
    ON public.templates
    FOR SELECT
    USING (
        is_shared = true
        AND (
            user_id = auth.uid()
            OR EXISTS (
                SELECT 1 FROM public.friendships f
                WHERE f.status = 'accepted'
                  AND (
                      (f.user_id = auth.uid() AND f.friend_id = templates.user_id)
                      OR
                      (f.friend_id = auth.uid() AND f.user_id = templates.user_id)
                  )
            )
        )
    );

-- workout_days + workout_day_exercises currently scope reads via
-- templates → user_id = auth.uid(). Loosen the join so accepted friends
-- can read days/exercises of a shared template.
CREATE POLICY shared_workout_days_readable_by_friends
    ON public.workout_days
    FOR SELECT
    USING (
        template_id IN (
            SELECT id FROM public.templates
            WHERE is_shared = true AND (
                user_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM public.friendships f
                    WHERE f.status = 'accepted'
                      AND (
                          (f.user_id = auth.uid() AND f.friend_id = templates.user_id)
                          OR
                          (f.friend_id = auth.uid() AND f.user_id = templates.user_id)
                      )
                )
            )
        )
    );

CREATE POLICY shared_workout_day_exercises_readable_by_friends
    ON public.workout_day_exercises
    FOR SELECT
    USING (
        workout_day_id IN (
            SELECT wd.id
            FROM public.workout_days wd
            JOIN public.templates t ON t.id = wd.template_id
            WHERE t.is_shared = true AND (
                t.user_id = auth.uid()
                OR EXISTS (
                    SELECT 1 FROM public.friendships f
                    WHERE f.status = 'accepted'
                      AND (
                          (f.user_id = auth.uid() AND f.friend_id = t.user_id)
                          OR
                          (f.friend_id = auth.uid() AND f.user_id = t.user_id)
                      )
                )
            )
        )
    );

-- ============================================================
-- 2. user_presence (training-now status)
-- ============================================================
CREATE TABLE IF NOT EXISTS public.user_presence (
    user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    gym_place_id text,
    started_at timestamptz NOT NULL DEFAULT now(),
    expires_at timestamptz NOT NULL DEFAULT (now() + interval '2 hours')
);

-- Composite index for the (expires_at, gym_place_id) lookup the gym hub
-- runs. A `WHERE expires_at > now()` partial predicate would be ideal
-- but Postgres rejects it because `now()` is STABLE, not IMMUTABLE;
-- partial-index predicates can only reference immutable functions. The
-- full composite index is plenty fast for the row volume we expect.
CREATE INDEX IF NOT EXISTS idx_user_presence_active
    ON public.user_presence(expires_at, gym_place_id);

ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;

-- The owner can read/write their own row.
CREATE POLICY presence_owner_all
    ON public.user_presence
    FOR ALL
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- Accepted friends can read presence rows.
CREATE POLICY presence_visible_to_friends
    ON public.user_presence
    FOR SELECT
    USING (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.friendships f
            WHERE f.status = 'accepted'
              AND (
                  (f.user_id = auth.uid() AND f.friend_id = user_presence.user_id)
                  OR
                  (f.friend_id = auth.uid() AND f.user_id = user_presence.user_id)
              )
        )
    );

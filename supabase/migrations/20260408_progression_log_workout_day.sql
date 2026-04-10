-- Scope progression_log entries by workout_day_id so the same exercise
-- in different workout days (e.g., bench press in Push A vs Push B) gets
-- independent progression histories.

ALTER TABLE public.progression_log
    ADD COLUMN IF NOT EXISTS workout_day_id UUID
    REFERENCES public.workout_days(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_progression_user_exercise_day
    ON public.progression_log(user_id, exercise_id, workout_day_id, created_at DESC);

-- Backfill: tag each historical progression entry with the workout_day_id
-- of the most recent completed session for that user that occurred at or
-- before the entry's created_at. No data is lost — old entries get the
-- day they were originally tied to.
UPDATE public.progression_log pl
SET workout_day_id = ws.workout_day_id
FROM public.workout_sessions ws
WHERE pl.workout_day_id IS NULL
  AND ws.user_id = pl.user_id
  AND ws.workout_day_id IS NOT NULL
  AND ws.id = (
      SELECT id FROM public.workout_sessions
      WHERE user_id = pl.user_id
        AND status = 'completed'
        AND completed_at <= pl.created_at
        AND workout_day_id IS NOT NULL
      ORDER BY completed_at DESC
      LIMIT 1
  );

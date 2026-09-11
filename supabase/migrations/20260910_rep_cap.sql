-- rep_cap was added to production out-of-band; recorded here so a fresh
-- environment matches. Narrows the top of the training mode's rep range.
ALTER TABLE public.workout_day_exercises ADD COLUMN IF NOT EXISTS rep_cap INTEGER;

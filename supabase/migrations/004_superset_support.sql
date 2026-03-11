-- Add superset grouping support to workout day exercises.
-- Exercises with the same superset_group value within a workout day are performed as a superset.
-- NULL means the exercise is performed standalone (not part of a superset).

ALTER TABLE public.workout_day_exercises
    ADD COLUMN IF NOT EXISTS superset_group integer;

COMMENT ON COLUMN public.workout_day_exercises.superset_group IS
    'Superset group index within a workout day. Exercises sharing the same value are performed back-to-back with no rest between them.';

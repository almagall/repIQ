-- Strength exercises can be ramped (weight ascends to a top set, the top set
-- is judged) or straight (every set at the prescribed weight, the weakest set
-- gates progression). Hypertrophy is always straight and ignores the column.
-- Defaults to 'ramped' so every existing row keeps its current behaviour.
ALTER TABLE public.workout_day_exercises
    ADD COLUMN IF NOT EXISTS set_scheme TEXT NOT NULL DEFAULT 'ramped'
    CHECK (set_scheme IN ('ramped', 'straight'));

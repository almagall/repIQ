-- Who decides an exercise's numbers. 'autoregulated' is the reactive engine
-- (ProgressionService.calculateTarget); 'wave_531' is Wendler's 5/3/1 cycle,
-- prescribed from a training max. Defaults so every existing row is unchanged.
-- When the rule isn't autoregulated it owns the set layout, and set_scheme /
-- rep_cap are ignored.
ALTER TABLE public.workout_day_exercises
    ADD COLUMN IF NOT EXISTS progression_rule TEXT NOT NULL DEFAULT 'autoregulated'
    CHECK (progression_rule IN ('autoregulated', 'wave_531'));

-- Per-user, per-lift training max for percentage-based rules. Append-only:
-- the latest row is the current TM, and every cycle-end verdict writes a new
-- row so bumps, holds and resets are auditable and plottable.
CREATE TABLE IF NOT EXISTS public.training_maxes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
    value DECIMAL(7,2) NOT NULL,
    source TEXT NOT NULL CHECK (source IN ('manual', 'estimated', 'bump', 'hold', 'reset', 'recalibrated')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_training_maxes_user_exercise
    ON public.training_maxes(user_id, exercise_id, created_at DESC);

ALTER TABLE public.training_maxes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own training maxes"
    ON public.training_maxes FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own training maxes"
    ON public.training_maxes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can delete own training maxes"
    ON public.training_maxes FOR DELETE USING (auth.uid() = user_id);

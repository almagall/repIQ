-- Per-set target snapshot.
--
-- What the progression engine prescribed for this specific set before it was
-- lifted. Until now the target lived only in memory on `SetEntry`, so once a
-- set was saved there was no way to ask "did they do what they were told?" —
-- which is what the Progress tab's adherence figures are built on.
--
-- NULL means the set was never given a target, and such sets are excluded from
-- adherence entirely rather than counted as misses. That covers warm-ups and
-- cool-downs (deliberately never pre-filled), drop and failure sets, extra sets
-- the user added beyond the prescription, and the first session of a brand-new
-- exercise where the engine has nothing to go on yet.
--
-- Historical rows stay NULL. `progression_log` can reconstruct hypertrophy
-- straight sets and strength top sets for sessions before this migration, but
-- not the individual ramp-up weights, which only ever existed on `SetEntry`.

ALTER TABLE public.workout_sets
    ADD COLUMN target_weight DECIMAL(7,2),
    ADD COLUMN target_reps INTEGER,
    ADD COLUMN target_rpe DECIMAL(3,1);

-- Adherence always reads graded sets only, and graded means target_reps IS NOT
-- NULL. A partial index keeps those scans off the (much larger) set of
-- warm-ups and pre-migration rows.
CREATE INDEX idx_sets_graded
    ON public.workout_sets(exercise_id, completed_at DESC)
    WHERE target_reps IS NOT NULL;

-- Add per-set notes field to workout_sets table
ALTER TABLE workout_sets ADD COLUMN IF NOT EXISTS notes TEXT;

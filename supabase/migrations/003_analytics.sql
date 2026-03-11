-- ============================================================
-- Migration: Analytics Performance Index
-- Adds composite index on workout_sets for faster analytics queries
-- ============================================================

-- Speed up analytics aggregation queries that join sets with sessions and exercises
CREATE INDEX IF NOT EXISTS idx_workout_sets_session_exercise
  ON public.workout_sets (session_id, exercise_id);

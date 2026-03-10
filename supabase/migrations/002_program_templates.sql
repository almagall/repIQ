-- ============================================================
-- Migration: Pre-Built Program Templates
-- Adds source_program column to templates and new built-in exercises
-- ============================================================

-- Add source_program column to track which pre-built program a template was created from
ALTER TABLE public.templates ADD COLUMN source_program TEXT;

-- Add new built-in exercises needed by pre-built program templates
INSERT INTO public.exercises (user_id, name, muscle_group, equipment, is_compound, default_rest_seconds) VALUES
-- Back
(NULL, 'Chin-Ups', 'back', 'bodyweight', true, 120),
(NULL, 'Rack Pull', 'back', 'barbell', true, 120),
(NULL, 'Power Clean', 'back', 'barbell', true, 180),
-- Chest
(NULL, 'Incline Dumbbell Flyes', 'chest', 'dumbbell', false, 60),
-- Quads
(NULL, 'Front Squat', 'quads', 'barbell', true, 120),
(NULL, 'Box Squat', 'quads', 'barbell', true, 120),
(NULL, 'Dumbbell Lunges', 'quads', 'dumbbell', true, 90),
-- Hamstrings
(NULL, 'Sumo Deadlift', 'hamstrings', 'barbell', true, 180),
(NULL, 'Good Mornings', 'hamstrings', 'barbell', true, 90),
(NULL, 'Back Extensions', 'hamstrings', 'bodyweight', false, 60);

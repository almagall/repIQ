-- Add exercises referenced by pre-built programs but missing from the seed data.
-- Without these, 11 of 14 programs fail to materialize ("Missing exercises" error).

INSERT INTO public.exercises (user_id, name, muscle_group, equipment, is_compound, default_rest_seconds) VALUES
(NULL, 'Back Extensions', 'back', 'bodyweight', false, 60),
(NULL, 'Box Squat', 'quads', 'barbell', true, 180),
(NULL, 'Chin-Ups', 'back', 'bodyweight', true, 120),
(NULL, 'Dumbbell Lunges', 'quads', 'dumbbell', true, 90),
(NULL, 'Front Squat', 'quads', 'barbell', true, 180),
(NULL, 'Good Mornings', 'hamstrings', 'barbell', true, 120),
(NULL, 'Incline Dumbbell Flyes', 'chest', 'dumbbell', false, 60),
(NULL, 'Power Clean', 'back', 'barbell', true, 120),
(NULL, 'Rack Pull', 'back', 'barbell', true, 120),
(NULL, 'Sumo Deadlift', 'back', 'barbell', true, 180)
ON CONFLICT DO NOTHING;

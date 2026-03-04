-- ============================================================
-- repIQ Database Schema - Initial Migration
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor → New Query)
-- ============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. PROFILES (extends Supabase auth.users)
-- ============================================================
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    display_name TEXT,
    weight_unit TEXT NOT NULL DEFAULT 'lbs' CHECK (weight_unit IN ('lbs', 'kg')),
    rest_timer_default INTEGER NOT NULL DEFAULT 90,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email)
    VALUES (NEW.id, NEW.email);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 2. EXERCISE LIBRARY
-- ============================================================
CREATE TABLE public.exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    muscle_group TEXT NOT NULL,
    equipment TEXT NOT NULL DEFAULT 'barbell',
    is_compound BOOLEAN NOT NULL DEFAULT false,
    default_rest_seconds INTEGER NOT NULL DEFAULT 90,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_exercises_user ON public.exercises(user_id);
CREATE INDEX idx_exercises_muscle ON public.exercises(muscle_group);

-- ============================================================
-- 3. TEMPLATES
-- ============================================================
CREATE TABLE public.templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_templates_user ON public.templates(user_id);

-- ============================================================
-- 4. WORKOUT DAYS
-- ============================================================
CREATE TABLE public.workout_days (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id UUID NOT NULL REFERENCES public.templates(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_workout_days_template ON public.workout_days(template_id);

-- ============================================================
-- 5. WORKOUT DAY EXERCISES
-- ============================================================
CREATE TABLE public.workout_day_exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    workout_day_id UUID NOT NULL REFERENCES public.workout_days(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE RESTRICT,
    training_mode TEXT NOT NULL DEFAULT 'hypertrophy'
        CHECK (training_mode IN ('hypertrophy', 'strength')),
    target_sets INTEGER NOT NULL DEFAULT 3,
    sort_order INTEGER NOT NULL DEFAULT 0,
    rest_seconds_override INTEGER,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_wde_day ON public.workout_day_exercises(workout_day_id);

-- ============================================================
-- 6. WORKOUT SESSIONS
-- ============================================================
CREATE TABLE public.workout_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    template_id UUID REFERENCES public.templates(id) ON DELETE SET NULL,
    workout_day_id UUID REFERENCES public.workout_days(id) ON DELETE SET NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_seconds INTEGER,
    notes TEXT,
    status TEXT NOT NULL DEFAULT 'in_progress'
        CHECK (status IN ('in_progress', 'completed', 'abandoned')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sessions_user ON public.workout_sessions(user_id);
CREATE INDEX idx_sessions_day ON public.workout_sessions(workout_day_id);
CREATE INDEX idx_sessions_started ON public.workout_sessions(started_at DESC);

-- ============================================================
-- 7. WORKOUT SETS
-- ============================================================
CREATE TABLE public.workout_sets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id UUID NOT NULL REFERENCES public.workout_sessions(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE RESTRICT,
    set_number INTEGER NOT NULL,
    set_type TEXT NOT NULL DEFAULT 'working'
        CHECK (set_type IN ('warmup', 'working', 'cooldown', 'drop', 'failure')),
    weight DECIMAL(7,2) NOT NULL DEFAULT 0,
    reps INTEGER NOT NULL DEFAULT 0,
    rpe DECIMAL(3,1),
    is_pr BOOLEAN NOT NULL DEFAULT false,
    notes TEXT,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sets_session ON public.workout_sets(session_id);
CREATE INDEX idx_sets_exercise ON public.workout_sets(exercise_id);
CREATE INDEX idx_sets_exercise_completed ON public.workout_sets(exercise_id, completed_at DESC);

-- ============================================================
-- 8. PERSONAL RECORDS
-- ============================================================
CREATE TABLE public.personal_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
    record_type TEXT NOT NULL
        CHECK (record_type IN ('weight', 'reps', 'volume', 'estimated_1rm')),
    value DECIMAL(10,2) NOT NULL,
    reps_at_weight INTEGER,
    session_id UUID REFERENCES public.workout_sessions(id) ON DELETE SET NULL,
    achieved_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_prs_user ON public.personal_records(user_id);
CREATE INDEX idx_prs_exercise ON public.personal_records(exercise_id);
CREATE UNIQUE INDEX idx_prs_unique ON public.personal_records(user_id, exercise_id, record_type);

-- ============================================================
-- 9. PROGRESSION LOG
-- ============================================================
CREATE TABLE public.progression_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES public.exercises(id) ON DELETE CASCADE,
    training_mode TEXT NOT NULL CHECK (training_mode IN ('hypertrophy', 'strength')),
    previous_weight DECIMAL(7,2),
    previous_reps INTEGER,
    previous_rpe DECIMAL(3,1),
    target_weight DECIMAL(7,2) NOT NULL,
    target_reps_low INTEGER NOT NULL,
    target_reps_high INTEGER NOT NULL,
    target_rpe DECIMAL(3,1) NOT NULL,
    decision TEXT NOT NULL,
    reasoning TEXT,
    mesocycle_week INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_progression_user ON public.progression_log(user_id);
CREATE INDEX idx_progression_exercise ON public.progression_log(exercise_id);

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_days ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_day_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.personal_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.progression_log ENABLE ROW LEVEL SECURITY;

-- Profiles
CREATE POLICY "Users can view own profile"
    ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile"
    ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Exercises (built-in + user's own)
CREATE POLICY "Users can view exercises"
    ON public.exercises FOR SELECT
    USING (user_id IS NULL OR user_id = auth.uid());
CREATE POLICY "Users can insert own exercises"
    ON public.exercises FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update own exercises"
    ON public.exercises FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete own exercises"
    ON public.exercises FOR DELETE USING (user_id = auth.uid());

-- Templates
CREATE POLICY "Users manage own templates"
    ON public.templates FOR ALL USING (user_id = auth.uid());

-- Workout Days (via template ownership)
CREATE POLICY "Users manage own workout days"
    ON public.workout_days FOR ALL
    USING (template_id IN (SELECT id FROM public.templates WHERE user_id = auth.uid()));

-- Workout Day Exercises (via template chain)
CREATE POLICY "Users manage own day exercises"
    ON public.workout_day_exercises FOR ALL
    USING (workout_day_id IN (
        SELECT wd.id FROM public.workout_days wd
        JOIN public.templates t ON wd.template_id = t.id
        WHERE t.user_id = auth.uid()
    ));

-- Sessions, Sets, PRs, Progression
CREATE POLICY "Users manage own sessions"
    ON public.workout_sessions FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users manage own sets"
    ON public.workout_sets FOR ALL
    USING (session_id IN (SELECT id FROM public.workout_sessions WHERE user_id = auth.uid()));
CREATE POLICY "Users manage own PRs"
    ON public.personal_records FOR ALL USING (user_id = auth.uid());
CREATE POLICY "Users manage own progression"
    ON public.progression_log FOR ALL USING (user_id = auth.uid());

-- ============================================================
-- SEED: Built-in Exercise Library
-- ============================================================
INSERT INTO public.exercises (user_id, name, muscle_group, equipment, is_compound, default_rest_seconds) VALUES
-- Chest
(NULL, 'Barbell Bench Press', 'chest', 'barbell', true, 120),
(NULL, 'Incline Barbell Bench Press', 'chest', 'barbell', true, 120),
(NULL, 'Dumbbell Bench Press', 'chest', 'dumbbell', true, 90),
(NULL, 'Incline Dumbbell Press', 'chest', 'dumbbell', true, 90),
(NULL, 'Cable Flyes', 'chest', 'cable', false, 60),
(NULL, 'Pec Deck', 'chest', 'machine', false, 60),
(NULL, 'Push-Ups', 'chest', 'bodyweight', true, 60),
(NULL, 'Dips (Chest)', 'chest', 'bodyweight', true, 90),
-- Back
(NULL, 'Barbell Row', 'back', 'barbell', true, 120),
(NULL, 'Pull-Ups', 'back', 'bodyweight', true, 120),
(NULL, 'Lat Pulldown', 'back', 'cable', true, 90),
(NULL, 'Seated Cable Row', 'back', 'cable', true, 90),
(NULL, 'Dumbbell Row', 'back', 'dumbbell', true, 90),
(NULL, 'T-Bar Row', 'back', 'barbell', true, 120),
(NULL, 'Face Pulls', 'back', 'cable', false, 60),
(NULL, 'Deadlift', 'back', 'barbell', true, 180),
-- Shoulders
(NULL, 'Overhead Press', 'shoulders', 'barbell', true, 120),
(NULL, 'Dumbbell Shoulder Press', 'shoulders', 'dumbbell', true, 90),
(NULL, 'Lateral Raises', 'shoulders', 'dumbbell', false, 60),
(NULL, 'Front Raises', 'shoulders', 'dumbbell', false, 60),
(NULL, 'Reverse Pec Deck', 'shoulders', 'machine', false, 60),
(NULL, 'Cable Lateral Raise', 'shoulders', 'cable', false, 60),
-- Quads
(NULL, 'Barbell Squat', 'quads', 'barbell', true, 180),
(NULL, 'Leg Press', 'quads', 'machine', true, 120),
(NULL, 'Leg Extensions', 'quads', 'machine', false, 60),
(NULL, 'Bulgarian Split Squat', 'quads', 'dumbbell', true, 90),
(NULL, 'Hack Squat', 'quads', 'machine', true, 120),
-- Hamstrings
(NULL, 'Romanian Deadlift', 'hamstrings', 'barbell', true, 120),
(NULL, 'Leg Curls', 'hamstrings', 'machine', false, 60),
(NULL, 'Stiff-Leg Deadlift', 'hamstrings', 'barbell', true, 120),
-- Glutes
(NULL, 'Hip Thrust', 'glutes', 'barbell', true, 120),
(NULL, 'Cable Kickback', 'glutes', 'cable', false, 60),
-- Calves
(NULL, 'Standing Calf Raise', 'calves', 'machine', false, 60),
(NULL, 'Seated Calf Raise', 'calves', 'machine', false, 60),
-- Biceps
(NULL, 'Barbell Curl', 'biceps', 'barbell', false, 60),
(NULL, 'Dumbbell Curl', 'biceps', 'dumbbell', false, 60),
(NULL, 'Hammer Curl', 'biceps', 'dumbbell', false, 60),
(NULL, 'Preacher Curl', 'biceps', 'barbell', false, 60),
(NULL, 'Cable Curl', 'biceps', 'cable', false, 60),
-- Triceps
(NULL, 'Tricep Pushdown', 'triceps', 'cable', false, 60),
(NULL, 'Skull Crushers', 'triceps', 'barbell', false, 60),
(NULL, 'Overhead Tricep Extension', 'triceps', 'dumbbell', false, 60),
(NULL, 'Close-Grip Bench Press', 'triceps', 'barbell', true, 90),
(NULL, 'Tricep Dips', 'triceps', 'bodyweight', true, 90),
-- Core
(NULL, 'Plank', 'abs', 'bodyweight', false, 60),
(NULL, 'Cable Crunch', 'abs', 'cable', false, 60),
(NULL, 'Hanging Leg Raises', 'abs', 'bodyweight', false, 60),
(NULL, 'Ab Wheel Rollout', 'abs', 'other', false, 60),
-- Forearms
(NULL, 'Wrist Curls', 'forearms', 'dumbbell', false, 60),
(NULL, 'Reverse Wrist Curls', 'forearms', 'dumbbell', false, 60);

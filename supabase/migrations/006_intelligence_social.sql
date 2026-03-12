-- Phase 4: Intelligence-Powered Social + Phase 5: Content & Community
-- Tables for: exercise tips, tip votes, milestones, weekly digests, monthly wrapped, matchmaking

-- ============================================================
-- Exercise Tips (crowdsourced knowledge attached to exercises)
-- ============================================================
CREATE TABLE IF NOT EXISTS exercise_tips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (char_length(content) BETWEEN 10 AND 500),
    tip_type TEXT NOT NULL DEFAULT 'form' CHECK (tip_type IN ('form', 'variation', 'cue', 'safety', 'progression')),
    upvote_count INT NOT NULL DEFAULT 0,
    downvote_count INT NOT NULL DEFAULT 0,
    is_flagged BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_exercise_tips_exercise ON exercise_tips(exercise_id, created_at DESC);
CREATE INDEX idx_exercise_tips_user ON exercise_tips(user_id);

ALTER TABLE exercise_tips ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone can read tips"
    ON exercise_tips FOR SELECT USING (true);
CREATE POLICY "authenticated users create tips"
    ON exercise_tips FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users delete own tips"
    ON exercise_tips FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- Tip Votes (upvote/downvote system)
-- ============================================================
CREATE TABLE IF NOT EXISTS tip_votes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tip_id UUID NOT NULL REFERENCES exercise_tips(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    is_upvote BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(tip_id, user_id)
);

ALTER TABLE tip_votes ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anyone can read votes"
    ON tip_votes FOR SELECT USING (true);
CREATE POLICY "authenticated users vote"
    ON tip_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users change own votes"
    ON tip_votes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "users remove own votes"
    ON tip_votes FOR DELETE USING (auth.uid() = user_id);

-- ============================================================
-- Milestones (major achievements that trigger celebrations)
-- ============================================================
CREATE TABLE IF NOT EXISTS user_milestones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    milestone_type TEXT NOT NULL CHECK (milestone_type IN (
        'sessions_100', 'sessions_250', 'sessions_500', 'sessions_1000',
        'streak_30', 'streak_90', 'streak_180', 'streak_365',
        'volume_100k', 'volume_500k', 'volume_1m',
        'thousand_lb_club', 'bodyweight_bench', 'double_bodyweight_squat',
        'year_anniversary', 'two_year_anniversary'
    )),
    achieved_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    data JSONB,
    UNIQUE(user_id, milestone_type)
);

CREATE INDEX idx_user_milestones_user ON user_milestones(user_id, achieved_at DESC);

ALTER TABLE user_milestones ENABLE ROW LEVEL SECURITY;
CREATE POLICY "friends can see milestones"
    ON user_milestones FOR SELECT USING (
        auth.uid() = user_id
        OR EXISTS (
            SELECT 1 FROM friendships
            WHERE status = 'accepted'
              AND ((user_id = auth.uid() AND friend_id = user_milestones.user_id)
                OR (friend_id = auth.uid() AND user_id = user_milestones.user_id))
        )
    );
CREATE POLICY "system inserts milestones"
    ON user_milestones FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- Weekly Digests (in-app summary of friend circle activity)
-- ============================================================
CREATE TABLE IF NOT EXISTS weekly_digests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    friends_trained INT NOT NULL DEFAULT 0,
    total_prs INT NOT NULL DEFAULT 0,
    total_workouts INT NOT NULL DEFAULT 0,
    league_changes JSONB,
    top_performer_id UUID REFERENCES profiles(id),
    top_performer_workouts INT DEFAULT 0,
    highlights JSONB,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, week_start)
);

CREATE INDEX idx_weekly_digests_user ON weekly_digests(user_id, week_start DESC);

ALTER TABLE weekly_digests ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users read own digests"
    ON weekly_digests FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "system creates digests"
    ON weekly_digests FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "users mark digests read"
    ON weekly_digests FOR UPDATE USING (auth.uid() = user_id);

-- ============================================================
-- Monthly Wrapped (Spotify-style monthly report)
-- ============================================================
CREATE TABLE IF NOT EXISTS monthly_wrapped (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    month_start DATE NOT NULL,
    total_sessions INT NOT NULL DEFAULT 0,
    total_volume DOUBLE PRECISION NOT NULL DEFAULT 0,
    total_sets INT NOT NULL DEFAULT 0,
    total_prs INT NOT NULL DEFAULT 0,
    top_exercise_name TEXT,
    top_exercise_volume DOUBLE PRECISION,
    most_consistent_muscle TEXT,
    biggest_pr_exercise TEXT,
    biggest_pr_value DOUBLE PRECISION,
    biggest_pr_type TEXT,
    percentile_rank INT,
    avg_session_duration INT,
    longest_streak INT NOT NULL DEFAULT 0,
    favorite_day TEXT,
    data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, month_start)
);

CREATE INDEX idx_monthly_wrapped_user ON monthly_wrapped(user_id, month_start DESC);

ALTER TABLE monthly_wrapped ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users read own wrapped"
    ON monthly_wrapped FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "system creates wrapped"
    ON monthly_wrapped FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- Matchmaking Preferences
-- ============================================================
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS training_style TEXT CHECK (training_style IN ('hypertrophy', 'strength', 'powerlifting', 'bodybuilding', 'general')),
    ADD COLUMN IF NOT EXISTS experience_level TEXT CHECK (experience_level IN ('beginner', 'intermediate', 'advanced', 'elite')),
    ADD COLUMN IF NOT EXISTS preferred_frequency INT CHECK (preferred_frequency BETWEEN 1 AND 7),
    ADD COLUMN IF NOT EXISTS gym_name TEXT;

-- ============================================================
-- Speed up analytics queries for matchmaking and wrapped
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_workout_sessions_user_completed
    ON workout_sessions(user_id, completed_at DESC)
    WHERE status = 'completed';

CREATE INDEX IF NOT EXISTS idx_personal_records_user_achieved
    ON personal_records(user_id, achieved_at DESC);

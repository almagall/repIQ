-- ============================================================
-- repIQ Social Features: Phase 1 (Friends & Feed), Phase 2 (Gamification),
-- Phase 3 (Training Partners, Challenges, Clubs)
-- ============================================================

-- 1. Extend profiles with social fields
ALTER TABLE public.profiles
    ADD COLUMN IF NOT EXISTS username text UNIQUE,
    ADD COLUMN IF NOT EXISTS bio text DEFAULT '',
    ADD COLUMN IF NOT EXISTS avatar_url text,
    ADD COLUMN IF NOT EXISTS privacy_level text DEFAULT 'friends_only'
        CHECK (privacy_level IN ('public', 'friends_only', 'private')),
    ADD COLUMN IF NOT EXISTS league_tier text DEFAULT 'bronze'
        CHECK (league_tier IN ('bronze', 'silver', 'gold', 'platinum', 'diamond', 'elite')),
    ADD COLUMN IF NOT EXISTS total_iq integer DEFAULT 0,
    ADD COLUMN IF NOT EXISTS current_streak integer DEFAULT 0,
    ADD COLUMN IF NOT EXISTS longest_streak integer DEFAULT 0,
    ADD COLUMN IF NOT EXISTS last_workout_date date;

CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles (username);

-- 2. Friendships (bidirectional friend requests)
CREATE TABLE IF NOT EXISTS public.friendships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    friend_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'accepted', 'declined')),
    is_training_partner boolean DEFAULT false,
    partner_streak integer DEFAULT 0,
    created_at timestamptz DEFAULT now(),
    UNIQUE (user_id, friend_id),
    CHECK (user_id <> friend_id)
);

CREATE INDEX IF NOT EXISTS idx_friendships_user ON public.friendships (user_id, status);
CREATE INDEX IF NOT EXISTS idx_friendships_friend ON public.friendships (friend_id, status);

-- 3. Feed items (auto-generated on workout completion, PR, milestone, etc.)
CREATE TABLE IF NOT EXISTS public.feed_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_id uuid REFERENCES public.workout_sessions(id) ON DELETE SET NULL,
    item_type text NOT NULL
        CHECK (item_type IN ('workout_completed', 'pr_achieved', 'streak_milestone',
                             'badge_earned', 'league_promoted', 'challenge_won')),
    data jsonb DEFAULT '{}',
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feed_items_user ON public.feed_items (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feed_items_created ON public.feed_items (created_at DESC);

-- 4. Feed reactions (fist bumps)
CREATE TABLE IF NOT EXISTS public.feed_reactions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_item_id uuid NOT NULL REFERENCES public.feed_items(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz DEFAULT now(),
    UNIQUE (feed_item_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_feed_reactions_item ON public.feed_reactions (feed_item_id);

-- 5. Feed comments
CREATE TABLE IF NOT EXISTS public.feed_comments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    feed_item_id uuid NOT NULL REFERENCES public.feed_items(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    content text NOT NULL CHECK (char_length(content) <= 500),
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_feed_comments_item ON public.feed_comments (feed_item_id, created_at);

-- 6. IQ Points ledger (every point-earning event)
CREATE TABLE IF NOT EXISTS public.iq_points_ledger (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    points integer NOT NULL,
    reason text NOT NULL
        CHECK (reason IN ('set_completed', 'target_hit', 'session_completed',
                          'pr_achieved', 'streak_bonus', 'challenge_won',
                          'weekly_frequency_bonus')),
    reference_id uuid,
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_iq_ledger_user ON public.iq_points_ledger (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_iq_ledger_user_week ON public.iq_points_ledger (user_id, created_at)
    WHERE created_at >= (now() - interval '7 days');

-- 7. Badge definitions
CREATE TABLE IF NOT EXISTS public.badges (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL UNIQUE,
    description text NOT NULL,
    icon text NOT NULL,
    category text NOT NULL
        CHECK (category IN ('volume', 'consistency', 'strength', 'social', 'intelligence')),
    requirement_type text NOT NULL,
    requirement_value integer NOT NULL,
    created_at timestamptz DEFAULT now()
);

-- 8. User badges (earned)
CREATE TABLE IF NOT EXISTS public.user_badges (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    badge_id uuid NOT NULL REFERENCES public.badges(id) ON DELETE CASCADE,
    earned_at timestamptz DEFAULT now(),
    UNIQUE (user_id, badge_id)
);

CREATE INDEX IF NOT EXISTS idx_user_badges_user ON public.user_badges (user_id);

-- 9. Challenges (head-to-head or personal)
CREATE TABLE IF NOT EXISTS public.challenges (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    challenger_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    challenged_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    challenge_type text NOT NULL
        CHECK (challenge_type IN ('iq_points', 'prs', 'consistency', 'volume_exercise')),
    exercise_id uuid REFERENCES public.exercises(id) ON DELETE SET NULL,
    duration_days integer NOT NULL DEFAULT 7,
    start_date date NOT NULL,
    end_date date NOT NULL,
    status text NOT NULL DEFAULT 'pending'
        CHECK (status IN ('pending', 'active', 'completed', 'declined', 'expired')),
    challenger_score numeric DEFAULT 0,
    challenged_score numeric DEFAULT 0,
    winner_id uuid REFERENCES auth.users(id),
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_challenges_users ON public.challenges (challenger_id, challenged_id, status);

-- 10. Clubs (training groups)
CREATE TABLE IF NOT EXISTS public.clubs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    description text DEFAULT '',
    owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_public boolean DEFAULT true,
    member_count integer DEFAULT 1,
    created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_clubs_owner ON public.clubs (owner_id);

-- 11. Club members
CREATE TABLE IF NOT EXISTS public.club_members (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    club_id uuid NOT NULL REFERENCES public.clubs(id) ON DELETE CASCADE,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role text NOT NULL DEFAULT 'member'
        CHECK (role IN ('owner', 'admin', 'member')),
    joined_at timestamptz DEFAULT now(),
    UNIQUE (club_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_club_members_club ON public.club_members (club_id);
CREATE INDEX IF NOT EXISTS idx_club_members_user ON public.club_members (user_id);

-- 12. Seed badge definitions
INSERT INTO public.badges (name, description, icon, category, requirement_type, requirement_value) VALUES
    -- Volume badges
    ('First Rep', 'Complete your first working set', 'dumbbell.fill', 'volume', 'total_sets', 1),
    ('Century Club', 'Complete 100 working sets', 'flame.fill', 'volume', 'total_sets', 100),
    ('Set Machine', 'Complete 500 working sets', 'bolt.fill', 'volume', 'total_sets', 500),
    ('Iron Addict', 'Complete 1,000 working sets', 'trophy.fill', 'volume', 'total_sets', 1000),
    ('Volume King', 'Lift 100,000 lbs total volume', 'crown.fill', 'volume', 'total_volume', 100000),
    ('Ton Lifter', 'Lift 1,000,000 lbs total volume', 'star.fill', 'volume', 'total_volume', 1000000),
    -- Consistency badges
    ('First Timer', 'Complete your first workout', 'figure.strengthtraining.traditional', 'consistency', 'total_sessions', 1),
    ('Getting Started', 'Complete 10 workouts', 'figure.walk', 'consistency', 'total_sessions', 10),
    ('Regular', 'Complete 50 workouts', 'figure.run', 'consistency', 'total_sessions', 50),
    ('Dedicated', 'Complete 100 workouts', 'medal.fill', 'consistency', 'total_sessions', 100),
    ('Week Warrior', 'Maintain a 7-day training streak', 'calendar.badge.checkmark', 'consistency', 'streak_days', 7),
    ('Month Strong', 'Maintain a 30-day training streak', 'calendar.badge.clock', 'consistency', 'streak_days', 30),
    ('Quarter Beast', 'Maintain a 90-day training streak', 'shield.fill', 'consistency', 'streak_days', 90),
    ('Year of Iron', 'Maintain a 365-day training streak', 'star.circle.fill', 'consistency', 'streak_days', 365),
    -- Strength badges
    ('PR Hunter', 'Hit your first personal record', 'chart.line.uptrend.xyaxis', 'strength', 'total_prs', 1),
    ('Record Breaker', 'Hit 10 personal records', 'chart.bar.fill', 'strength', 'total_prs', 10),
    ('PR Machine', 'Hit 50 personal records', 'bolt.circle.fill', 'strength', 'total_prs', 50),
    ('Progression Master', 'Hit a target 50 times', 'target', 'strength', 'targets_hit', 50),
    -- Social badges
    ('Social Butterfly', 'Add your first friend', 'person.2.fill', 'social', 'friends_count', 1),
    ('Squad', 'Have 5 friends', 'person.3.fill', 'social', 'friends_count', 5),
    ('Crew', 'Have 10 friends', 'person.3.sequence.fill', 'social', 'friends_count', 10),
    ('Hype Machine', 'Give 50 fist bumps', 'hands.clap.fill', 'social', 'fist_bumps_given', 50),
    ('Encourager', 'Give 200 fist bumps', 'heart.fill', 'social', 'fist_bumps_given', 200),
    -- Intelligence badges
    ('Data Driven', 'View your progress dashboard 10 times', 'chart.xyaxis.line', 'intelligence', 'dashboard_views', 10),
    ('Analyst', 'View your progress dashboard 50 times', 'waveform.path.ecg', 'intelligence', 'dashboard_views', 50)
ON CONFLICT (name) DO NOTHING;

-- RLS policies
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feed_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feed_reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.feed_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.iq_points_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_badges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clubs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.club_members ENABLE ROW LEVEL SECURITY;

-- Friendships: users can see their own friendships
CREATE POLICY friendships_select ON public.friendships FOR SELECT
    USING (auth.uid() = user_id OR auth.uid() = friend_id);
CREATE POLICY friendships_insert ON public.friendships FOR INSERT
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY friendships_update ON public.friendships FOR UPDATE
    USING (auth.uid() = user_id OR auth.uid() = friend_id);

-- Feed: users can see feed items from friends or public profiles
CREATE POLICY feed_items_select ON public.feed_items FOR SELECT USING (true);
CREATE POLICY feed_items_insert ON public.feed_items FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Reactions and comments: authenticated users
CREATE POLICY feed_reactions_select ON public.feed_reactions FOR SELECT USING (true);
CREATE POLICY feed_reactions_insert ON public.feed_reactions FOR INSERT
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY feed_reactions_delete ON public.feed_reactions FOR DELETE
    USING (auth.uid() = user_id);

CREATE POLICY feed_comments_select ON public.feed_comments FOR SELECT USING (true);
CREATE POLICY feed_comments_insert ON public.feed_comments FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- IQ Points: users see their own
CREATE POLICY iq_ledger_select ON public.iq_points_ledger FOR SELECT USING (true);
CREATE POLICY iq_ledger_insert ON public.iq_points_ledger FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Badges: public read
CREATE POLICY user_badges_select ON public.user_badges FOR SELECT USING (true);
CREATE POLICY user_badges_insert ON public.user_badges FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Challenges: participants can see
CREATE POLICY challenges_select ON public.challenges FOR SELECT
    USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);
CREATE POLICY challenges_insert ON public.challenges FOR INSERT
    WITH CHECK (auth.uid() = challenger_id);
CREATE POLICY challenges_update ON public.challenges FOR UPDATE
    USING (auth.uid() = challenger_id OR auth.uid() = challenged_id);

-- Clubs: public read, owner manage
CREATE POLICY clubs_select ON public.clubs FOR SELECT USING (true);
CREATE POLICY clubs_insert ON public.clubs FOR INSERT WITH CHECK (auth.uid() = owner_id);
CREATE POLICY clubs_update ON public.clubs FOR UPDATE USING (auth.uid() = owner_id);

CREATE POLICY club_members_select ON public.club_members FOR SELECT USING (true);
CREATE POLICY club_members_insert ON public.club_members FOR INSERT
    WITH CHECK (auth.uid() = user_id);
CREATE POLICY club_members_delete ON public.club_members FOR DELETE
    USING (auth.uid() = user_id);

-- Lift percentile RPC.
--
-- Returns the user's percentile rank on `p_exercise_id` within users of a
-- given `league_tier`, scoped to working sets logged in the last 90 days.
-- e1RM is derived inline via Epley (weight * (1 + reps / 30)) since
-- workout_sets doesn't store it.
--
-- Returns NULL when the cohort is too small (< 5 distinct users) — a
-- "78th percentile of 3 people" comparison is misleading, so we'd rather
-- the client show nothing than show a fake-precise number.

CREATE OR REPLACE FUNCTION lift_percentile_in_tier(
    p_exercise_id uuid,
    p_user_e1rm numeric,
    p_tier text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    total_users integer;
    users_below integer;
BEGIN
    WITH user_best AS (
        SELECT
            s.user_id,
            MAX(ws.weight * (1.0 + ws.reps / 30.0)) AS best_e1rm
        FROM workout_sets ws
        JOIN workout_sessions s ON s.id = ws.session_id
        JOIN profiles p ON p.id = s.user_id
        WHERE ws.exercise_id = p_exercise_id
          AND ws.set_type = 'working'
          AND ws.completed_at >= (now() - interval '90 days')
          AND ws.weight > 0
          AND ws.reps > 0
          AND p.league_tier = p_tier
        GROUP BY s.user_id
    )
    SELECT
        COUNT(*)::integer,
        COUNT(*) FILTER (WHERE best_e1rm <= p_user_e1rm)::integer
    INTO total_users, users_below
    FROM user_best;

    IF total_users IS NULL OR total_users < 5 THEN
        RETURN NULL;
    END IF;

    RETURN GREATEST(0, LEAST(100, ROUND((users_below::numeric / total_users::numeric) * 100)::integer));
END;
$$;

GRANT EXECUTE ON FUNCTION lift_percentile_in_tier(uuid, numeric, text) TO authenticated;

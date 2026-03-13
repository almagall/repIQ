-- Delete duplicate reverse friendships (keep the one created first)
DELETE FROM friendships f1
USING friendships f2
WHERE f1.user_id = f2.friend_id
  AND f1.friend_id = f2.user_id
  AND f1.created_at > f2.created_at;

-- Add unique index that prevents reverse duplicates
-- LEAST/GREATEST ensures (A,B) and (B,A) map to the same key
CREATE UNIQUE INDEX IF NOT EXISTS idx_friendships_unique_pair
    ON friendships (LEAST(user_id, friend_id), GREATEST(user_id, friend_id));

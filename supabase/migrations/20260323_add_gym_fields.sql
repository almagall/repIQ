-- Add gym location fields to profiles for MapKit-based gym discovery
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gym_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gym_place_id TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gym_latitude DOUBLE PRECISION;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gym_longitude DOUBLE PRECISION;

-- Index for efficient gym member queries
CREATE INDEX IF NOT EXISTS idx_profiles_gym_place_id ON profiles(gym_place_id) WHERE gym_place_id IS NOT NULL;

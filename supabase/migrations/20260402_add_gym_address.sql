-- Add missing gym_address column to profiles
-- gym_address was referenced in app code but never added to the schema,
-- causing all gym-related profile queries to fail silently.
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS gym_address TEXT;

-- Add e1RM tracking and starting value to goals
ALTER TABLE goals ADD COLUMN IF NOT EXISTS is_estimated_1rm BOOLEAN DEFAULT false;
ALTER TABLE goals ADD COLUMN IF NOT EXISTS starting_value DOUBLE PRECISION DEFAULT 0;

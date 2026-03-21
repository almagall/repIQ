-- Add estimated 1RM column to progression_log for e1RM-based progression tracking
ALTER TABLE progression_log ADD COLUMN estimated_1rm DECIMAL(7,2);

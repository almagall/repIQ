-- Add source_program column to templates table.
-- This column was defined in migration 002 but that migration was never
-- applied to production, causing INSERT failures when materializing
-- pre-built program templates.

ALTER TABLE public.templates ADD COLUMN IF NOT EXISTS source_program TEXT;

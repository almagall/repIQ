-- Adds the training-archetype reveal column and a viewed-state column to
-- monthly_wrapped. The archetype is a one-of-five label assigned by
-- WrappedArchetype.classify; viewed_at is set when the user finishes (or
-- dismisses) the story flow so the dashboard banner + tab dot badge can clear.
ALTER TABLE monthly_wrapped
    ADD COLUMN IF NOT EXISTS archetype TEXT,
    ADD COLUMN IF NOT EXISTS viewed_at TIMESTAMPTZ;

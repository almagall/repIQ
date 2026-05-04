-- Body context + injury list captured during onboarding (and editable from
-- profile later). All fields are optional; values stored in metric (cm, kg)
-- regardless of the user's display unit so future relative-strength stats
-- and BMI proxies have a canonical source.
--
-- `injuries` is a free-form text array of injury tags ('knee', 'lower_back',
-- 'shoulder', 'wrist', 'hip', 'neck'). New tags can be added without a
-- schema change.
ALTER TABLE profiles
    ADD COLUMN IF NOT EXISTS sex TEXT,
    ADD COLUMN IF NOT EXISTS birth_date DATE,
    ADD COLUMN IF NOT EXISTS height_cm NUMERIC(5,2),
    ADD COLUMN IF NOT EXISTS body_weight_kg NUMERIC(6,2),
    ADD COLUMN IF NOT EXISTS injuries TEXT[];

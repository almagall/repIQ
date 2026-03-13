-- Fix: Allow authenticated users to search profiles for friend discovery
-- The existing policy only allows viewing own profile, which breaks friend search

-- Add a new policy (PostgreSQL OR's multiple SELECT policies together)
CREATE POLICY "Authenticated users can search profiles"
    ON public.profiles FOR SELECT
    USING (auth.uid() IS NOT NULL);

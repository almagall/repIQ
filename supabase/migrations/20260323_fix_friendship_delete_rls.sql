-- Fix: Add missing DELETE policy on friendships table
-- Without this, RLS silently blocks friend removal
CREATE POLICY "friendships_delete" ON public.friendships
    FOR DELETE USING ((auth.uid() = user_id) OR (auth.uid() = friend_id));

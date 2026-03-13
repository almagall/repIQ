-- Fix: Add direct FKs from friendships to profiles for PostgREST joins
-- The existing FKs point to auth.users, which prevents profile joins from working

ALTER TABLE public.friendships
    ADD CONSTRAINT friendships_user_id_profiles_fkey
    FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE public.friendships
    ADD CONSTRAINT friendships_friend_id_profiles_fkey
    FOREIGN KEY (friend_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

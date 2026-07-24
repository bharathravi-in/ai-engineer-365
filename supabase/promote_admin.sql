-- Grant admin rights to a user by email.
-- Run AFTER the person has signed up in the app (so their auth user + profile exist).
-- Replace the email below, then run in the Supabase SQL Editor.

update public.profiles
set is_admin = true
where email = 'bharathravi.in@gmail.com';

-- Verify:
-- select id, email, is_admin from public.profiles order by created_at;

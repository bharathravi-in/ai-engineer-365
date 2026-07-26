-- Remove the legacy single-plan (AI Engineer 365) content + learner-state
-- tables. The app now uses tracks/modules/topics + topic_progress/topic_notes
-- (see 0002_tracks.sql). Kept: profiles, is_admin(), handle_new_user(),
-- touch_updated_at(), and the plan_status enum (still used by tracks/topics).
drop table if exists public.days cascade;
drop table if exists public.months cascade;
drop table if exists public.progress cascade;   -- old per-day progress
drop table if exists public.notes cascade;       -- old per-day notes

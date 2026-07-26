-- Multi-track study planner (roadmap.sh-style).
-- A "track" is a roadmap (Frontend, Backend, DevOps, AI Engineer, ...).
-- track -> modules -> topics (concepts). Each topic has estimated hours and a
-- jsonb array of reference links. Users ENROLL in a track with their weekday/
-- weekend study hours + start date; the app generates a dated day-by-day plan.

create extension if not exists "pgcrypto";

do $$ begin
  create type public.plan_status as enum ('draft', 'published');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Content: tracks -> modules -> topics
-- ---------------------------------------------------------------------------
create table if not exists public.tracks (
  id          uuid primary key default gen_random_uuid(),
  slug        text not null unique,
  title       text not null,
  subtitle    text not null default '',
  description text not null default '',
  icon        text not null default '📚',      -- emoji
  color       text not null default '#6366f1',
  difficulty  text not null default 'Beginner→Advanced',
  status      public.plan_status not null default 'published',
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table if not exists public.modules (
  id          uuid primary key default gen_random_uuid(),
  track_id    uuid not null references public.tracks(id) on delete cascade,
  slug        text not null,
  title       text not null,
  goal        text not null default '',
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (track_id, slug)
);
create index if not exists modules_track_idx on public.modules(track_id);

create table if not exists public.topics (
  id          uuid primary key default gen_random_uuid(),
  module_id   uuid not null references public.modules(id) on delete cascade,
  slug        text not null,
  title       text not null,
  description text not null default '',
  est_hours   numeric not null default 2,
  resources   jsonb not null default '[]'::jsonb,  -- [{kind,title,url}]
  status      public.plan_status not null default 'published',
  sort_order  int not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (module_id, slug)
);
create index if not exists topics_module_idx on public.topics(module_id);

-- ---------------------------------------------------------------------------
-- Per-user: enrollment (availability), progress, notes
-- ---------------------------------------------------------------------------
create table if not exists public.enrollments (
  user_id       uuid not null references auth.users(id) on delete cascade,
  track_id      uuid not null references public.tracks(id) on delete cascade,
  start_date    date not null default current_date,
  weekday_hours numeric not null default 2,
  weekend_hours numeric not null default 4,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  primary key (user_id, track_id)
);

create table if not exists public.topic_progress (
  user_id    uuid not null references auth.users(id) on delete cascade,
  topic_id   uuid not null references public.topics(id) on delete cascade,
  completed  boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, topic_id)
);

create table if not exists public.topic_notes (
  user_id    uuid not null references auth.users(id) on delete cascade,
  topic_id   uuid not null references public.topics(id) on delete cascade,
  content    text not null default '',
  updated_at timestamptz not null default now(),
  primary key (user_id, topic_id)
);

-- keep updated_at fresh (reuses public.touch_updated_at from 0001)
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists tracks_touch on public.tracks;
create trigger tracks_touch before update on public.tracks
  for each row execute function public.touch_updated_at();
drop trigger if exists modules_touch on public.modules;
create trigger modules_touch before update on public.modules
  for each row execute function public.touch_updated_at();
drop trigger if exists topics_touch on public.topics;
create trigger topics_touch before update on public.topics
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security (defense-in-depth; the Node API is the real gate)
-- ---------------------------------------------------------------------------
alter table public.tracks         enable row level security;
alter table public.modules        enable row level security;
alter table public.topics         enable row level security;
alter table public.enrollments    enable row level security;
alter table public.topic_progress enable row level security;
alter table public.topic_notes    enable row level security;

drop policy if exists tracks_read on public.tracks;
create policy tracks_read on public.tracks for select
  using (status = 'published' or public.is_admin(auth.uid()));
drop policy if exists tracks_admin_write on public.tracks;
create policy tracks_admin_write on public.tracks for all
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists modules_read on public.modules;
create policy modules_read on public.modules for select using (true);
drop policy if exists modules_admin_write on public.modules;
create policy modules_admin_write on public.modules for all
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists topics_read on public.topics;
create policy topics_read on public.topics for select
  using (status = 'published' or public.is_admin(auth.uid()));
drop policy if exists topics_admin_write on public.topics;
create policy topics_admin_write on public.topics for all
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists enrollments_owner on public.enrollments;
create policy enrollments_owner on public.enrollments for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists topic_progress_owner on public.topic_progress;
create policy topic_progress_owner on public.topic_progress for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists topic_notes_owner on public.topic_notes;
create policy topic_notes_owner on public.topic_notes for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

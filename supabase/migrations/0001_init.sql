-- AI Engineer 365 — initial schema
-- Run this in the Supabase SQL Editor (or via `supabase db push`).
-- Model: months + days are the plan content (with draft/published status).
-- profiles gates admin access; progress + notes are per-user learner state.

create extension if not exists "pgcrypto";

do $$ begin
  create type public.plan_status as enum ('draft', 'published');
exception when duplicate_object then null; end $$;

-- ---------------------------------------------------------------------------
-- Content tables
-- ---------------------------------------------------------------------------
create table if not exists public.months (
  id           uuid primary key default gen_random_uuid(),
  month_number int  not null unique,
  title        text not null,
  goal         text default '',
  project      jsonb not null default '{}'::jsonb,
  status       public.plan_status not null default 'draft',
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create table if not exists public.days (
  id                  uuid primary key default gen_random_uuid(),
  month_id            uuid not null references public.months(id) on delete cascade,
  day_number          int  not null unique,
  title               text not null,
  duration            text not null default '2h',
  learning_objective  text default '',
  videos              text[] not null default '{}',
  docs                text[] not null default '{}',
  reading             text[] not null default '{}',
  practice            text[] not null default '{}',
  tasks               text[] not null default '{}',
  mini_project        text default '',
  interview_questions text[] not null default '{}',
  status              public.plan_status not null default 'draft',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index if not exists days_month_id_idx on public.days(month_id);

-- ---------------------------------------------------------------------------
-- Auth-linked tables
-- ---------------------------------------------------------------------------
create table if not exists public.profiles (
  id         uuid primary key references auth.users(id) on delete cascade,
  email      text,
  is_admin   boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.progress (
  user_id    uuid not null references auth.users(id) on delete cascade,
  day_number int  not null,
  completed  boolean not null default true,
  updated_at timestamptz not null default now(),
  primary key (user_id, day_number)
);

create table if not exists public.notes (
  user_id    uuid not null references auth.users(id) on delete cascade,
  day_number int  not null,
  content    text not null default '',
  updated_at timestamptz not null default now(),
  primary key (user_id, day_number)
);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
-- SECURITY DEFINER so RLS policies can check admin status without recursing
-- into the profiles table's own RLS.
create or replace function public.is_admin(uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select is_admin from public.profiles where id = uid), false);
$$;

-- Auto-create a profile row when a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- keep updated_at fresh
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

drop trigger if exists months_touch on public.months;
create trigger months_touch before update on public.months
  for each row execute function public.touch_updated_at();
drop trigger if exists days_touch on public.days;
create trigger days_touch before update on public.days
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------
alter table public.months   enable row level security;
alter table public.days     enable row level security;
alter table public.profiles enable row level security;
alter table public.progress enable row level security;
alter table public.notes    enable row level security;

-- Content: everyone (including anonymous) reads PUBLISHED rows; admins read all.
drop policy if exists months_read on public.months;
create policy months_read on public.months for select
  using (status = 'published' or public.is_admin(auth.uid()));
drop policy if exists months_admin_write on public.months;
create policy months_admin_write on public.months for all
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

drop policy if exists days_read on public.days;
create policy days_read on public.days for select
  using (status = 'published' or public.is_admin(auth.uid()));
drop policy if exists days_admin_write on public.days;
create policy days_admin_write on public.days for all
  using (public.is_admin(auth.uid())) with check (public.is_admin(auth.uid()));

-- Profiles: a user sees their own row (admins see all); a user may update their
-- own row but CANNOT grant themselves admin (guarded in the WITH CHECK).
drop policy if exists profiles_read on public.profiles;
create policy profiles_read on public.profiles for select
  using (id = auth.uid() or public.is_admin(auth.uid()));
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid() and is_admin = public.is_admin(auth.uid()));

-- Learner state: strictly owner-scoped.
drop policy if exists progress_owner on public.progress;
create policy progress_owner on public.progress for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists notes_owner on public.notes;
create policy notes_owner on public.notes for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

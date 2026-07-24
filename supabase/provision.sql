-- ============================================================
-- AI Engineer 365 — full provisioning script (one-shot).
-- Runs: schema (0001_init) + seed (12 months / 365 days) + admin promote.
-- Safe to re-run: schema is idempotent, seed upserts.
-- ============================================================

-- ---------- 1. SCHEMA ----------
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

-- ---------- 2. SEED (months + days, published) ----------
-- Generated by scripts/gen-seed-sql.mjs — do not edit by hand.
-- Seeds all months + days as PUBLISHED. Safe to re-run (upserts on the
-- natural keys month_number / day_number).

begin;

-- Month 1: PostgreSQL + SQL
insert into public.months (month_number, title, goal, project, status)
values (1, 'PostgreSQL + SQL', 'Build durable relational-database foundations and query fluency for backend and AI systems.', '{"name":"School Management Database","prd":"Design and query a normalized PostgreSQL database for students, courses, teachers, and enrollments.","architecture":"PostgreSQL schema with constraints, indexes, and views; queried from psql and a small Python client.","techStack":["PostgreSQL","SQL","psql","pgAdmin"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 1, 'PostgreSQL Installation & Setup', '2h', 'Install PostgreSQL and connect via CLI and a GUI client.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a local database and a table', 'Insert and query three rows']::text[], array['Learn: PostgreSQL Installation & Setup (45 min)', 'Code: apply postgresql installation & setup in practice (45 min)', 'Notes + GitHub commit for Day 1 (30 min)']::text[], '', array['What is the difference between a database and a schema?', 'How do PostgreSQL roles differ from OS users?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 2, 'psql & GUI Clients', '2h', 'Navigate psql meta-commands and pgAdmin/DBeaver comfortably.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run \dt, \d, \l in psql', 'Browse a table in a GUI client']::text[], array['Learn: psql & GUI Clients (45 min)', 'Code: apply psql & gui clients in practice (45 min)', 'Notes + GitHub commit for Day 2 (30 min)']::text[], '', array['What does \d do in psql?', 'When would you use a GUI over psql?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 3, 'Databases, Schemas, Roles', '2h', 'Understand how databases, schemas, and roles organize data and access.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a schema and a role', 'Grant read access to the role']::text[], array['Learn: Databases, Schemas, Roles (45 min)', 'Code: apply databases, schemas, roles in practice (45 min)', 'Notes + GitHub commit for Day 3 (30 min)']::text[], '', array['What is a schema used for?', 'How do you grant table permissions?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 4, 'Data Types & Table Creation', '2h', 'Choose correct column types and create tables.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create tables with text, numeric, boolean, timestamp columns', 'Alter a table to add a column']::text[], array['Learn: Data Types & Table Creation (45 min)', 'Code: apply data types & table creation in practice (45 min)', 'Notes + GitHub commit for Day 4 (30 min)']::text[], '', array['When use NUMERIC vs FLOAT?', 'What is the difference between VARCHAR and TEXT?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 5, 'CRUD Operations', '2h', 'Perform INSERT, SELECT, UPDATE, DELETE safely.', '{}'::text[], '{}'::text[], '{}'::text[], array['Insert 10 rows', 'Update and delete rows inside a transaction']::text[], array['Learn: CRUD Operations (45 min)', 'Code: apply crud operations in practice (45 min)', 'Notes + GitHub commit for Day 5 (30 min)']::text[], '', array['Why is UPDATE without WHERE dangerous?', 'What does RETURNING do?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 6, 'Filtering with WHERE', '4h', 'Filter rows with comparison, BETWEEN, IN, LIKE, and NULL checks.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write 8 WHERE queries', 'Filter with IN and LIKE']::text[], array['Learn: Filtering with WHERE (45 min)', 'Code: apply filtering with where in practice (45 min)', 'Notes + GitHub commit for Day 6 (30 min)']::text[], '', array['How do you test for NULL?', 'What is the difference between = and LIKE?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 7, 'Sorting, LIMIT, DISTINCT', '4h', 'Order, paginate, and deduplicate result sets.', '{}'::text[], '{}'::text[], '{}'::text[], array['Sort by multiple columns', 'Use LIMIT/OFFSET for paging']::text[], array['Learn: Sorting, LIMIT, DISTINCT (45 min)', 'Code: apply sorting, limit, distinct in practice (45 min)', 'Notes + GitHub commit for Day 7 (30 min)']::text[], '', array['How does ORDER BY handle NULLs?', 'What does DISTINCT do?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 8, 'Aggregate Functions', '2h', 'Summarize data with COUNT, SUM, AVG, MIN, MAX.', '{}'::text[], '{}'::text[], '{}'::text[], array['Compute totals and averages', 'Count rows per condition']::text[], array['Learn: Aggregate Functions (45 min)', 'Code: apply aggregate functions in practice (45 min)', 'Notes + GitHub commit for Day 8 (30 min)']::text[], '', array['What does COUNT(*) vs COUNT(col) return?', 'How are NULLs treated in AVG?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 9, 'GROUP BY & HAVING', '2h', 'Group rows and filter aggregates.', '{}'::text[], '{}'::text[], '{}'::text[], array['Group enrollments by course', 'Filter groups with HAVING']::text[], array['Learn: GROUP BY & HAVING (45 min)', 'Code: apply group by & having in practice (45 min)', 'Notes + GitHub commit for Day 9 (30 min)']::text[], '', array['What is the difference between WHERE and HAVING?', 'Can you use aggregates in WHERE?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 10, 'Constraints', '2h', 'Enforce data integrity with PK, FK, UNIQUE, CHECK, NOT NULL.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add primary and unique keys', 'Add a CHECK constraint']::text[], array['Learn: Constraints (45 min)', 'Code: apply constraints in practice (45 min)', 'Notes + GitHub commit for Day 10 (30 min)']::text[], '', array['What problem do foreign keys solve?', 'Difference between UNIQUE and PRIMARY KEY?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 11, 'Data Modeling & Normalization', '2h', 'Model entities and normalize to 3NF.', '{}'::text[], '{}'::text[], '{}'::text[], array['Sketch an ERD for the school domain', 'Normalize a denormalized table']::text[], array['Learn: Data Modeling & Normalization (45 min)', 'Code: apply data modeling & normalization in practice (45 min)', 'Notes + GitHub commit for Day 11 (30 min)']::text[], '', array['What problem does normalization solve?', 'When would you denormalize?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 12, 'Relationships & Foreign Keys', '2h', 'Model one-to-many and many-to-many relationships.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a join table for enrollments', 'Add ON DELETE CASCADE']::text[], array['Learn: Relationships & Foreign Keys (45 min)', 'Code: apply relationships & foreign keys in practice (45 min)', 'Notes + GitHub commit for Day 12 (30 min)']::text[], '', array['How do you model many-to-many?', 'What does ON DELETE CASCADE do?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 13, 'INNER & OUTER Joins', '4h', 'Combine tables with INNER, LEFT, RIGHT, FULL joins.', '{}'::text[], '{}'::text[], '{}'::text[], array['Join students to courses', 'Use LEFT JOIN to find gaps']::text[], array['Learn: INNER & OUTER Joins (45 min)', 'Code: apply inner & outer joins in practice (45 min)', 'Notes + GitHub commit for Day 13 (30 min)']::text[], '', array['Difference between INNER and LEFT JOIN?', 'When do you get NULLs from a join?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 14, 'Subqueries', '4h', 'Use scalar, correlated, and IN/EXISTS subqueries.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a correlated subquery', 'Use EXISTS to filter']::text[], array['Learn: Subqueries (45 min)', 'Code: apply subqueries in practice (45 min)', 'Notes + GitHub commit for Day 14 (30 min)']::text[], '', array['Difference between IN and EXISTS?', 'What is a correlated subquery?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 15, 'Views', '2h', 'Create and use views to simplify queries.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a view for active enrollments', 'Query the view']::text[], array['Learn: Views (45 min)', 'Code: apply views in practice (45 min)', 'Notes + GitHub commit for Day 15 (30 min)']::text[], '', array['When would you use a view?', 'What is a materialized view?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 16, 'Indexes & Query Performance', '2h', 'Speed up queries with the right indexes.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a B-tree index', 'Measure query time before/after']::text[], array['Learn: Indexes & Query Performance (45 min)', 'Code: apply indexes & query performance in practice (45 min)', 'Notes + GitHub commit for Day 16 (30 min)']::text[], '', array['When should you add an index?', 'What is the cost of an index?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 17, 'Transactions & ACID', '2h', 'Group operations atomically with transactions.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run a multi-statement transaction', 'Test ROLLBACK']::text[], array['Learn: Transactions & ACID (45 min)', 'Code: apply transactions & acid in practice (45 min)', 'Notes + GitHub commit for Day 17 (30 min)']::text[], '', array['What does ACID stand for?', 'What are isolation levels?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 18, 'Window Functions', '2h', 'Compute running totals and rankings with OVER().', '{}'::text[], '{}'::text[], '{}'::text[], array['Rank students per course', 'Compute a running total']::text[], array['Learn: Window Functions (45 min)', 'Code: apply window functions in practice (45 min)', 'Notes + GitHub commit for Day 18 (30 min)']::text[], '', array['Difference between GROUP BY and window functions?', 'What does PARTITION BY do?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 19, 'Common Table Expressions', '2h', 'Structure queries with WITH and recursive CTEs.', '{}'::text[], '{}'::text[], '{}'::text[], array['Rewrite a subquery as a CTE', 'Write a recursive CTE']::text[], array['Learn: Common Table Expressions (45 min)', 'Code: apply common table expressions in practice (45 min)', 'Notes + GitHub commit for Day 19 (30 min)']::text[], '', array['When is a CTE clearer than a subquery?', 'How do recursive CTEs work?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 20, 'String & Date Functions', '4h', 'Manipulate text and timestamps in SQL.', '{}'::text[], '{}'::text[], '{}'::text[], array['Format dates and extract parts', 'Concatenate and split strings']::text[], array['Learn: String & Date Functions (45 min)', 'Code: apply string & date functions in practice (45 min)', 'Notes + GitHub commit for Day 20 (30 min)']::text[], '', array['How do you get the current timestamp?', 'How do you extract the year from a date?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 21, 'JSON & JSONB', '4h', 'Store and query semi-structured data with JSONB.', '{}'::text[], '{}'::text[], '{}'::text[], array['Store a JSONB column', 'Query nested keys']::text[], array['Learn: JSON & JSONB (45 min)', 'Code: apply json & jsonb in practice (45 min)', 'Notes + GitHub commit for Day 21 (30 min)']::text[], '', array['Difference between JSON and JSONB?', 'How do you index JSONB?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 22, 'Full-Text Search Basics', '2h', 'Search text with tsvector and tsquery.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a tsvector column', 'Run a full-text query']::text[], array['Learn: Full-Text Search Basics (45 min)', 'Code: apply full-text search basics in practice (45 min)', 'Notes + GitHub commit for Day 22 (30 min)']::text[], '', array['What is a tsvector?', 'How does full-text differ from LIKE?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 23, 'Functions & Stored Procedures', '2h', 'Encapsulate logic with PL/pgSQL.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a SQL function', 'Write a procedure with parameters']::text[], array['Learn: Functions & Stored Procedures (45 min)', 'Code: apply functions & stored procedures in practice (45 min)', 'Notes + GitHub commit for Day 23 (30 min)']::text[], '', array['Difference between a function and a procedure?', 'What is PL/pgSQL?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 24, 'Triggers', '2h', 'React to data changes with triggers.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create an updated_at trigger', 'Log deletes with a trigger']::text[], array['Learn: Triggers (45 min)', 'Code: apply triggers in practice (45 min)', 'Notes + GitHub commit for Day 24 (30 min)']::text[], '', array['When would you use a trigger?', 'What are the downsides of triggers?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 25, 'Backup & Restore', '2h', 'Back up and restore databases with pg_dump/pg_restore.', '{}'::text[], '{}'::text[], '{}'::text[], array['Dump a database to a file', 'Restore into a fresh database']::text[], array['Learn: Backup & Restore (45 min)', 'Code: apply backup & restore in practice (45 min)', 'Notes + GitHub commit for Day 25 (30 min)']::text[], '', array['Difference between logical and physical backups?', 'What does pg_dump produce?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 26, 'Roles & Permissions', '2h', 'Manage access with roles and GRANT/REVOKE.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a read-only role', 'Grant and revoke privileges']::text[], array['Learn: Roles & Permissions (45 min)', 'Code: apply roles & permissions in practice (45 min)', 'Notes + GitHub commit for Day 26 (30 min)']::text[], '', array['What is role inheritance?', 'How do you make a read-only user?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 27, 'EXPLAIN & Optimization', '4h', 'Read query plans and optimize slow queries.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run EXPLAIN ANALYZE', 'Fix a sequential scan with an index']::text[], array['Learn: EXPLAIN & Optimization (45 min)', 'Code: apply explain & optimization in practice (45 min)', 'Notes + GitHub commit for Day 27 (30 min)']::text[], '', array['What does EXPLAIN ANALYZE show?', 'What is a sequential scan?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 28, 'Connection Pooling', '4h', 'Understand pooling with PgBouncer and app pools.', '{}'::text[], '{}'::text[], '{}'::text[], array['Configure a connection pool in code', 'Read pool metrics']::text[], array['Learn: Connection Pooling (45 min)', 'Code: apply connection pooling in practice (45 min)', 'Notes + GitHub commit for Day 28 (30 min)']::text[], '', array['Why do you need connection pooling?', 'What does PgBouncer do?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 29, 'Schema Design Review', '2h', 'Review and refactor the full school schema.', '{}'::text[], '{}'::text[], '{}'::text[], array['Audit constraints and indexes', 'Write schema.sql for the project']::text[], array['Learn: Schema Design Review (45 min)', 'Code: apply schema design review in practice (45 min)', 'Notes + GitHub commit for Day 29 (30 min)']::text[], '', array['How do you review a schema for scale?', 'What indexes does a read-heavy app need?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 1), 30, 'Project: School Management Database', '2h', 'Ship a normalized, indexed school database with example queries.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize schema.sql and seed data', 'Write 15 reporting queries']::text[], array['Learn: Project: School Management Database (45 min)', 'Code: apply project: school management database in practice (45 min)', 'Notes + GitHub commit for Day 30 (30 min)']::text[], '', array['Walk through your schema design.', 'How would you scale reads on this database?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 2: Python
insert into public.months (month_number, title, goal, project, status)
values (2, 'Python', 'Become fluent in Python for backend services, automation, and AI engineering.', '{"name":"Python Automation Toolkit","prd":"A CLI toolkit that reads/writes files, calls APIs, and processes data with tests and type hints.","architecture":"Packaged Python project with modules, argparse CLI, pytest tests, and CI-ready linting.","techStack":["Python","pytest","Poetry","requests","mypy"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 31, 'Python Setup & Virtual Environments', '2h', 'Install Python and isolate dependencies with venv.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create and activate a venv', 'Install a package with pip']::text[], array['Learn: Python Setup & Virtual Environments (45 min)', 'Code: apply python setup & virtual environments in practice (45 min)', 'Notes + GitHub commit for Day 31 (30 min)']::text[], '', array['Why use virtual environments?', 'Difference between pip and a package manager?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 32, 'Variables, Types, Operators', '2h', 'Work with core types and operators.', '{}'::text[], '{}'::text[], '{}'::text[], array['Experiment in the REPL', 'Convert between types']::text[], array['Learn: Variables, Types, Operators (45 min)', 'Code: apply variables, types, operators in practice (45 min)', 'Notes + GitHub commit for Day 32 (30 min)']::text[], '', array['Mutable vs immutable types?', 'What is duck typing?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 33, 'Strings & Formatting', '2h', 'Manipulate and format strings with f-strings.', '{}'::text[], '{}'::text[], '{}'::text[], array['Use slicing and methods', 'Format with f-strings']::text[], array['Learn: Strings & Formatting (45 min)', 'Code: apply strings & formatting in practice (45 min)', 'Notes + GitHub commit for Day 33 (30 min)']::text[], '', array['What are f-strings?', 'How do you reverse a string?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 34, 'Lists & Tuples', '4h', 'Use ordered sequences and understand mutability.', '{}'::text[], '{}'::text[], '{}'::text[], array['Practice list methods', 'Unpack tuples']::text[], array['Learn: Lists & Tuples (45 min)', 'Code: apply lists & tuples in practice (45 min)', 'Notes + GitHub commit for Day 34 (30 min)']::text[], '', array['List vs tuple?', 'What is tuple unpacking?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 35, 'Dictionaries & Sets', '4h', 'Use key-value maps and unique collections.', '{}'::text[], '{}'::text[], '{}'::text[], array['Build and iterate a dict', 'Deduplicate with a set']::text[], array['Learn: Dictionaries & Sets (45 min)', 'Code: apply dictionaries & sets in practice (45 min)', 'Notes + GitHub commit for Day 35 (30 min)']::text[], '', array['When use a set?', 'How do you merge two dicts?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 36, 'Conditionals & Loops', '2h', 'Control flow with if/for/while and comprehensions.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write loop-based solutions to 5 problems', 'Use enumerate and zip']::text[], array['Learn: Conditionals & Loops (45 min)', 'Code: apply conditionals & loops in practice (45 min)', 'Notes + GitHub commit for Day 36 (30 min)']::text[], '', array['What does enumerate return?', 'break vs continue?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 37, 'Functions & Scope', '2h', 'Write reusable functions and understand scope.', '{}'::text[], '{}'::text[], '{}'::text[], array['Refactor a script into functions', 'Use default and keyword args']::text[], array['Learn: Functions & Scope (45 min)', 'Code: apply functions & scope in practice (45 min)', 'Notes + GitHub commit for Day 37 (30 min)']::text[], '', array['What is *args/**kwargs?', 'Explain LEGB scope.']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 38, 'Closures & Decorators', '2h', 'Create decorators using closures.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a timing decorator', 'Use functools.wraps']::text[], array['Learn: Closures & Decorators (45 min)', 'Code: apply closures & decorators in practice (45 min)', 'Notes + GitHub commit for Day 38 (30 min)']::text[], '', array['What is a closure?', 'How does a decorator work?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 39, 'Modules & Packages', '2h', 'Organize code into modules and packages.', '{}'::text[], '{}'::text[], '{}'::text[], array['Split code into modules', 'Create a package with __init__']::text[], array['Learn: Modules & Packages (45 min)', 'Code: apply modules & packages in practice (45 min)', 'Notes + GitHub commit for Day 39 (30 min)']::text[], '', array['What is __name__ == "__main__"?', 'How does import resolution work?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 40, 'File I/O', '2h', 'Read and write files safely.', '{}'::text[], '{}'::text[], '{}'::text[], array['Read and write text files', 'Use context managers']::text[], array['Learn: File I/O (45 min)', 'Code: apply file i/o in practice (45 min)', 'Notes + GitHub commit for Day 40 (30 min)']::text[], '', array['Why use a context manager?', 'What does with do?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 41, 'Exceptions & Error Handling', '4h', 'Handle errors with try/except and custom exceptions.', '{}'::text[], '{}'::text[], '{}'::text[], array['Catch and raise exceptions', 'Define a custom exception']::text[], array['Learn: Exceptions & Error Handling (45 min)', 'Code: apply exceptions & error handling in practice (45 min)', 'Notes + GitHub commit for Day 41 (30 min)']::text[], '', array['try/except/else/finally order?', 'When create custom exceptions?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 42, 'Comprehensions', '4h', 'Build lists, dicts, and sets concisely.', '{}'::text[], '{}'::text[], '{}'::text[], array['Rewrite loops as comprehensions', 'Write a nested comprehension']::text[], array['Learn: Comprehensions (45 min)', 'Code: apply comprehensions in practice (45 min)', 'Notes + GitHub commit for Day 42 (30 min)']::text[], '', array['When is a comprehension too complex?', 'Dict comprehension syntax?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 43, 'Iterators & Generators', '2h', 'Produce values lazily with generators.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a generator function', 'Use yield for a pipeline']::text[], array['Learn: Iterators & Generators (45 min)', 'Code: apply iterators & generators in practice (45 min)', 'Notes + GitHub commit for Day 43 (30 min)']::text[], '', array['Difference between iterator and iterable?', 'Why use generators?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 44, 'OOP: Classes & Objects', '2h', 'Model data and behavior with classes.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define a class with methods', 'Use instance vs class attributes']::text[], array['Learn: OOP: Classes & Objects (45 min)', 'Code: apply oop: classes & objects in practice (45 min)', 'Notes + GitHub commit for Day 44 (30 min)']::text[], '', array['What is self?', 'Instance vs class attribute?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 45, 'Inheritance & Polymorphism', '2h', 'Reuse behavior with inheritance.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a subclass', 'Override a method']::text[], array['Learn: Inheritance & Polymorphism (45 min)', 'Code: apply inheritance & polymorphism in practice (45 min)', 'Notes + GitHub commit for Day 45 (30 min)']::text[], '', array['What is method resolution order?', 'Composition vs inheritance?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 46, 'Dunder Methods & Dataclasses', '2h', 'Customize objects and use @dataclass.', '{}'::text[], '{}'::text[], '{}'::text[], array['Implement __repr__ and __eq__', 'Convert a class to a dataclass']::text[], array['Learn: Dunder Methods & Dataclasses (45 min)', 'Code: apply dunder methods & dataclasses in practice (45 min)', 'Notes + GitHub commit for Day 46 (30 min)']::text[], '', array['What does __init__ do?', 'When use a dataclass?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 47, 'Type Hints & mypy', '2h', 'Add static types and check with mypy.', '{}'::text[], '{}'::text[], '{}'::text[], array['Annotate functions', 'Run mypy on the project']::text[], array['Learn: Type Hints & mypy (45 min)', 'Code: apply type hints & mypy in practice (45 min)', 'Notes + GitHub commit for Day 47 (30 min)']::text[], '', array['Do type hints affect runtime?', 'What is Optional?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 48, 'Standard Library Tour', '4h', 'Use collections, itertools, pathlib, and more.', '{}'::text[], '{}'::text[], '{}'::text[], array['Use Counter and defaultdict', 'Use pathlib for paths']::text[], array['Learn: Standard Library Tour (45 min)', 'Code: apply standard library tour in practice (45 min)', 'Notes + GitHub commit for Day 48 (30 min)']::text[], '', array['What is defaultdict?', 'Why prefer pathlib?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 49, 'Working with JSON & CSV', '4h', 'Parse and write JSON and CSV data.', '{}'::text[], '{}'::text[], '{}'::text[], array['Load and dump JSON', 'Read a CSV into dicts']::text[], array['Learn: Working with JSON & CSV (45 min)', 'Code: apply working with json & csv in practice (45 min)', 'Notes + GitHub commit for Day 49 (30 min)']::text[], '', array['json.load vs json.loads?', 'How do you handle CSV headers?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 50, 'HTTP Requests', '2h', 'Call APIs with the requests library.', '{}'::text[], '{}'::text[], '{}'::text[], array['GET and POST to a public API', 'Handle status codes and JSON']::text[], array['Learn: HTTP Requests (45 min)', 'Code: apply http requests in practice (45 min)', 'Notes + GitHub commit for Day 50 (30 min)']::text[], '', array['How do you send headers?', 'How do you handle timeouts?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 51, 'Regular Expressions', '2h', 'Match and extract text with re.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write patterns for emails and dates', 'Use groups and findall']::text[], array['Learn: Regular Expressions (45 min)', 'Code: apply regular expressions in practice (45 min)', 'Notes + GitHub commit for Day 51 (30 min)']::text[], '', array['What is a capture group?', 'Greedy vs lazy matching?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 52, 'Datetime & Timezones', '2h', 'Work with dates, times, and timezones.', '{}'::text[], '{}'::text[], '{}'::text[], array['Parse and format datetimes', 'Convert between timezones']::text[], array['Learn: Datetime & Timezones (45 min)', 'Code: apply datetime & timezones in practice (45 min)', 'Notes + GitHub commit for Day 52 (30 min)']::text[], '', array['Why use timezone-aware datetimes?', 'What is UTC?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 53, 'Dependency Management', '2h', 'Manage dependencies with pip and Poetry.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a pyproject.toml', 'Pin and lock dependencies']::text[], array['Learn: Dependency Management (45 min)', 'Code: apply dependency management in practice (45 min)', 'Notes + GitHub commit for Day 53 (30 min)']::text[], '', array['Why lock dependencies?', 'requirements.txt vs Poetry?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 54, 'Testing with pytest', '2h', 'Write and run unit tests.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write tests for the toolkit', 'Use fixtures and parametrize']::text[], array['Learn: Testing with pytest (45 min)', 'Code: apply testing with pytest in practice (45 min)', 'Notes + GitHub commit for Day 54 (30 min)']::text[], '', array['What is a fixture?', 'Why parametrize tests?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 55, 'Logging', '4h', 'Log instead of print, with levels and handlers.', '{}'::text[], '{}'::text[], '{}'::text[], array['Configure the logging module', 'Log to file and console']::text[], array['Learn: Logging (45 min)', 'Code: apply logging in practice (45 min)', 'Notes + GitHub commit for Day 55 (30 min)']::text[], '', array['Why log instead of print?', 'What are log levels?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 56, 'Async IO Basics', '4h', 'Run concurrent IO with asyncio.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write an async function', 'Run tasks with gather']::text[], array['Learn: Async IO Basics (45 min)', 'Code: apply async io basics in practice (45 min)', 'Notes + GitHub commit for Day 56 (30 min)']::text[], '', array['What is the event loop?', 'async vs threads?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 57, 'Databases from Python', '2h', 'Query PostgreSQL with psycopg.', '{}'::text[], '{}'::text[], '{}'::text[], array['Connect and run a query', 'Use parameterized statements']::text[], array['Learn: Databases from Python (45 min)', 'Code: apply databases from python in practice (45 min)', 'Notes + GitHub commit for Day 57 (30 min)']::text[], '', array['Why parameterize queries?', 'What is a cursor?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 58, 'CLI Apps', '2h', 'Build command-line tools with argparse/click.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add subcommands to the toolkit', 'Parse flags and args']::text[], array['Learn: CLI Apps (45 min)', 'Code: apply cli apps in practice (45 min)', 'Notes + GitHub commit for Day 58 (30 min)']::text[], '', array['argparse vs click?', 'How do you handle bad input?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 59, 'Code Quality', '2h', 'Format and lint with black and ruff.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run black and ruff', 'Fix lint errors']::text[], array['Learn: Code Quality (45 min)', 'Code: apply code quality in practice (45 min)', 'Notes + GitHub commit for Day 59 (30 min)']::text[], '', array['Why use a formatter?', 'What does a linter catch?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 2), 60, 'Project: Python Automation Toolkit', '2h', 'Ship a tested, typed, packaged CLI toolkit.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize CLI and tests', 'Add README and CI config']::text[], array['Learn: Project: Python Automation Toolkit (45 min)', 'Code: apply project: python automation toolkit in practice (45 min)', 'Notes + GitHub commit for Day 60 (30 min)']::text[], '', array['Walk through your project structure.', 'How is it tested?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 3: FastAPI + Redis
insert into public.months (month_number, title, goal, project, status)
values (3, 'FastAPI + Redis', 'Build production-style REST APIs with authentication, databases, caching, and queues.', '{"name":"URL Shortener API","prd":"A FastAPI service that shortens URLs, tracks clicks, and caches lookups in Redis with JWT auth.","architecture":"FastAPI + SQLAlchemy + PostgreSQL for storage, Redis for caching and rate limiting, Celery for async.","techStack":["FastAPI","Redis","SQLAlchemy","PostgreSQL","Celery"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 61, 'HTTP & REST Refresher', '2h', 'Review HTTP methods, status codes, and REST principles.', '{}'::text[], '{}'::text[], '{}'::text[], array['Map CRUD to HTTP methods', 'List status codes for common cases']::text[], array['Learn: HTTP & REST Refresher (45 min)', 'Code: apply http & rest refresher in practice (45 min)', 'Notes + GitHub commit for Day 61 (30 min)']::text[], '', array['What makes an API RESTful?', 'When return 201 vs 200?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 62, 'FastAPI Setup & First Endpoint', '4h', 'Scaffold a FastAPI app and run it with uvicorn.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a hello endpoint', 'Open the /docs UI']::text[], array['Learn: FastAPI Setup & First Endpoint (45 min)', 'Code: apply fastapi setup & first endpoint in practice (45 min)', 'Notes + GitHub commit for Day 62 (30 min)']::text[], '', array['What is ASGI?', 'How does FastAPI generate docs?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 63, 'Path & Query Parameters', '4h', 'Accept typed path and query parameters.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add path and query params', 'Add default and optional params']::text[], array['Learn: Path & Query Parameters (45 min)', 'Code: apply path & query parameters in practice (45 min)', 'Notes + GitHub commit for Day 63 (30 min)']::text[], '', array['Path vs query parameters?', 'How are types validated?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 64, 'Pydantic Models & Validation', '2h', 'Validate input with Pydantic models.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define request models', 'Add field validators']::text[], array['Learn: Pydantic Models & Validation (45 min)', 'Code: apply pydantic models & validation in practice (45 min)', 'Notes + GitHub commit for Day 64 (30 min)']::text[], '', array['What does Pydantic do?', 'How do you add custom validation?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 65, 'Request Body & Response Models', '2h', 'Shape requests and responses with models.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a response_model', 'Exclude fields from responses']::text[], array['Learn: Request Body & Response Models (45 min)', 'Code: apply request body & response models in practice (45 min)', 'Notes + GitHub commit for Day 65 (30 min)']::text[], '', array['Why use response_model?', 'How do you hide fields?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 66, 'Status Codes & Error Handling', '2h', 'Return correct statuses and raise HTTPException.', '{}'::text[], '{}'::text[], '{}'::text[], array['Raise 404 and 400 errors', 'Add an exception handler']::text[], array['Learn: Status Codes & Error Handling (45 min)', 'Code: apply status codes & error handling in practice (45 min)', 'Notes + GitHub commit for Day 66 (30 min)']::text[], '', array['When return 422?', 'How do you customize errors?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 67, 'Dependency Injection', '2h', 'Share logic with Depends().', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a dependency for DB sessions', 'Inject query params']::text[], array['Learn: Dependency Injection (45 min)', 'Code: apply dependency injection in practice (45 min)', 'Notes + GitHub commit for Day 67 (30 min)']::text[], '', array['Why use dependency injection?', 'What can a dependency return?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 68, 'Routers & Project Structure', '2h', 'Organize endpoints with APIRouter.', '{}'::text[], '{}'::text[], '{}'::text[], array['Split routes into routers', 'Structure the project into packages']::text[], array['Learn: Routers & Project Structure (45 min)', 'Code: apply routers & project structure in practice (45 min)', 'Notes + GitHub commit for Day 68 (30 min)']::text[], '', array['Why split into routers?', 'How do you version an API?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 69, 'Async Endpoints', '4h', 'Write async endpoints and understand when they help.', '{}'::text[], '{}'::text[], '{}'::text[], array['Convert an endpoint to async', 'Await an async DB call']::text[], array['Learn: Async Endpoints (45 min)', 'Code: apply async endpoints in practice (45 min)', 'Notes + GitHub commit for Day 69 (30 min)']::text[], '', array['When is async worth it?', 'What blocks the event loop?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 70, 'Database Integration', '4h', 'Connect PostgreSQL with SQLAlchemy.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define ORM models', 'Open sessions via a dependency']::text[], array['Learn: Database Integration (45 min)', 'Code: apply database integration in practice (45 min)', 'Notes + GitHub commit for Day 70 (30 min)']::text[], '', array['What is an ORM?', 'How do you manage sessions?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 71, 'CRUD API with Postgres', '2h', 'Build full CRUD endpoints backed by the DB.', '{}'::text[], '{}'::text[], '{}'::text[], array['Implement create/read/update/delete', 'Return proper status codes']::text[], array['Learn: CRUD API with Postgres (45 min)', 'Code: apply crud api with postgres in practice (45 min)', 'Notes + GitHub commit for Day 71 (30 min)']::text[], '', array['How do you prevent SQL injection?', 'Where does validation belong?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 72, 'Migrations with Alembic', '2h', 'Version the schema with Alembic.', '{}'::text[], '{}'::text[], '{}'::text[], array['Init Alembic', 'Autogenerate and apply a migration']::text[], array['Learn: Migrations with Alembic (45 min)', 'Code: apply migrations with alembic in practice (45 min)', 'Notes + GitHub commit for Day 72 (30 min)']::text[], '', array['Why version schema changes?', 'What is autogenerate?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 73, 'Password Hashing', '2h', 'Store passwords securely with bcrypt/argon2.', '{}'::text[], '{}'::text[], '{}'::text[], array['Hash and verify a password', 'Add a users table']::text[], array['Learn: Password Hashing (45 min)', 'Code: apply password hashing in practice (45 min)', 'Notes + GitHub commit for Day 73 (30 min)']::text[], '', array['Why never store plaintext passwords?', 'What is a salt?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 74, 'JWT Authentication', '2h', 'Issue and verify JWT access tokens.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a login endpoint', 'Protect a route with a token']::text[], array['Learn: JWT Authentication (45 min)', 'Code: apply jwt authentication in practice (45 min)', 'Notes + GitHub commit for Day 74 (30 min)']::text[], '', array['What is inside a JWT?', 'Where do you store tokens?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 75, 'OAuth2 & Scopes', '2h', 'Use OAuth2 password flow and scopes.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add OAuth2PasswordBearer', 'Enforce a scope']::text[], array['Learn: OAuth2 & Scopes (45 min)', 'Code: apply oauth2 & scopes in practice (45 min)', 'Notes + GitHub commit for Day 75 (30 min)']::text[], '', array['What is OAuth2?', 'What are scopes for?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 76, 'Middleware & CORS', '4h', 'Add middleware and configure CORS.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a request-timing middleware', 'Enable CORS for a frontend']::text[], array['Learn: Middleware & CORS (45 min)', 'Code: apply middleware & cors in practice (45 min)', 'Notes + GitHub commit for Day 76 (30 min)']::text[], '', array['What is CORS?', 'When do you need middleware?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 77, 'Background Tasks', '4h', 'Run work after responding with BackgroundTasks.', '{}'::text[], '{}'::text[], '{}'::text[], array['Send a fake email in the background', 'Log asynchronously']::text[], array['Learn: Background Tasks (45 min)', 'Code: apply background tasks in practice (45 min)', 'Notes + GitHub commit for Day 77 (30 min)']::text[], '', array['BackgroundTasks vs a task queue?', 'When is background work unsafe?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 78, 'File Uploads', '2h', 'Accept and store uploaded files.', '{}'::text[], '{}'::text[], '{}'::text[], array['Accept an UploadFile', 'Validate content type']::text[], array['Learn: File Uploads (45 min)', 'Code: apply file uploads in practice (45 min)', 'Notes + GitHub commit for Day 78 (30 min)']::text[], '', array['How do you stream large uploads?', 'How do you limit file size?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 79, 'Redis Setup & Basics', '2h', 'Run Redis and use core data types.', '{}'::text[], '{}'::text[], '{}'::text[], array['Set/get keys', 'Use hashes and lists']::text[], array['Learn: Redis Setup & Basics (45 min)', 'Code: apply redis setup & basics in practice (45 min)', 'Notes + GitHub commit for Day 79 (30 min)']::text[], '', array['What is Redis used for?', 'Is Redis single-threaded?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 80, 'Caching with Redis', '2h', 'Cache expensive results with TTLs.', '{}'::text[], '{}'::text[], '{}'::text[], array['Cache a DB lookup', 'Set an expiry']::text[], array['Learn: Caching with Redis (45 min)', 'Code: apply caching with redis in practice (45 min)', 'Notes + GitHub commit for Day 80 (30 min)']::text[], '', array['What is cache invalidation?', 'What is a TTL?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 81, 'Redis as Session Store', '2h', 'Store sessions and short-lived state in Redis.', '{}'::text[], '{}'::text[], '{}'::text[], array['Store a session token', 'Expire idle sessions']::text[], array['Learn: Redis as Session Store (45 min)', 'Code: apply redis as session store in practice (45 min)', 'Notes + GitHub commit for Day 81 (30 min)']::text[], '', array['Why store sessions in Redis?', 'Cookie vs token sessions?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 82, 'Rate Limiting with Redis', '2h', 'Limit request rates per client.', '{}'::text[], '{}'::text[], '{}'::text[], array['Implement a fixed-window limiter', 'Return 429 on overflow']::text[], array['Learn: Rate Limiting with Redis (45 min)', 'Code: apply rate limiting with redis in practice (45 min)', 'Notes + GitHub commit for Day 82 (30 min)']::text[], '', array['Fixed vs sliding window?', 'What status code for rate limits?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 83, 'Redis Pub/Sub', '4h', 'Publish and subscribe to channels.', '{}'::text[], '{}'::text[], '{}'::text[], array['Publish an event', 'Subscribe and react']::text[], array['Learn: Redis Pub/Sub (45 min)', 'Code: apply redis pub/sub in practice (45 min)', 'Notes + GitHub commit for Day 83 (30 min)']::text[], '', array['When use pub/sub?', 'Pub/sub vs a queue?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 84, 'Celery Task Queue', '4h', 'Offload work to Celery workers with Redis broker.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define a Celery task', 'Call it asynchronously']::text[], array['Learn: Celery Task Queue (45 min)', 'Code: apply celery task queue in practice (45 min)', 'Notes + GitHub commit for Day 84 (30 min)']::text[], '', array['Why use a task queue?', 'What is a broker?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 85, 'WebSockets', '2h', 'Push real-time updates over WebSockets.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a WebSocket endpoint', 'Broadcast messages']::text[], array['Learn: WebSockets (45 min)', 'Code: apply websockets in practice (45 min)', 'Notes + GitHub commit for Day 85 (30 min)']::text[], '', array['WebSocket vs HTTP polling?', 'How do you scale WebSockets?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 86, 'API Testing', '2h', 'Test endpoints with pytest and httpx.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write tests for auth and CRUD', 'Use a test database']::text[], array['Learn: API Testing (45 min)', 'Code: apply api testing in practice (45 min)', 'Notes + GitHub commit for Day 86 (30 min)']::text[], '', array['How do you test protected routes?', 'What is a test client?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 87, 'API Documentation & OpenAPI', '2h', 'Improve auto-generated OpenAPI docs.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add descriptions and examples', 'Tag and group routes']::text[], array['Learn: API Documentation & OpenAPI (45 min)', 'Code: apply api documentation & openapi in practice (45 min)', 'Notes + GitHub commit for Day 87 (30 min)']::text[], '', array['What is OpenAPI?', 'How do you document errors?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 88, 'Pagination & Filtering', '2h', 'Add pagination, sorting, and filtering.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add limit/offset paging', 'Add query filters']::text[], array['Learn: Pagination & Filtering (45 min)', 'Code: apply pagination & filtering in practice (45 min)', 'Notes + GitHub commit for Day 88 (30 min)']::text[], '', array['Offset vs cursor pagination?', 'How do you paginate large tables?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 89, 'Deployment Prep', '2h', 'Run with gunicorn/uvicorn workers and config.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add settings via env vars', 'Run multiple workers']::text[], array['Learn: Deployment Prep (45 min)', 'Code: apply deployment prep in practice (45 min)', 'Notes + GitHub commit for Day 89 (30 min)']::text[], '', array['How many workers should you run?', 'How do you manage config?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 3), 90, 'Project: URL Shortener API', '4h', 'Ship a cached, authenticated URL shortener with tests.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize endpoints and Redis caching', 'Add tests and docs']::text[], array['Learn: Project: URL Shortener API (45 min)', 'Code: apply project: url shortener api in practice (45 min)', 'Notes + GitHub commit for Day 90 (30 min)']::text[], '', array['Walk through the request flow.', 'How does caching improve it?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 4: Docker + Kubernetes
insert into public.months (month_number, title, goal, project, status)
values (4, 'Docker + Kubernetes', 'Containerize services and orchestrate them reliably with Kubernetes.', '{"name":"Containerized & Orchestrated App","prd":"Dockerize the FastAPI + Postgres + Redis stack and deploy it to Kubernetes with autoscaling.","architecture":"Multi-stage Docker images, Compose for local dev, K8s Deployments/Services/Ingress for prod.","techStack":["Docker","Docker Compose","Kubernetes","Helm","kubectl"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 91, 'Containers vs VMs', '4h', 'Understand containers, images, and isolation.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run a public image', 'Inspect a running container']::text[], array['Learn: Containers vs VMs (45 min)', 'Code: apply containers vs vms in practice (45 min)', 'Notes + GitHub commit for Day 91 (30 min)']::text[], '', array['Container vs VM?', 'What is an image layer?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 92, 'Docker Installation & CLI', '2h', 'Use core docker CLI commands.', '{}'::text[], '{}'::text[], '{}'::text[], array['Pull, run, stop, rm containers', 'List images and containers']::text[], array['Learn: Docker Installation & CLI (45 min)', 'Code: apply docker installation & cli in practice (45 min)', 'Notes + GitHub commit for Day 92 (30 min)']::text[], '', array['What does docker run do?', 'Difference between image and container?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 93, 'Images & Dockerfile', '2h', 'Write a Dockerfile for a Python app.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a Dockerfile', 'Build the image']::text[], array['Learn: Images & Dockerfile (45 min)', 'Code: apply images & dockerfile in practice (45 min)', 'Notes + GitHub commit for Day 93 (30 min)']::text[], '', array['What does each Dockerfile instruction do?', 'Why order layers carefully?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 94, 'Building & Tagging Images', '2h', 'Build, tag, and version images.', '{}'::text[], '{}'::text[], '{}'::text[], array['Tag an image with a version', 'Rebuild after a change']::text[], array['Learn: Building & Tagging Images (45 min)', 'Code: apply building & tagging images in practice (45 min)', 'Notes + GitHub commit for Day 94 (30 min)']::text[], '', array['Why tag images?', 'What is the latest tag pitfall?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 95, 'Docker Volumes', '2h', 'Persist data with volumes and bind mounts.', '{}'::text[], '{}'::text[], '{}'::text[], array['Mount a volume for Postgres', 'Use a bind mount for code']::text[], array['Learn: Docker Volumes (45 min)', 'Code: apply docker volumes in practice (45 min)', 'Notes + GitHub commit for Day 95 (30 min)']::text[], '', array['Volume vs bind mount?', 'Where does volume data live?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 96, 'Docker Networking', '2h', 'Connect containers over networks.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a user-defined network', 'Connect two containers by name']::text[], array['Learn: Docker Networking (45 min)', 'Code: apply docker networking in practice (45 min)', 'Notes + GitHub commit for Day 96 (30 min)']::text[], '', array['How do containers find each other?', 'What is the default bridge network?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 97, 'Env Variables & Secrets', '4h', 'Configure containers via environment.', '{}'::text[], '{}'::text[], '{}'::text[], array['Pass env vars at run', 'Use an env file']::text[], array['Learn: Env Variables & Secrets (45 min)', 'Code: apply env variables & secrets in practice (45 min)', 'Notes + GitHub commit for Day 97 (30 min)']::text[], '', array['How do you handle secrets in Docker?', 'Why avoid baking secrets into images?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 98, 'Docker Compose Basics', '4h', 'Define multi-service apps in Compose.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a compose file', 'Bring the stack up/down']::text[], array['Learn: Docker Compose Basics (45 min)', 'Code: apply docker compose basics in practice (45 min)', 'Notes + GitHub commit for Day 98 (30 min)']::text[], '', array['What does Compose solve?', 'depends_on limitations?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 99, 'Multi-container Apps', '2h', 'Wire app + db + cache with Compose.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add Postgres and Redis services', 'Use service names as hosts']::text[], array['Learn: Multi-container Apps (45 min)', 'Code: apply multi-container apps in practice (45 min)', 'Notes + GitHub commit for Day 99 (30 min)']::text[], '', array['How do services communicate?', 'How do you seed a DB in Compose?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 100, 'Dockerizing the Stack', '2h', 'Containerize FastAPI + Postgres + Redis together.', '{}'::text[], '{}'::text[], '{}'::text[], array['Compose the full stack', 'Run migrations in a container']::text[], array['Learn: Dockerizing the Stack (45 min)', 'Code: apply dockerizing the stack in practice (45 min)', 'Notes + GitHub commit for Day 100 (30 min)']::text[], '', array['Where do migrations run?', 'How do you wait for the DB?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 101, 'Multi-stage Builds', '2h', 'Shrink images with multi-stage builds.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a builder stage', 'Copy only artifacts to final stage']::text[], array['Learn: Multi-stage Builds (45 min)', 'Code: apply multi-stage builds in practice (45 min)', 'Notes + GitHub commit for Day 101 (30 min)']::text[], '', array['Why use multi-stage builds?', 'What goes in the final image?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 102, 'Image Optimization', '2h', 'Reduce image size and build time.', '{}'::text[], '{}'::text[], '{}'::text[], array['Use a slim base image', 'Leverage layer caching']::text[], array['Learn: Image Optimization (45 min)', 'Code: apply image optimization in practice (45 min)', 'Notes + GitHub commit for Day 102 (30 min)']::text[], '', array['How do you cut image size?', 'What breaks layer caching?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 103, 'Docker Registry & Push', '2h', 'Push images to a registry.', '{}'::text[], '{}'::text[], '{}'::text[], array['Push to Docker Hub or GHCR', 'Pull on another machine']::text[], array['Learn: Docker Registry & Push (45 min)', 'Code: apply docker registry & push in practice (45 min)', 'Notes + GitHub commit for Day 103 (30 min)']::text[], '', array['What is a registry?', 'How do you authenticate to a registry?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 104, 'Logging & Debugging', '4h', 'Inspect logs and debug containers.', '{}'::text[], '{}'::text[], '{}'::text[], array['Read logs and exec into a container', 'Debug a crash loop']::text[], array['Learn: Logging & Debugging (45 min)', 'Code: apply logging & debugging in practice (45 min)', 'Notes + GitHub commit for Day 104 (30 min)']::text[], '', array['How do you view container logs?', 'How do you exec into a container?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 105, 'Kubernetes Concepts', '4h', 'Understand the K8s control plane and objects.', '{}'::text[], '{}'::text[], '{}'::text[], array['Diagram the cluster components', 'Read a manifest']::text[], array['Learn: Kubernetes Concepts (45 min)', 'Code: apply kubernetes concepts in practice (45 min)', 'Notes + GitHub commit for Day 105 (30 min)']::text[], '', array['What is the control plane?', 'What is a node?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 106, 'kubectl & Minikube', '2h', 'Set up a local cluster and use kubectl.', '{}'::text[], '{}'::text[], '{}'::text[], array['Start Minikube', 'Run kubectl get/describe']::text[], array['Learn: kubectl & Minikube (45 min)', 'Code: apply kubectl & minikube in practice (45 min)', 'Notes + GitHub commit for Day 106 (30 min)']::text[], '', array['What does kubectl do?', 'What is a kubeconfig?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 107, 'Pods', '2h', 'Deploy and inspect the smallest unit, the Pod.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a pod from YAML', 'Get logs and exec in']::text[], array['Learn: Pods (45 min)', 'Code: apply pods in practice (45 min)', 'Notes + GitHub commit for Day 107 (30 min)']::text[], '', array['What is a Pod?', 'Why not run pods directly in prod?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 108, 'Deployments & ReplicaSets', '2h', 'Manage stateless apps with Deployments.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a Deployment', 'Scale replicas']::text[], array['Learn: Deployments & ReplicaSets (45 min)', 'Code: apply deployments & replicasets in practice (45 min)', 'Notes + GitHub commit for Day 108 (30 min)']::text[], '', array['What does a Deployment manage?', 'What is a ReplicaSet?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 109, 'Services', '2h', 'Expose pods with ClusterIP/NodePort/LoadBalancer.', '{}'::text[], '{}'::text[], '{}'::text[], array['Expose a Deployment with a Service', 'Reach it via DNS']::text[], array['Learn: Services (45 min)', 'Code: apply services in practice (45 min)', 'Notes + GitHub commit for Day 109 (30 min)']::text[], '', array['Service types?', 'How does service discovery work?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 110, 'ConfigMaps & Secrets', '2h', 'Externalize config and secrets.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a ConfigMap', 'Mount a Secret as env']::text[], array['Learn: ConfigMaps & Secrets (45 min)', 'Code: apply configmaps & secrets in practice (45 min)', 'Notes + GitHub commit for Day 110 (30 min)']::text[], '', array['ConfigMap vs Secret?', 'Are Secrets encrypted by default?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 111, 'Volumes & PersistentVolumes', '4h', 'Persist state with PV/PVC.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a PVC', 'Mount it in a pod']::text[], array['Learn: Volumes & PersistentVolumes (45 min)', 'Code: apply volumes & persistentvolumes in practice (45 min)', 'Notes + GitHub commit for Day 111 (30 min)']::text[], '', array['What is a PVC?', 'How does dynamic provisioning work?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 112, 'Ingress', '4h', 'Route external HTTP traffic with Ingress.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add an Ingress rule', 'Route by path/host']::text[], array['Learn: Ingress (45 min)', 'Code: apply ingress in practice (45 min)', 'Notes + GitHub commit for Day 112 (30 min)']::text[], '', array['Ingress vs LoadBalancer Service?', 'What is an ingress controller?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 113, 'Namespaces & Resource Limits', '2h', 'Isolate workloads and set requests/limits.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a namespace', 'Set CPU/memory limits']::text[], array['Learn: Namespaces & Resource Limits (45 min)', 'Code: apply namespaces & resource limits in practice (45 min)', 'Notes + GitHub commit for Day 113 (30 min)']::text[], '', array['Why set resource limits?', 'requests vs limits?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 114, 'Health Checks', '2h', 'Add liveness and readiness probes.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add probes to a Deployment', 'Watch pods restart']::text[], array['Learn: Health Checks (45 min)', 'Code: apply health checks in practice (45 min)', 'Notes + GitHub commit for Day 114 (30 min)']::text[], '', array['Liveness vs readiness?', 'What happens when a probe fails?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 115, 'Horizontal Pod Autoscaling', '2h', 'Scale pods on CPU/metrics.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add an HPA', 'Load test to trigger scaling']::text[], array['Learn: Horizontal Pod Autoscaling (45 min)', 'Code: apply horizontal pod autoscaling in practice (45 min)', 'Notes + GitHub commit for Day 115 (30 min)']::text[], '', array['How does HPA decide to scale?', 'What metrics can it use?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 116, 'Helm Basics', '2h', 'Package K8s apps with Helm charts.', '{}'::text[], '{}'::text[], '{}'::text[], array['Install a chart', 'Template values']::text[], array['Learn: Helm Basics (45 min)', 'Code: apply helm basics in practice (45 min)', 'Notes + GitHub commit for Day 116 (30 min)']::text[], '', array['What problem does Helm solve?', 'What is a values file?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 117, 'Deploying the App to K8s', '2h', 'Deploy FastAPI + Postgres + Redis to the cluster.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write manifests for the stack', 'Verify with kubectl']::text[], array['Learn: Deploying the App to K8s (45 min)', 'Code: apply deploying the app to k8s in practice (45 min)', 'Notes + GitHub commit for Day 117 (30 min)']::text[], '', array['How do you deploy a stateful DB?', 'How do apps read secrets?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 118, 'Rolling Updates & Rollbacks', '4h', 'Ship changes without downtime.', '{}'::text[], '{}'::text[], '{}'::text[], array['Trigger a rolling update', 'Roll back a bad deploy']::text[], array['Learn: Rolling Updates & Rollbacks (45 min)', 'Code: apply rolling updates & rollbacks in practice (45 min)', 'Notes + GitHub commit for Day 118 (30 min)']::text[], '', array['How do rolling updates work?', 'How do you roll back?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 119, 'Monitoring Basics', '4h', 'Observe cluster and app health.', '{}'::text[], '{}'::text[], '{}'::text[], array['View metrics and events', 'Read pod resource usage']::text[], array['Learn: Monitoring Basics (45 min)', 'Code: apply monitoring basics in practice (45 min)', 'Notes + GitHub commit for Day 119 (30 min)']::text[], '', array['What do you monitor in K8s?', 'What is kube-state-metrics?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 4), 120, 'Project: Orchestrated App', '2h', 'Ship the full stack running on Kubernetes.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize manifests/Helm chart', 'Document the deploy']::text[], array['Learn: Project: Orchestrated App (45 min)', 'Code: apply project: orchestrated app in practice (45 min)', 'Notes + GitHub commit for Day 120 (30 min)']::text[], '', array['Walk through your deployment.', 'How does it scale and recover?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 5: AI Fundamentals + LLMs
insert into public.months (month_number, title, goal, project, status)
values (5, 'AI Fundamentals + LLMs', 'Understand modern AI/ML and build applications on large language models.', '{"name":"AI Chatbot","prd":"A chatbot with system prompts, streaming, tool calling, and conversation memory over the Claude API.","architecture":"FastAPI backend calling the Claude API with streaming and tools; React chat frontend.","techStack":["Python","Claude API","FastAPI","NumPy","Pandas"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 121, 'What is AI / ML / DL', '2h', 'Distinguish AI, machine learning, and deep learning.', '{}'::text[], '{}'::text[], '{}'::text[], array['Map real products to categories', 'Summarize the ML workflow']::text[], array['Learn: What is AI / ML / DL (45 min)', 'Code: apply what is ai / ml / dl in practice (45 min)', 'Notes + GitHub commit for Day 121 (30 min)']::text[], '', array['ML vs deep learning?', 'What is a model?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 122, 'NumPy Essentials', '2h', 'Work with arrays and vectorized operations.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create and reshape arrays', 'Vectorize a loop']::text[], array['Learn: NumPy Essentials (45 min)', 'Code: apply numpy essentials in practice (45 min)', 'Notes + GitHub commit for Day 122 (30 min)']::text[], '', array['Why is NumPy fast?', 'What is broadcasting?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 123, 'Pandas Essentials', '2h', 'Load and manipulate tabular data.', '{}'::text[], '{}'::text[], '{}'::text[], array['Load a CSV into a DataFrame', 'Filter and group rows']::text[], array['Learn: Pandas Essentials (45 min)', 'Code: apply pandas essentials in practice (45 min)', 'Notes + GitHub commit for Day 123 (30 min)']::text[], '', array['Series vs DataFrame?', 'How do you group and aggregate?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 124, 'Data Cleaning & EDA', '2h', 'Explore and clean a dataset.', '{}'::text[], '{}'::text[], '{}'::text[], array['Handle missing values', 'Plot distributions']::text[], array['Learn: Data Cleaning & EDA (45 min)', 'Code: apply data cleaning & eda in practice (45 min)', 'Notes + GitHub commit for Day 124 (30 min)']::text[], '', array['How do you handle NaNs?', 'What is EDA?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 125, 'ML Concepts', '4h', 'Understand supervised vs unsupervised learning.', '{}'::text[], '{}'::text[], '{}'::text[], array['Classify example tasks', 'Pick features for a problem']::text[], array['Learn: ML Concepts (45 min)', 'Code: apply ml concepts in practice (45 min)', 'Notes + GitHub commit for Day 125 (30 min)']::text[], '', array['Classification vs regression?', 'What is clustering?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 126, 'Training, Metrics, Overfitting', '4h', 'Split data and evaluate models.', '{}'::text[], '{}'::text[], '{}'::text[], array['Do a train/test split', 'Compute accuracy/precision/recall']::text[], array['Learn: Training, Metrics, Overfitting (45 min)', 'Code: apply training, metrics, overfitting in practice (45 min)', 'Notes + GitHub commit for Day 126 (30 min)']::text[], '', array['What is overfitting?', 'Precision vs recall?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 127, 'Neural Network Intuition', '2h', 'Build intuition for how neural nets learn.', '{}'::text[], '{}'::text[], '{}'::text[], array['Sketch a simple network', 'Explain gradient descent in words']::text[], array['Learn: Neural Network Intuition (45 min)', 'Code: apply neural network intuition in practice (45 min)', 'Notes + GitHub commit for Day 127 (30 min)']::text[], '', array['What is a weight?', 'What is backpropagation (intuition)?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 128, 'Embeddings Explained', '2h', 'Understand vector embeddings of meaning.', '{}'::text[], '{}'::text[], '{}'::text[], array['Embed a few sentences', 'Compare similarity']::text[], array['Learn: Embeddings Explained (45 min)', 'Code: apply embeddings explained in practice (45 min)', 'Notes + GitHub commit for Day 128 (30 min)']::text[], '', array['What is an embedding?', 'Why are similar items close in vector space?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 129, 'Transformers & Attention', '2h', 'Grasp the intuition behind attention.', '{}'::text[], '{}'::text[], '{}'::text[], array['Explain attention in your words', 'Diagram a transformer block']::text[], array['Learn: Transformers & Attention (45 min)', 'Code: apply transformers & attention in practice (45 min)', 'Notes + GitHub commit for Day 129 (30 min)']::text[], '', array['What does attention do?', 'Why did transformers replace RNNs?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 130, 'What are LLMs', '2h', 'Understand how LLMs are trained and used.', '{}'::text[], '{}'::text[], '{}'::text[], array['List LLM capabilities and limits', 'Compare model sizes']::text[], array['Learn: What are LLMs (45 min)', 'Code: apply what are llms in practice (45 min)', 'Notes + GitHub commit for Day 130 (30 min)']::text[], '', array['How is an LLM trained?', 'What is a base vs instruct model?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 131, 'Tokenization', '2h', 'See how text becomes tokens.', '{}'::text[], '{}'::text[], '{}'::text[], array['Tokenize sample text', 'Count tokens for a prompt']::text[], array['Learn: Tokenization (45 min)', 'Code: apply tokenization in practice (45 min)', 'Notes + GitHub commit for Day 131 (30 min)']::text[], '', array['What is a token?', 'Why do tokens matter for cost?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 132, 'Calling the Claude API', '4h', 'Send your first Messages API request.', '{}'::text[], '{}'::text[], '{}'::text[], array['Call the Claude API', 'Parse the response']::text[], array['Learn: Calling the Claude API (45 min)', 'Code: apply calling the claude api in practice (45 min)', 'Notes + GitHub commit for Day 132 (30 min)']::text[], '', array['What is the Messages API?', 'What is a role in a message?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 133, 'Prompt Engineering Basics', '4h', 'Write clear, effective prompts.', '{}'::text[], '{}'::text[], '{}'::text[], array['Rewrite a vague prompt', 'Add explicit instructions']::text[], array['Learn: Prompt Engineering Basics (45 min)', 'Code: apply prompt engineering basics in practice (45 min)', 'Notes + GitHub commit for Day 133 (30 min)']::text[], '', array['What makes a prompt effective?', 'Why give examples?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 134, 'System Prompts & Roles', '2h', 'Steer behavior with a system prompt.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a system prompt for a persona', 'Test role separation']::text[], array['Learn: System Prompts & Roles (45 min)', 'Code: apply system prompts & roles in practice (45 min)', 'Notes + GitHub commit for Day 134 (30 min)']::text[], '', array['What is a system prompt?', 'user vs assistant roles?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 135, 'Few-shot & Chain-of-thought', '2h', 'Improve results with examples and reasoning.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add few-shot examples', 'Ask for step-by-step reasoning']::text[], array['Learn: Few-shot & Chain-of-thought (45 min)', 'Code: apply few-shot & chain-of-thought in practice (45 min)', 'Notes + GitHub commit for Day 135 (30 min)']::text[], '', array['What is few-shot prompting?', 'When does CoT help?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 136, 'Structured Output', '2h', 'Get reliable JSON or typed output.', '{}'::text[], '{}'::text[], '{}'::text[], array['Force JSON output', 'Validate against a schema']::text[], array['Learn: Structured Output (45 min)', 'Code: apply structured output in practice (45 min)', 'Notes + GitHub commit for Day 136 (30 min)']::text[], '', array['How do you get reliable JSON?', 'Why validate model output?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 137, 'Sampling Parameters', '2h', 'Control randomness with temperature and top-p.', '{}'::text[], '{}'::text[], '{}'::text[], array['Compare temperatures', 'Set max tokens']::text[], array['Learn: Sampling Parameters (45 min)', 'Code: apply sampling parameters in practice (45 min)', 'Notes + GitHub commit for Day 137 (30 min)']::text[], '', array['What does temperature do?', 'What is top-p?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 138, 'Tool / Function Calling', '2h', 'Let the model call your tools.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define a tool schema', 'Handle a tool call']::text[], array['Learn: Tool / Function Calling (45 min)', 'Code: apply tool / function calling in practice (45 min)', 'Notes + GitHub commit for Day 138 (30 min)']::text[], '', array['How does tool calling work?', 'Who executes the tool?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 139, 'Streaming Responses', '4h', 'Stream tokens for responsive UX.', '{}'::text[], '{}'::text[], '{}'::text[], array['Stream a completion', 'Render tokens as they arrive']::text[], array['Learn: Streaming Responses (45 min)', 'Code: apply streaming responses in practice (45 min)', 'Notes + GitHub commit for Day 139 (30 min)']::text[], '', array['Why stream responses?', 'How do you handle stream errors?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 140, 'Context Windows & Budgeting', '4h', 'Manage the context window and token budget.', '{}'::text[], '{}'::text[], '{}'::text[], array['Trim history to fit context', 'Estimate token usage']::text[], array['Learn: Context Windows & Budgeting (45 min)', 'Code: apply context windows & budgeting in practice (45 min)', 'Notes + GitHub commit for Day 140 (30 min)']::text[], '', array['What is a context window?', 'What happens when you exceed it?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 141, 'Prompt Caching', '2h', 'Cache repeated prompt prefixes to cut cost/latency.', '{}'::text[], '{}'::text[], '{}'::text[], array['Mark a cacheable prefix', 'Measure savings']::text[], array['Learn: Prompt Caching (45 min)', 'Code: apply prompt caching in practice (45 min)', 'Notes + GitHub commit for Day 141 (30 min)']::text[], '', array['What is prompt caching?', 'When does it help most?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 142, 'Handling Hallucinations', '2h', 'Reduce and detect fabricated answers.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add grounding instructions', 'Ask the model to cite/abstain']::text[], array['Learn: Handling Hallucinations (45 min)', 'Code: apply handling hallucinations in practice (45 min)', 'Notes + GitHub commit for Day 142 (30 min)']::text[], '', array['Why do LLMs hallucinate?', 'How do you reduce hallucinations?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 143, 'Cost & Latency Optimization', '2h', 'Balance quality, cost, and speed.', '{}'::text[], '{}'::text[], '{}'::text[], array['Pick a model per task', 'Cut prompt size']::text[], array['Learn: Cost & Latency Optimization (45 min)', 'Code: apply cost & latency optimization in practice (45 min)', 'Notes + GitHub commit for Day 143 (30 min)']::text[], '', array['How do you choose a model tier?', 'What drives cost?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 144, 'Multimodal Basics', '2h', 'Send images to a vision-capable model.', '{}'::text[], '{}'::text[], '{}'::text[], array['Send an image + question', 'Extract text from an image']::text[], array['Learn: Multimodal Basics (45 min)', 'Code: apply multimodal basics in practice (45 min)', 'Notes + GitHub commit for Day 144 (30 min)']::text[], '', array['What is multimodal input?', 'When use vision models?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 145, 'Safety & Guardrails', '2h', 'Add moderation and safety guardrails.', '{}'::text[], '{}'::text[], '{}'::text[], array['Filter unsafe input/output', 'Add a refusal path']::text[], array['Learn: Safety & Guardrails (45 min)', 'Code: apply safety & guardrails in practice (45 min)', 'Notes + GitHub commit for Day 145 (30 min)']::text[], '', array['What are guardrails?', 'How do you moderate content?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 146, 'LLM Evaluation Basics', '4h', 'Measure output quality systematically.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write 5 eval cases', 'Score outputs against expectations']::text[], array['Learn: LLM Evaluation Basics (45 min)', 'Code: apply llm evaluation basics in practice (45 min)', 'Notes + GitHub commit for Day 146 (30 min)']::text[], '', array['How do you evaluate an LLM feature?', 'What is an eval set?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 147, 'Building a Chat Loop', '4h', 'Assemble a multi-turn chat backend.', '{}'::text[], '{}'::text[], '{}'::text[], array['Maintain message history', 'Stream responses to a client']::text[], array['Learn: Building a Chat Loop (45 min)', 'Code: apply building a chat loop in practice (45 min)', 'Notes + GitHub commit for Day 147 (30 min)']::text[], '', array['How do you manage turn history?', 'How do you cap history length?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 148, 'Conversation Memory', '2h', 'Persist and summarize conversation state.', '{}'::text[], '{}'::text[], '{}'::text[], array['Store history per session', 'Summarize old turns']::text[], array['Learn: Conversation Memory (45 min)', 'Code: apply conversation memory in practice (45 min)', 'Notes + GitHub commit for Day 148 (30 min)']::text[], '', array['How do you handle long chats?', 'What is memory summarization?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 149, 'Chatbot UX Patterns', '2h', 'Design good chat interactions.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add loading/streaming states', 'Handle errors gracefully']::text[], array['Learn: Chatbot UX Patterns (45 min)', 'Code: apply chatbot ux patterns in practice (45 min)', 'Notes + GitHub commit for Day 149 (30 min)']::text[], '', array['What makes chat UX good?', 'How do you show tool use?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 5), 150, 'Project: AI Chatbot', '2h', 'Ship a streaming chatbot with tools and memory.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize backend and frontend', 'Add a few tools']::text[], array['Learn: Project: AI Chatbot (45 min)', 'Code: apply project: ai chatbot in practice (45 min)', 'Notes + GitHub commit for Day 150 (30 min)']::text[], '', array['Walk through a chat request.', 'How does tool calling work here?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 6: RAG + Vector Databases
insert into public.months (month_number, title, goal, project, status)
values (6, 'RAG + Vector Databases', 'Build retrieval-augmented generation systems grounded in your own documents.', '{"name":"PDF Chat / Resume Reviewer","prd":"Chat over uploaded PDFs with citations, then extend it into an AI resume reviewer.","architecture":"Ingest → chunk → embed → store in pgvector → retrieve → grounded generation with citations.","techStack":["pgvector","Embeddings","Claude API","FastAPI","Chroma"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 151, 'Why RAG', '2h', 'Understand when and why to use retrieval augmentation.', '{}'::text[], '{}'::text[], '{}'::text[], array['List RAG vs fine-tuning tradeoffs', 'Identify a RAG use case']::text[], array['Learn: Why RAG (45 min)', 'Code: apply why rag in practice (45 min)', 'Notes + GitHub commit for Day 151 (30 min)']::text[], '', array['What problem does RAG solve?', 'RAG vs fine-tuning?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 152, 'Document Loading & Parsing', '2h', 'Extract text from PDFs and other formats.', '{}'::text[], '{}'::text[], '{}'::text[], array['Parse a PDF to text', 'Handle a messy document']::text[], array['Learn: Document Loading & Parsing (45 min)', 'Code: apply document loading & parsing in practice (45 min)', 'Notes + GitHub commit for Day 152 (30 min)']::text[], '', array['Why is PDF parsing hard?', 'How do you handle tables/images?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 153, 'Chunking Strategies', '4h', 'Split documents into retrievable chunks.', '{}'::text[], '{}'::text[], '{}'::text[], array['Chunk by tokens with overlap', 'Compare chunk sizes']::text[], array['Learn: Chunking Strategies (45 min)', 'Code: apply chunking strategies in practice (45 min)', 'Notes + GitHub commit for Day 153 (30 min)']::text[], '', array['Why chunk documents?', 'What does overlap do?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 154, 'Embeddings Deep Dive', '4h', 'Generate and store text embeddings.', '{}'::text[], '{}'::text[], '{}'::text[], array['Embed chunks', 'Inspect vector dimensions']::text[], array['Learn: Embeddings Deep Dive (45 min)', 'Code: apply embeddings deep dive in practice (45 min)', 'Notes + GitHub commit for Day 154 (30 min)']::text[], '', array['What determines embedding quality?', 'How do you pick an embedding model?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 155, 'Vector Similarity', '2h', 'Measure similarity with cosine/dot/L2.', '{}'::text[], '{}'::text[], '{}'::text[], array['Compute cosine similarity', 'Rank chunks by similarity']::text[], array['Learn: Vector Similarity (45 min)', 'Code: apply vector similarity in practice (45 min)', 'Notes + GitHub commit for Day 155 (30 min)']::text[], '', array['What is cosine similarity?', 'Cosine vs dot product?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 156, 'Vector DB Overview', '2h', 'Compare pgvector, Chroma, Qdrant, Pinecone.', '{}'::text[], '{}'::text[], '{}'::text[], array['List tradeoffs of each', 'Pick one for the project']::text[], array['Learn: Vector DB Overview (45 min)', 'Code: apply vector db overview in practice (45 min)', 'Notes + GitHub commit for Day 156 (30 min)']::text[], '', array['Why use a vector DB?', 'When is pgvector enough?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 157, 'pgvector Setup', '2h', 'Enable and configure pgvector in Postgres.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a vector column', 'Add a vector index']::text[], array['Learn: pgvector Setup (45 min)', 'Code: apply pgvector setup in practice (45 min)', 'Notes + GitHub commit for Day 157 (30 min)']::text[], '', array['What index types does pgvector support?', 'Why index vectors?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 158, 'Storing & Querying Embeddings', '2h', 'Store chunks and run similarity search.', '{}'::text[], '{}'::text[], '{}'::text[], array['Insert embedded chunks', 'Query nearest neighbors']::text[], array['Learn: Storing & Querying Embeddings (45 min)', 'Code: apply storing & querying embeddings in practice (45 min)', 'Notes + GitHub commit for Day 158 (30 min)']::text[], '', array['What is a nearest-neighbor query?', 'How does an ANN index differ from exact?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 159, 'Retrieval Pipeline', '2h', 'Build ingest → retrieve end to end.', '{}'::text[], '{}'::text[], '{}'::text[], array['Wire ingestion and retrieval', 'Return top-k chunks']::text[], array['Learn: Retrieval Pipeline (45 min)', 'Code: apply retrieval pipeline in practice (45 min)', 'Notes + GitHub commit for Day 159 (30 min)']::text[], '', array['What is top-k?', 'Where does retrieval fit in the pipeline?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 160, 'RAG Prompt Construction', '4h', 'Assemble context + question into a prompt.', '{}'::text[], '{}'::text[], '{}'::text[], array['Build a grounded prompt', 'Add instructions to use only context']::text[], array['Learn: RAG Prompt Construction (45 min)', 'Code: apply rag prompt construction in practice (45 min)', 'Notes + GitHub commit for Day 160 (30 min)']::text[], '', array['How do you stop the model straying from context?', 'How much context is too much?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 161, 'Chroma / Qdrant Basics', '4h', 'Use a dedicated vector store.', '{}'::text[], '{}'::text[], '{}'::text[], array['Insert and query in Chroma', 'Attach metadata']::text[], array['Learn: Chroma / Qdrant Basics (45 min)', 'Code: apply chroma / qdrant basics in practice (45 min)', 'Notes + GitHub commit for Day 161 (30 min)']::text[], '', array['Why choose a dedicated store?', 'What is a collection?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 162, 'Metadata Filtering', '2h', 'Filter retrieval by metadata.', '{}'::text[], '{}'::text[], '{}'::text[], array['Filter by document/source', 'Combine filters with search']::text[], array['Learn: Metadata Filtering (45 min)', 'Code: apply metadata filtering in practice (45 min)', 'Notes + GitHub commit for Day 162 (30 min)']::text[], '', array['Why filter by metadata?', 'How does filtering affect recall?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 163, 'Hybrid Search', '2h', 'Combine keyword and vector search.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run keyword + vector', 'Merge and score results']::text[], array['Learn: Hybrid Search (45 min)', 'Code: apply hybrid search in practice (45 min)', 'Notes + GitHub commit for Day 163 (30 min)']::text[], '', array['Why hybrid search?', 'When does keyword beat vector?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 164, 'Reranking', '2h', 'Reorder retrieved chunks with a reranker.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a reranking step', 'Compare with/without']::text[], array['Learn: Reranking (45 min)', 'Code: apply reranking in practice (45 min)', 'Notes + GitHub commit for Day 164 (30 min)']::text[], '', array['What does a reranker do?', 'Why rerank after retrieval?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 165, 'RAG Retrieval Evaluation', '2h', 'Measure retrieval quality.', '{}'::text[], '{}'::text[], '{}'::text[], array['Build a small eval set', 'Compute recall@k']::text[], array['Learn: RAG Retrieval Evaluation (45 min)', 'Code: apply rag retrieval evaluation in practice (45 min)', 'Notes + GitHub commit for Day 165 (30 min)']::text[], '', array['What is recall@k?', 'How do you know retrieval is good?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 166, 'Handling Large Documents', '2h', 'Scale ingestion for big documents.', '{}'::text[], '{}'::text[], '{}'::text[], array['Batch embed large files', 'Track ingestion progress']::text[], array['Learn: Handling Large Documents (45 min)', 'Code: apply handling large documents in practice (45 min)', 'Notes + GitHub commit for Day 166 (30 min)']::text[], '', array['How do you ingest large corpora?', 'How do you avoid rate limits?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 167, 'Citations & Attribution', '4h', 'Return sources with answers.', '{}'::text[], '{}'::text[], '{}'::text[], array['Attach chunk sources to answers', 'Render citations']::text[], array['Learn: Citations & Attribution (45 min)', 'Code: apply citations & attribution in practice (45 min)', 'Notes + GitHub commit for Day 167 (30 min)']::text[], '', array['Why cite sources?', 'How do you map answer to source?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 168, 'Chat over PDFs', '4h', 'Assemble the full PDF chat flow.', '{}'::text[], '{}'::text[], '{}'::text[], array['Upload → ingest → chat', 'Show cited passages']::text[], array['Learn: Chat over PDFs (45 min)', 'Code: apply chat over pdfs in practice (45 min)', 'Notes + GitHub commit for Day 168 (30 min)']::text[], '', array['Walk through the PDF chat flow.', 'How do you handle a question with no answer?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 169, 'Multi-document RAG', '2h', 'Retrieve across many documents.', '{}'::text[], '{}'::text[], '{}'::text[], array['Ingest multiple PDFs', 'Scope queries to a document set']::text[], array['Learn: Multi-document RAG (45 min)', 'Code: apply multi-document rag in practice (45 min)', 'Notes + GitHub commit for Day 169 (30 min)']::text[], '', array['How do you scope retrieval?', 'How do you avoid cross-document leakage?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 170, 'Caching & Cost in RAG', '2h', 'Cache embeddings and answers.', '{}'::text[], '{}'::text[], '{}'::text[], array['Cache embeddings', 'Reuse retrieved context']::text[], array['Learn: Caching & Cost in RAG (45 min)', 'Code: apply caching & cost in rag in practice (45 min)', 'Notes + GitHub commit for Day 170 (30 min)']::text[], '', array['What can you cache in RAG?', 'How do you cut embedding cost?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 171, 'Chunk Size Tuning', '2h', 'Tune chunking for your data.', '{}'::text[], '{}'::text[], '{}'::text[], array['Sweep chunk sizes', 'Measure answer quality']::text[], array['Learn: Chunk Size Tuning (45 min)', 'Code: apply chunk size tuning in practice (45 min)', 'Notes + GitHub commit for Day 171 (30 min)']::text[], '', array['How does chunk size affect quality?', 'How do you tune it?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 172, 'Query Rewriting', '2h', 'Improve retrieval with query expansion.', '{}'::text[], '{}'::text[], '{}'::text[], array['Rewrite a user query', 'Generate sub-queries']::text[], array['Learn: Query Rewriting (45 min)', 'Code: apply query rewriting in practice (45 min)', 'Notes + GitHub commit for Day 172 (30 min)']::text[], '', array['Why rewrite queries?', 'What is query expansion?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 173, 'Hallucination Guardrails', '2h', 'Force answers to stay grounded.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add abstain-if-unsure logic', 'Detect unsupported claims']::text[], array['Learn: Hallucination Guardrails (45 min)', 'Code: apply hallucination guardrails in practice (45 min)', 'Notes + GitHub commit for Day 173 (30 min)']::text[], '', array['How do you keep RAG grounded?', 'When should the system say "I don''t know"?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 174, 'RAG Observability', '4h', 'Trace and debug retrieval and generation.', '{}'::text[], '{}'::text[], '{}'::text[], array['Log retrieved chunks', 'Trace a bad answer']::text[], array['Learn: RAG Observability (45 min)', 'Code: apply rag observability in practice (45 min)', 'Notes + GitHub commit for Day 174 (30 min)']::text[], '', array['What do you log in a RAG system?', 'How do you debug a wrong answer?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 175, 'Incremental Indexing', '4h', 'Update the index as documents change.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add/update/delete a document', 'Re-embed changed chunks']::text[], array['Learn: Incremental Indexing (45 min)', 'Code: apply incremental indexing in practice (45 min)', 'Notes + GitHub commit for Day 175 (30 min)']::text[], '', array['How do you keep an index fresh?', 'How do you handle deletions?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 176, 'Access Control on Documents', '2h', 'Restrict retrieval by user permissions.', '{}'::text[], '{}'::text[], '{}'::text[], array['Filter by user access', 'Test isolation between users']::text[], array['Learn: Access Control on Documents (45 min)', 'Code: apply access control on documents in practice (45 min)', 'Notes + GitHub commit for Day 176 (30 min)']::text[], '', array['How do you enforce per-user access?', 'Why is metadata filtering a security concern?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 177, 'RAG Evaluation Harness', '2h', 'Automate end-to-end RAG evaluation.', '{}'::text[], '{}'::text[], '{}'::text[], array['Score answers with an LLM judge', 'Track metrics over changes']::text[], array['Learn: RAG Evaluation Harness (45 min)', 'Code: apply rag evaluation harness in practice (45 min)', 'Notes + GitHub commit for Day 177 (30 min)']::text[], '', array['What is LLM-as-judge?', 'What metrics matter for RAG?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 178, 'Deploying a RAG Service', '2h', 'Serve RAG behind an API.', '{}'::text[], '{}'::text[], '{}'::text[], array['Expose ingest and query endpoints', 'Add auth and limits']::text[], array['Learn: Deploying a RAG Service (45 min)', 'Code: apply deploying a rag service in practice (45 min)', 'Notes + GitHub commit for Day 178 (30 min)']::text[], '', array['How do you deploy RAG?', 'How do you handle concurrent ingestion?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 179, 'RAG Frontend Integration', '2h', 'Connect a UI to the RAG API.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add upload and chat UI', 'Show citations in the UI']::text[], array['Learn: RAG Frontend Integration (45 min)', 'Code: apply rag frontend integration in practice (45 min)', 'Notes + GitHub commit for Day 179 (30 min)']::text[], '', array['How do you show sources in UI?', 'How do you stream RAG answers?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 6), 180, 'Project: PDF Chat / Resume Reviewer', '2h', 'Ship grounded PDF chat and extend to resume review.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize ingestion + chat + citations', 'Add resume-review prompts']::text[], array['Learn: Project: PDF Chat / Resume Reviewer (45 min)', 'Code: apply project: pdf chat / resume reviewer in practice (45 min)', 'Notes + GitHub commit for Day 180 (30 min)']::text[], '', array['Walk through your RAG pipeline.', 'How do you evaluate its quality?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 7: LangGraph + MCP + AI Agents
insert into public.months (month_number, title, goal, project, status)
values (7, 'LangGraph + MCP + AI Agents', 'Build reliable, tool-using AI agents and multi-step workflows.', '{"name":"AI Agent Platform","prd":"A platform that runs multi-step agents with tools, memory, MCP integration, and tracing.","architecture":"LangGraph state machine + tool layer + MCP servers, exposed via FastAPI with observability.","techStack":["LangGraph","MCP","Claude API","LangChain","FastAPI"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 181, 'What are AI Agents', '4h', 'Define agents and where they beat plain prompting.', '{}'::text[], '{}'::text[], '{}'::text[], array['List agent use cases', 'Identify when NOT to use an agent']::text[], array['Learn: What are AI Agents (45 min)', 'Code: apply what are ai agents in practice (45 min)', 'Notes + GitHub commit for Day 181 (30 min)']::text[], '', array['What is an AI agent?', 'When is an agent overkill?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 182, 'Agent Loops (ReAct)', '4h', 'Understand the reason-act-observe loop.', '{}'::text[], '{}'::text[], '{}'::text[], array['Trace a ReAct loop by hand', 'Diagram the loop']::text[], array['Learn: Agent Loops (ReAct) (45 min)', 'Code: apply agent loops (react) in practice (45 min)', 'Notes + GitHub commit for Day 182 (30 min)']::text[], '', array['What is the ReAct pattern?', 'What ends the loop?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 183, 'Tools & Tool Schemas', '2h', 'Define tools the agent can call.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write two tool schemas', 'Handle tool results']::text[], array['Learn: Tools & Tool Schemas (45 min)', 'Code: apply tools & tool schemas in practice (45 min)', 'Notes + GitHub commit for Day 183 (30 min)']::text[], '', array['What makes a good tool schema?', 'How do you validate tool inputs?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 184, 'LangChain Basics', '2h', 'Use LangChain building blocks.', '{}'::text[], '{}'::text[], '{}'::text[], array['Build a simple chain', 'Swap the model']::text[], array['Learn: LangChain Basics (45 min)', 'Code: apply langchain basics in practice (45 min)', 'Notes + GitHub commit for Day 184 (30 min)']::text[], '', array['What does LangChain provide?', 'What is a chain?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 185, 'LangGraph Concepts', '2h', 'Model agents as graphs of nodes and edges.', '{}'::text[], '{}'::text[], '{}'::text[], array['Diagram a graph', 'Define nodes and edges']::text[], array['Learn: LangGraph Concepts (45 min)', 'Code: apply langgraph concepts in practice (45 min)', 'Notes + GitHub commit for Day 185 (30 min)']::text[], '', array['Why model an agent as a graph?', 'What is graph state?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 186, 'Building a Simple Graph', '2h', 'Build and run a minimal LangGraph.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a two-node graph', 'Run it end to end']::text[], array['Learn: Building a Simple Graph (45 min)', 'Code: apply building a simple graph in practice (45 min)', 'Notes + GitHub commit for Day 186 (30 min)']::text[], '', array['What is a node?', 'How does data flow between nodes?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 187, 'State Management', '2h', 'Manage shared state across nodes.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define a state schema', 'Update state in a node']::text[], array['Learn: State Management (45 min)', 'Code: apply state management in practice (45 min)', 'Notes + GitHub commit for Day 187 (30 min)']::text[], '', array['How is state shared?', 'How do you reduce state?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 188, 'Conditional Edges & Routing', '4h', 'Branch based on state or model output.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a conditional edge', 'Route to different tools']::text[], array['Learn: Conditional Edges & Routing (45 min)', 'Code: apply conditional edges & routing in practice (45 min)', 'Notes + GitHub commit for Day 188 (30 min)']::text[], '', array['How does routing work?', 'How do you avoid infinite loops?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 189, 'Multi-step Workflows', '4h', 'Chain multiple reasoning/tool steps.', '{}'::text[], '{}'::text[], '{}'::text[], array['Build a 3-step workflow', 'Handle intermediate results']::text[], array['Learn: Multi-step Workflows (45 min)', 'Code: apply multi-step workflows in practice (45 min)', 'Notes + GitHub commit for Day 189 (30 min)']::text[], '', array['How do you sequence steps?', 'How do you pass results forward?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 190, 'Memory in Agents', '2h', 'Give agents short- and long-term memory.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add conversation memory', 'Persist memory across runs']::text[], array['Learn: Memory in Agents (45 min)', 'Code: apply memory in agents in practice (45 min)', 'Notes + GitHub commit for Day 190 (30 min)']::text[], '', array['Short vs long-term memory?', 'How do you store agent memory?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 191, 'Human-in-the-loop', '2h', 'Pause for human approval mid-run.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add an approval checkpoint', 'Resume after input']::text[], array['Learn: Human-in-the-loop (45 min)', 'Code: apply human-in-the-loop in practice (45 min)', 'Notes + GitHub commit for Day 191 (30 min)']::text[], '', array['When require human approval?', 'How do you pause/resume a graph?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 192, 'Streaming Agent Output', '2h', 'Stream intermediate steps to the UI.', '{}'::text[], '{}'::text[], '{}'::text[], array['Stream node updates', 'Show tool calls live']::text[], array['Learn: Streaming Agent Output (45 min)', 'Code: apply streaming agent output in practice (45 min)', 'Notes + GitHub commit for Day 192 (30 min)']::text[], '', array['Why stream agent steps?', 'What do you show users mid-run?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 193, 'Error Handling & Retries', '2h', 'Make agents robust to failures.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add retries with backoff', 'Handle a failing tool']::text[], array['Learn: Error Handling & Retries (45 min)', 'Code: apply error handling & retries in practice (45 min)', 'Notes + GitHub commit for Day 193 (30 min)']::text[], '', array['How do you retry a tool call?', 'How do you prevent runaway loops?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 194, 'Multi-agent Systems', '2h', 'Coordinate multiple specialized agents.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design a two-agent system', 'Route work between agents']::text[], array['Learn: Multi-agent Systems (45 min)', 'Code: apply multi-agent systems in practice (45 min)', 'Notes + GitHub commit for Day 194 (30 min)']::text[], '', array['When use multiple agents?', 'How do agents communicate?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 195, 'Planner / Executor Pattern', '4h', 'Separate planning from execution.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a planner node', 'Execute the plan step by step']::text[], array['Learn: Planner / Executor Pattern (45 min)', 'Code: apply planner / executor pattern in practice (45 min)', 'Notes + GitHub commit for Day 195 (30 min)']::text[], '', array['What is the planner/executor pattern?', 'Why separate planning?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 196, 'MCP Overview', '4h', 'Understand the Model Context Protocol.', '{}'::text[], '{}'::text[], '{}'::text[], array['Read the MCP spec basics', 'List MCP primitives']::text[], array['Learn: MCP Overview (45 min)', 'Code: apply mcp overview in practice (45 min)', 'Notes + GitHub commit for Day 196 (30 min)']::text[], '', array['What is MCP?', 'What does MCP standardize?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 197, 'MCP Servers & Tools', '2h', 'Understand MCP servers, tools, resources.', '{}'::text[], '{}'::text[], '{}'::text[], array['Explore an existing MCP server', 'Call an MCP tool']::text[], array['Learn: MCP Servers & Tools (45 min)', 'Code: apply mcp servers & tools in practice (45 min)', 'Notes + GitHub commit for Day 197 (30 min)']::text[], '', array['What does an MCP server expose?', 'Tools vs resources in MCP?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 198, 'Building an MCP Server', '2h', 'Build a small MCP server.', '{}'::text[], '{}'::text[], '{}'::text[], array['Implement a tool on an MCP server', 'Test it locally']::text[], array['Learn: Building an MCP Server (45 min)', 'Code: apply building an mcp server in practice (45 min)', 'Notes + GitHub commit for Day 198 (30 min)']::text[], '', array['How do you expose a tool via MCP?', 'How is an MCP server transported?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 199, 'Connecting MCP to an Agent', '2h', 'Wire MCP tools into an agent.', '{}'::text[], '{}'::text[], '{}'::text[], array['Register MCP tools with the agent', 'Run a task using them']::text[], array['Learn: Connecting MCP to an Agent (45 min)', 'Code: apply connecting mcp to an agent in practice (45 min)', 'Notes + GitHub commit for Day 199 (30 min)']::text[], '', array['How does an agent discover MCP tools?', 'Why use MCP over hardcoded tools?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 200, 'Tool Result Handling', '2h', 'Feed tool results back correctly.', '{}'::text[], '{}'::text[], '{}'::text[], array['Format tool results for the model', 'Handle large results']::text[], array['Learn: Tool Result Handling (45 min)', 'Code: apply tool result handling in practice (45 min)', 'Notes + GitHub commit for Day 200 (30 min)']::text[], '', array['How do you return tool results?', 'How do you handle huge tool outputs?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 201, 'Agent Observability & Tracing', '2h', 'Trace agent runs for debugging.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add tracing to a run', 'Inspect a failed trace']::text[], array['Learn: Agent Observability & Tracing (45 min)', 'Code: apply agent observability & tracing in practice (45 min)', 'Notes + GitHub commit for Day 201 (30 min)']::text[], '', array['What do you trace in an agent?', 'How do you debug a bad run?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 202, 'Guardrails for Agents', '4h', 'Constrain agent actions safely.', '{}'::text[], '{}'::text[], '{}'::text[], array['Restrict allowed tools', 'Add output validation']::text[], array['Learn: Guardrails for Agents (45 min)', 'Code: apply guardrails for agents in practice (45 min)', 'Notes + GitHub commit for Day 202 (30 min)']::text[], '', array['How do you sandbox agent actions?', 'What are dangerous tool calls?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 203, 'Cost Control in Agent Loops', '4h', 'Bound cost and steps per run.', '{}'::text[], '{}'::text[], '{}'::text[], array['Cap steps and tokens', 'Log cost per run']::text[], array['Learn: Cost Control in Agent Loops (45 min)', 'Code: apply cost control in agent loops in practice (45 min)', 'Notes + GitHub commit for Day 203 (30 min)']::text[], '', array['How do you cap agent cost?', 'How do you stop expensive loops?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 204, 'Evaluating Agents', '2h', 'Measure agent task success.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define success criteria', 'Score a set of tasks']::text[], array['Learn: Evaluating Agents (45 min)', 'Code: apply evaluating agents in practice (45 min)', 'Notes + GitHub commit for Day 204 (30 min)']::text[], '', array['How do you evaluate an agent?', 'What is task success rate?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 205, 'Structured Agent Outputs', '2h', 'Return typed, validated results.', '{}'::text[], '{}'::text[], '{}'::text[], array['Force structured final output', 'Validate the result']::text[], array['Learn: Structured Agent Outputs (45 min)', 'Code: apply structured agent outputs in practice (45 min)', 'Notes + GitHub commit for Day 205 (30 min)']::text[], '', array['Why force structured output?', 'How do you validate it?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 206, 'Long-running & Background Agents', '2h', 'Run agents asynchronously.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run an agent as a background job', 'Report progress']::text[], array['Learn: Long-running & Background Agents (45 min)', 'Code: apply long-running & background agents in practice (45 min)', 'Notes + GitHub commit for Day 206 (30 min)']::text[], '', array['How do you run long agents?', 'How do you report progress?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 207, 'Agent Security', '2h', 'Defend against prompt injection.', '{}'::text[], '{}'::text[], '{}'::text[], array['Test a prompt-injection attack', 'Add input sanitization']::text[], array['Learn: Agent Security (45 min)', 'Code: apply agent security in practice (45 min)', 'Notes + GitHub commit for Day 207 (30 min)']::text[], '', array['What is prompt injection?', 'How do you defend against it?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 208, 'Deploying Agents', '2h', 'Serve agents behind an API.', '{}'::text[], '{}'::text[], '{}'::text[], array['Expose an agent endpoint', 'Add auth and limits']::text[], array['Learn: Deploying Agents (45 min)', 'Code: apply deploying agents in practice (45 min)', 'Notes + GitHub commit for Day 208 (30 min)']::text[], '', array['How do you deploy an agent?', 'How do you handle concurrency?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 209, 'Agent Frontend / Chat UI', '4h', 'Build a UI that shows agent steps.', '{}'::text[], '{}'::text[], '{}'::text[], array['Render steps and tool calls', 'Add human approval UI']::text[], array['Learn: Agent Frontend / Chat UI (45 min)', 'Code: apply agent frontend / chat ui in practice (45 min)', 'Notes + GitHub commit for Day 209 (30 min)']::text[], '', array['How do you visualize agent steps?', 'How do you surface approvals?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 7), 210, 'Project: AI Agent Platform', '4h', 'Ship a multi-step agent platform with tools and tracing.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize graph, tools, MCP', 'Add tracing and limits']::text[], array['Learn: Project: AI Agent Platform (45 min)', 'Code: apply project: ai agent platform in practice (45 min)', 'Notes + GitHub commit for Day 210 (30 min)']::text[], '', array['Walk through an agent run.', 'How is it observable and safe?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 8: ClickHouse + Kafka
insert into public.months (month_number, title, goal, project, status)
values (8, 'ClickHouse + Kafka', 'Build real-time analytics pipelines over streaming event data.', '{"name":"Real-time Analytics Platform","prd":"Ingest events via Kafka, store in ClickHouse, and serve real-time aggregations through an API.","architecture":"FastAPI producers → Kafka → consumer → ClickHouse → analytics API and dashboards.","techStack":["ClickHouse","Kafka","FastAPI","Python"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 211, 'OLTP vs OLAP', '2h', 'Distinguish transactional and analytical workloads.', '{}'::text[], '{}'::text[], '{}'::text[], array['Classify example queries', 'Pick a store per workload']::text[], array['Learn: OLTP vs OLAP (45 min)', 'Code: apply oltp vs olap in practice (45 min)', 'Notes + GitHub commit for Day 211 (30 min)']::text[], '', array['OLTP vs OLAP?', 'Why not run analytics on Postgres at scale?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 212, 'ClickHouse Concepts & Install', '2h', 'Install ClickHouse and understand its model.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run ClickHouse locally', 'Connect with the client']::text[], array['Learn: ClickHouse Concepts & Install (45 min)', 'Code: apply clickhouse concepts & install in practice (45 min)', 'Notes + GitHub commit for Day 212 (30 min)']::text[], '', array['Why is ClickHouse fast for analytics?', 'What is columnar storage?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 213, 'Tables & Engines', '2h', 'Choose the right table engine.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a table with an engine', 'Compare engines']::text[], array['Learn: Tables & Engines (45 min)', 'Code: apply tables & engines in practice (45 min)', 'Notes + GitHub commit for Day 213 (30 min)']::text[], '', array['What is a table engine?', 'When use Log vs MergeTree?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 214, 'MergeTree Deep Dive', '2h', 'Understand the MergeTree family.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a MergeTree table', 'Set ORDER BY / PRIMARY KEY']::text[], array['Learn: MergeTree Deep Dive (45 min)', 'Code: apply mergetree deep dive in practice (45 min)', 'Notes + GitHub commit for Day 214 (30 min)']::text[], '', array['How does MergeTree sort data?', 'What does ORDER BY do here?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 215, 'Inserting & Querying', '2h', 'Load and query large datasets efficiently.', '{}'::text[], '{}'::text[], '{}'::text[], array['Bulk insert rows', 'Run aggregation queries']::text[], array['Learn: Inserting & Querying (45 min)', 'Code: apply inserting & querying in practice (45 min)', 'Notes + GitHub commit for Day 215 (30 min)']::text[], '', array['Why batch inserts?', 'What makes queries fast?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 216, 'Materialized Views', '4h', 'Precompute aggregates with materialized views.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a materialized view', 'Query the rollup']::text[], array['Learn: Materialized Views (45 min)', 'Code: apply materialized views in practice (45 min)', 'Notes + GitHub commit for Day 216 (30 min)']::text[], '', array['What is a materialized view?', 'How do they stay updated?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 217, 'Aggregations at Scale', '4h', 'Use aggregate functions and combinators.', '{}'::text[], '{}'::text[], '{}'::text[], array['Use uniq/quantile functions', 'Aggregate by time bucket']::text[], array['Learn: Aggregations at Scale (45 min)', 'Code: apply aggregations at scale in practice (45 min)', 'Notes + GitHub commit for Day 217 (30 min)']::text[], '', array['What is an aggregate combinator?', 'How do you compute percentiles?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 218, 'Partitioning & Sharding', '2h', 'Partition data and understand sharding.', '{}'::text[], '{}'::text[], '{}'::text[], array['Partition by month', 'Explain a sharding scheme']::text[], array['Learn: Partitioning & Sharding (45 min)', 'Code: apply partitioning & sharding in practice (45 min)', 'Notes + GitHub commit for Day 218 (30 min)']::text[], '', array['Partition vs shard?', 'How do you drop old data cheaply?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 219, 'Performance Tuning', '2h', 'Optimize ClickHouse queries.', '{}'::text[], '{}'::text[], '{}'::text[], array['Read a query plan', 'Optimize a slow query']::text[], array['Learn: Performance Tuning (45 min)', 'Code: apply performance tuning in practice (45 min)', 'Notes + GitHub commit for Day 219 (30 min)']::text[], '', array['How do you speed up a query?', 'What is a primary index in ClickHouse?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 220, 'Connecting to Apps', '2h', 'Query ClickHouse from Python.', '{}'::text[], '{}'::text[], '{}'::text[], array['Connect and query from Python', 'Stream results']::text[], array['Learn: Connecting to Apps (45 min)', 'Code: apply connecting to apps in practice (45 min)', 'Notes + GitHub commit for Day 220 (30 min)']::text[], '', array['How do apps connect to ClickHouse?', 'How do you handle large results?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 221, 'Event Data Modeling', '2h', 'Model events for analytics.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design an events schema', 'Choose a sort key']::text[], array['Learn: Event Data Modeling (45 min)', 'Code: apply event data modeling in practice (45 min)', 'Notes + GitHub commit for Day 221 (30 min)']::text[], '', array['How do you model event data?', 'What columns go in the sort key?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 222, 'Kafka Concepts', '2h', 'Understand topics, partitions, offsets.', '{}'::text[], '{}'::text[], '{}'::text[], array['Diagram a topic with partitions', 'Explain offsets']::text[], array['Learn: Kafka Concepts (45 min)', 'Code: apply kafka concepts in practice (45 min)', 'Notes + GitHub commit for Day 222 (30 min)']::text[], '', array['What is a partition?', 'What is an offset?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 223, 'Kafka Setup', '4h', 'Run Kafka locally.', '{}'::text[], '{}'::text[], '{}'::text[], array['Start a broker', 'Create a topic']::text[], array['Learn: Kafka Setup (45 min)', 'Code: apply kafka setup in practice (45 min)', 'Notes + GitHub commit for Day 223 (30 min)']::text[], '', array['What is a broker?', 'How many partitions should a topic have?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 224, 'Producers', '4h', 'Publish messages to Kafka.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a producer', 'Choose a partition key']::text[], array['Learn: Producers (45 min)', 'Code: apply producers in practice (45 min)', 'Notes + GitHub commit for Day 224 (30 min)']::text[], '', array['How does a producer choose a partition?', 'What is acks?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 225, 'Consumers & Groups', '2h', 'Consume messages with consumer groups.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a consumer', 'Scale with a consumer group']::text[], array['Learn: Consumers & Groups (45 min)', 'Code: apply consumers & groups in practice (45 min)', 'Notes + GitHub commit for Day 225 (30 min)']::text[], '', array['How do consumer groups scale?', 'What is a rebalance?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 226, 'Serialization', '2h', 'Serialize with JSON and Avro.', '{}'::text[], '{}'::text[], '{}'::text[], array['Produce/consume JSON', 'Compare with Avro']::text[], array['Learn: Serialization (45 min)', 'Code: apply serialization in practice (45 min)', 'Notes + GitHub commit for Day 226 (30 min)']::text[], '', array['Why use Avro?', 'JSON vs Avro tradeoffs?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 227, 'Schema Registry', '2h', 'Manage schemas centrally.', '{}'::text[], '{}'::text[], '{}'::text[], array['Register a schema', 'Evolve it safely']::text[], array['Learn: Schema Registry (45 min)', 'Code: apply schema registry in practice (45 min)', 'Notes + GitHub commit for Day 227 (30 min)']::text[], '', array['What is a schema registry?', 'What is schema evolution?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 228, 'Kafka Connect', '2h', 'Move data with connectors.', '{}'::text[], '{}'::text[], '{}'::text[], array['Configure a sink connector', 'Stream to a store']::text[], array['Learn: Kafka Connect (45 min)', 'Code: apply kafka connect in practice (45 min)', 'Notes + GitHub commit for Day 228 (30 min)']::text[], '', array['What is Kafka Connect?', 'Source vs sink connector?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 229, 'Stream Processing Concepts', '2h', 'Understand windows and stateful processing.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define a tumbling window', 'Explain event vs processing time']::text[], array['Learn: Stream Processing Concepts (45 min)', 'Code: apply stream processing concepts in practice (45 min)', 'Notes + GitHub commit for Day 229 (30 min)']::text[], '', array['Tumbling vs sliding window?', 'Event time vs processing time?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 230, 'Kafka → ClickHouse Pipeline', '4h', 'Stream Kafka events into ClickHouse.', '{}'::text[], '{}'::text[], '{}'::text[], array['Consume and insert into ClickHouse', 'Batch inserts']::text[], array['Learn: Kafka → ClickHouse Pipeline (45 min)', 'Code: apply kafka → clickhouse pipeline in practice (45 min)', 'Notes + GitHub commit for Day 230 (30 min)']::text[], '', array['How do you stream Kafka into ClickHouse?', 'Why batch on the consumer?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 231, 'Delivery Guarantees', '4h', 'Understand at-least/at-most/exactly-once.', '{}'::text[], '{}'::text[], '{}'::text[], array['Reason about duplicates', 'Make a consumer idempotent']::text[], array['Learn: Delivery Guarantees (45 min)', 'Code: apply delivery guarantees in practice (45 min)', 'Notes + GitHub commit for Day 231 (30 min)']::text[], '', array['What is exactly-once?', 'How do you dedupe events?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 232, 'Retention & Compaction', '2h', 'Configure retention and log compaction.', '{}'::text[], '{}'::text[], '{}'::text[], array['Set topic retention', 'Enable compaction']::text[], array['Learn: Retention & Compaction (45 min)', 'Code: apply retention & compaction in practice (45 min)', 'Notes + GitHub commit for Day 232 (30 min)']::text[], '', array['Retention vs compaction?', 'When use a compacted topic?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 233, 'Monitoring Kafka', '2h', 'Track lag and broker health.', '{}'::text[], '{}'::text[], '{}'::text[], array['Measure consumer lag', 'Watch throughput']::text[], array['Learn: Monitoring Kafka (45 min)', 'Code: apply monitoring kafka in practice (45 min)', 'Notes + GitHub commit for Day 233 (30 min)']::text[], '', array['What is consumer lag?', 'Why does lag matter?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 234, 'Dead Letter Queues', '2h', 'Handle poison messages.', '{}'::text[], '{}'::text[], '{}'::text[], array['Route failures to a DLQ', 'Reprocess from the DLQ']::text[], array['Learn: Dead Letter Queues (45 min)', 'Code: apply dead letter queues in practice (45 min)', 'Notes + GitHub commit for Day 234 (30 min)']::text[], '', array['What is a DLQ?', 'When does a message go to the DLQ?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 235, 'Ingesting Events from FastAPI', '2h', 'Produce events from your API.', '{}'::text[], '{}'::text[], '{}'::text[], array['Emit events on API actions', 'Buffer and flush']::text[], array['Learn: Ingesting Events from FastAPI (45 min)', 'Code: apply ingesting events from fastapi in practice (45 min)', 'Notes + GitHub commit for Day 235 (30 min)']::text[], '', array['Where do you produce events?', 'How do you avoid blocking requests?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 236, 'Real-time Aggregation', '2h', 'Compute live metrics from the stream.', '{}'::text[], '{}'::text[], '{}'::text[], array['Aggregate events per minute', 'Serve current metrics']::text[], array['Learn: Real-time Aggregation (45 min)', 'Code: apply real-time aggregation in practice (45 min)', 'Notes + GitHub commit for Day 236 (30 min)']::text[], '', array['How do you compute rolling metrics?', 'How fresh can metrics be?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 237, 'Dashboards over ClickHouse', '4h', 'Visualize analytics data.', '{}'::text[], '{}'::text[], '{}'::text[], array['Build a metrics query', 'Feed a chart']::text[], array['Learn: Dashboards over ClickHouse (45 min)', 'Code: apply dashboards over clickhouse in practice (45 min)', 'Notes + GitHub commit for Day 237 (30 min)']::text[], '', array['What queries power dashboards?', 'How do you keep dashboards fast?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 238, 'Scaling the Pipeline', '4h', 'Scale producers, consumers, and storage.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add partitions and consumers', 'Plan storage growth']::text[], array['Learn: Scaling the Pipeline (45 min)', 'Code: apply scaling the pipeline in practice (45 min)', 'Notes + GitHub commit for Day 238 (30 min)']::text[], '', array['How do you scale throughput?', 'What limits pipeline scale?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 239, 'Analytics API Layer', '2h', 'Expose analytics via an API.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add metrics endpoints', 'Cache hot queries']::text[], array['Learn: Analytics API Layer (45 min)', 'Code: apply analytics api layer in practice (45 min)', 'Notes + GitHub commit for Day 239 (30 min)']::text[], '', array['How do you serve analytics safely?', 'How do you cache heavy queries?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 8), 240, 'Project: Analytics Platform', '2h', 'Ship an end-to-end real-time analytics pipeline.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize Kafka → ClickHouse → API', 'Add a dashboard']::text[], array['Learn: Project: Analytics Platform (45 min)', 'Code: apply project: analytics platform in practice (45 min)', 'Notes + GitHub commit for Day 240 (30 min)']::text[], '', array['Walk through an event''s journey.', 'How does it stay real-time at scale?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 9: Elasticsearch + Neo4j
insert into public.months (month_number, title, goal, project, status)
values (9, 'Elasticsearch + Neo4j', 'Build powerful search and graph-based intelligence into applications.', '{"name":"AI Search Engine","prd":"A search engine combining full-text, vector, and graph relationships with an AI answer layer.","architecture":"Elasticsearch for search + Neo4j for relationships + LLM for answers, behind a FastAPI API.","techStack":["Elasticsearch","Neo4j","Cypher","Claude API","FastAPI"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 241, 'Search Fundamentals', '2h', 'Understand inverted indexes and relevance.', '{}'::text[], '{}'::text[], '{}'::text[], array['Explain an inverted index', 'List search use cases']::text[], array['Learn: Search Fundamentals (45 min)', 'Code: apply search fundamentals in practice (45 min)', 'Notes + GitHub commit for Day 241 (30 min)']::text[], '', array['What is an inverted index?', 'Search vs database query?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 242, 'Elasticsearch Concepts & Install', '2h', 'Run Elasticsearch and learn its model.', '{}'::text[], '{}'::text[], '{}'::text[], array['Start a node', 'Check cluster health']::text[], array['Learn: Elasticsearch Concepts & Install (45 min)', 'Code: apply elasticsearch concepts & install in practice (45 min)', 'Notes + GitHub commit for Day 242 (30 min)']::text[], '', array['What is a shard?', 'What is a replica?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 243, 'Indexes, Documents, Mappings', '2h', 'Model data with indexes and mappings.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create an index with a mapping', 'Index a document']::text[], array['Learn: Indexes, Documents, Mappings (45 min)', 'Code: apply indexes, documents, mappings in practice (45 min)', 'Notes + GitHub commit for Day 243 (30 min)']::text[], '', array['What is a mapping?', 'Dynamic vs explicit mapping?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 244, 'Indexing Data', '4h', 'Bulk-index documents efficiently.', '{}'::text[], '{}'::text[], '{}'::text[], array['Bulk index a dataset', 'Update a document']::text[], array['Learn: Indexing Data (45 min)', 'Code: apply indexing data in practice (45 min)', 'Notes + GitHub commit for Day 244 (30 min)']::text[], '', array['Why use the bulk API?', 'How are updates handled?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 245, 'Query DSL Basics', '4h', 'Query with the Elasticsearch Query DSL.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write match and term queries', 'Combine with bool']::text[], array['Learn: Query DSL Basics (45 min)', 'Code: apply query dsl basics in practice (45 min)', 'Notes + GitHub commit for Day 245 (30 min)']::text[], '', array['match vs term query?', 'What does bool do?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 246, 'Full-text Queries', '2h', 'Run analyzed full-text searches.', '{}'::text[], '{}'::text[], '{}'::text[], array['Search across fields', 'Boost fields']::text[], array['Learn: Full-text Queries (45 min)', 'Code: apply full-text queries in practice (45 min)', 'Notes + GitHub commit for Day 246 (30 min)']::text[], '', array['How does full-text scoring work?', 'How do you boost a field?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 247, 'Filters & Aggregations', '2h', 'Filter and aggregate results.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add filters to a query', 'Build a terms aggregation']::text[], array['Learn: Filters & Aggregations (45 min)', 'Code: apply filters & aggregations in practice (45 min)', 'Notes + GitHub commit for Day 247 (30 min)']::text[], '', array['Query context vs filter context?', 'What are aggregations?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 248, 'Analyzers & Tokenizers', '2h', 'Control how text is analyzed.', '{}'::text[], '{}'::text[], '{}'::text[], array['Test an analyzer', 'Add a custom analyzer']::text[], array['Learn: Analyzers & Tokenizers (45 min)', 'Code: apply analyzers & tokenizers in practice (45 min)', 'Notes + GitHub commit for Day 248 (30 min)']::text[], '', array['What does an analyzer do?', 'Why customize tokenization?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 249, 'Relevance & Scoring', '2h', 'Understand and tune relevance (BM25).', '{}'::text[], '{}'::text[], '{}'::text[], array['Inspect _score', 'Tune with boosting']::text[], array['Learn: Relevance & Scoring (45 min)', 'Code: apply relevance & scoring in practice (45 min)', 'Notes + GitHub commit for Day 249 (30 min)']::text[], '', array['What is BM25?', 'How do you tune relevance?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 250, 'Autocomplete & Suggesters', '2h', 'Build search-as-you-type.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a completion suggester', 'Handle typos with fuzziness']::text[], array['Learn: Autocomplete & Suggesters (45 min)', 'Code: apply autocomplete & suggesters in practice (45 min)', 'Notes + GitHub commit for Day 250 (30 min)']::text[], '', array['How do you build autocomplete?', 'What is fuzziness?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 251, 'Pagination & Sorting', '4h', 'Page and sort large result sets.', '{}'::text[], '{}'::text[], '{}'::text[], array['Paginate with search_after', 'Sort by field']::text[], array['Learn: Pagination & Sorting (45 min)', 'Code: apply pagination & sorting in practice (45 min)', 'Notes + GitHub commit for Day 251 (30 min)']::text[], '', array['Why avoid deep from/size paging?', 'What is search_after?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 252, 'Vector + Keyword (kNN)', '4h', 'Combine kNN vector search with keyword.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a dense_vector field', 'Run a hybrid query']::text[], array['Learn: Vector + Keyword (kNN) (45 min)', 'Code: apply vector + keyword (knn) in practice (45 min)', 'Notes + GitHub commit for Day 252 (30 min)']::text[], '', array['How does ES do vector search?', 'Why combine vector and keyword?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 253, 'Elasticsearch Performance', '2h', 'Optimize indexing and search.', '{}'::text[], '{}'::text[], '{}'::text[], array['Tune shard count', 'Optimize a slow query']::text[], array['Learn: Elasticsearch Performance (45 min)', 'Code: apply elasticsearch performance in practice (45 min)', 'Notes + GitHub commit for Day 253 (30 min)']::text[], '', array['How many shards should you use?', 'What slows down search?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 254, 'Kibana Basics', '2h', 'Explore and visualize data in Kibana.', '{}'::text[], '{}'::text[], '{}'::text[], array['Explore data in Discover', 'Build a visualization']::text[], array['Learn: Kibana Basics (45 min)', 'Code: apply kibana basics in practice (45 min)', 'Notes + GitHub commit for Day 254 (30 min)']::text[], '', array['What is Kibana for?', 'How do you inspect a query?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 255, 'Building a Search API', '2h', 'Expose search behind FastAPI.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a search endpoint', 'Return highlighted snippets']::text[], array['Learn: Building a Search API (45 min)', 'Code: apply building a search api in practice (45 min)', 'Notes + GitHub commit for Day 255 (30 min)']::text[], '', array['How do you build a search API?', 'What is highlighting?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 256, 'Graph Databases Intro', '2h', 'Understand when graphs beat tables.', '{}'::text[], '{}'::text[], '{}'::text[], array['List graph use cases', 'Compare to relational joins']::text[], array['Learn: Graph Databases Intro (45 min)', 'Code: apply graph databases intro in practice (45 min)', 'Notes + GitHub commit for Day 256 (30 min)']::text[], '', array['When is a graph DB better?', 'Graph vs relational for relationships?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 257, 'Neo4j Setup', '2h', 'Run Neo4j and use the browser.', '{}'::text[], '{}'::text[], '{}'::text[], array['Start Neo4j', 'Run a query in the browser']::text[], array['Learn: Neo4j Setup (45 min)', 'Code: apply neo4j setup in practice (45 min)', 'Notes + GitHub commit for Day 257 (30 min)']::text[], '', array['What is a property graph?', 'What is Neo4j Browser?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 258, 'Nodes, Relationships, Properties', '4h', 'Model the graph data model.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create nodes and relationships', 'Add properties']::text[], array['Learn: Nodes, Relationships, Properties (45 min)', 'Code: apply nodes, relationships, properties in practice (45 min)', 'Notes + GitHub commit for Day 258 (30 min)']::text[], '', array['What is a relationship type?', 'Where do properties live?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 259, 'Cypher Query Language', '4h', 'Query graphs with Cypher.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write MATCH/CREATE queries', 'Filter with WHERE']::text[], array['Learn: Cypher Query Language (45 min)', 'Code: apply cypher query language in practice (45 min)', 'Notes + GitHub commit for Day 259 (30 min)']::text[], '', array['What does MATCH do?', 'How do you create a relationship?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 260, 'Modeling Graphs', '2h', 'Design an effective graph model.', '{}'::text[], '{}'::text[], '{}'::text[], array['Model a domain as a graph', 'Choose relationship directions']::text[], array['Learn: Modeling Graphs (45 min)', 'Code: apply modeling graphs in practice (45 min)', 'Notes + GitHub commit for Day 260 (30 min)']::text[], '', array['How do you model a graph?', 'When use a relationship vs property?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 261, 'Graph Traversals & Paths', '2h', 'Find paths and traverse relationships.', '{}'::text[], '{}'::text[], '{}'::text[], array['Find shortest paths', 'Traverse variable-length paths']::text[], array['Learn: Graph Traversals & Paths (45 min)', 'Code: apply graph traversals & paths in practice (45 min)', 'Notes + GitHub commit for Day 261 (30 min)']::text[], '', array['What is a variable-length path?', 'How do you find shortest paths?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 262, 'Recommendations with Graphs', '2h', 'Build recommendations via traversal.', '{}'::text[], '{}'::text[], '{}'::text[], array['Recommend by shared connections', 'Rank recommendations']::text[], array['Learn: Recommendations with Graphs (45 min)', 'Code: apply recommendations with graphs in practice (45 min)', 'Notes + GitHub commit for Day 262 (30 min)']::text[], '', array['How do graphs power recommendations?', 'What is collaborative filtering (graph view)?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 263, 'Knowledge Graphs', '2h', 'Represent knowledge as a graph.', '{}'::text[], '{}'::text[], '{}'::text[], array['Model entities and relations', 'Query connected facts']::text[], array['Learn: Knowledge Graphs (45 min)', 'Code: apply knowledge graphs in practice (45 min)', 'Notes + GitHub commit for Day 263 (30 min)']::text[], '', array['What is a knowledge graph?', 'How do you extract entities?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 264, 'GraphRAG Concepts', '2h', 'Combine graphs with retrieval for LLMs.', '{}'::text[], '{}'::text[], '{}'::text[], array['Sketch a GraphRAG flow', 'Retrieve subgraphs for context']::text[], array['Learn: GraphRAG Concepts (45 min)', 'Code: apply graphrag concepts in practice (45 min)', 'Notes + GitHub commit for Day 264 (30 min)']::text[], '', array['What is GraphRAG?', 'Why add a graph to RAG?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 265, 'Neo4j + LLM Integration', '4h', 'Let an LLM query the graph.', '{}'::text[], '{}'::text[], '{}'::text[], array['Generate Cypher from a question', 'Ground answers in the graph']::text[], array['Learn: Neo4j + LLM Integration (45 min)', 'Code: apply neo4j + llm integration in practice (45 min)', 'Notes + GitHub commit for Day 265 (30 min)']::text[], '', array['How do you translate NL to Cypher?', 'How do you keep generated Cypher safe?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 266, 'Combining Search + Graph', '4h', 'Blend Elasticsearch and Neo4j results.', '{}'::text[], '{}'::text[], '{}'::text[], array['Search then expand via graph', 'Merge and rank results']::text[], array['Learn: Combining Search + Graph (45 min)', 'Code: apply combining search + graph in practice (45 min)', 'Notes + GitHub commit for Day 266 (30 min)']::text[], '', array['When combine search and graph?', 'How do you merge result sets?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 267, 'Indexing Strategy', '2h', 'Plan indexing across both stores.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design an indexing pipeline', 'Keep stores in sync']::text[], array['Learn: Indexing Strategy (45 min)', 'Code: apply indexing strategy in practice (45 min)', 'Notes + GitHub commit for Day 267 (30 min)']::text[], '', array['How do you keep two stores in sync?', 'What owns the source of truth?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 268, 'Search Relevance Tuning', '2h', 'Improve end-to-end relevance.', '{}'::text[], '{}'::text[], '{}'::text[], array['Tune boosts and reranking', 'Evaluate with judgments']::text[], array['Learn: Search Relevance Tuning (45 min)', 'Code: apply search relevance tuning in practice (45 min)', 'Notes + GitHub commit for Day 268 (30 min)']::text[], '', array['How do you measure relevance?', 'What is a relevance judgment?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 269, 'Search Observability', '2h', 'Monitor search quality and latency.', '{}'::text[], '{}'::text[], '{}'::text[], array['Log slow queries', 'Track zero-result rate']::text[], array['Learn: Search Observability (45 min)', 'Code: apply search observability in practice (45 min)', 'Notes + GitHub commit for Day 269 (30 min)']::text[], '', array['What do you monitor in search?', 'Why track zero-result queries?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 9), 270, 'Project: AI Search Engine', '2h', 'Ship search + graph + AI answers behind an API.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize hybrid search + graph', 'Add an AI answer layer']::text[], array['Learn: Project: AI Search Engine (45 min)', 'Code: apply project: ai search engine in practice (45 min)', 'Notes + GitHub commit for Day 270 (30 min)']::text[], '', array['Walk through a search query.', 'How do search, graph, and LLM combine?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 10: AWS + GCP + Azure
insert into public.months (month_number, title, goal, project, status)
values (10, 'AWS + GCP + Azure', 'Deploy and operate applications across the major cloud providers.', '{"name":"Cloud-Deployed AI Service","prd":"Deploy the AI service to a cloud provider with IaC, managed data stores, CI/CD, and monitoring.","architecture":"Containerized app on managed compute (ECS/Cloud Run/App Service) + managed Postgres + object storage.","techStack":["AWS","GCP","Azure","Terraform","CI/CD"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 271, 'Cloud Fundamentals', '2h', 'Understand cloud service models and regions.', '{}'::text[], '{}'::text[], '{}'::text[], array['Map IaaS/PaaS/SaaS examples', 'Explain regions and AZs']::text[], array['Learn: Cloud Fundamentals (45 min)', 'Code: apply cloud fundamentals in practice (45 min)', 'Notes + GitHub commit for Day 271 (30 min)']::text[], '', array['IaaS vs PaaS vs SaaS?', 'What is an availability zone?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 272, 'IAM & Security Basics', '4h', 'Manage identity and least-privilege access.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a scoped IAM role', 'Apply least privilege']::text[], array['Learn: IAM & Security Basics (45 min)', 'Code: apply iam & security basics in practice (45 min)', 'Notes + GitHub commit for Day 272 (30 min)']::text[], '', array['What is least privilege?', 'Role vs user vs policy?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 273, 'AWS EC2', '4h', 'Provision and access virtual machines.', '{}'::text[], '{}'::text[], '{}'::text[], array['Launch an EC2 instance', 'SSH and run the app']::text[], array['Learn: AWS EC2 (45 min)', 'Code: apply aws ec2 in practice (45 min)', 'Notes + GitHub commit for Day 273 (30 min)']::text[], '', array['What is an AMI?', 'What is a security group?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 274, 'AWS S3', '2h', 'Store objects and serve files.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a bucket', 'Upload and fetch objects']::text[], array['Learn: AWS S3 (45 min)', 'Code: apply aws s3 in practice (45 min)', 'Notes + GitHub commit for Day 274 (30 min)']::text[], '', array['What is object storage?', 'How do you make objects private?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 275, 'AWS RDS', '2h', 'Run managed PostgreSQL.', '{}'::text[], '{}'::text[], '{}'::text[], array['Provision an RDS instance', 'Connect the app']::text[], array['Learn: AWS RDS (45 min)', 'Code: apply aws rds in practice (45 min)', 'Notes + GitHub commit for Day 275 (30 min)']::text[], '', array['Why use managed databases?', 'What does RDS handle for you?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 276, 'AWS Networking (VPC)', '2h', 'Understand VPCs, subnets, and routing.', '{}'::text[], '{}'::text[], '{}'::text[], array['Diagram a VPC', 'Place resources in subnets']::text[], array['Learn: AWS Networking (VPC) (45 min)', 'Code: apply aws networking (vpc) in practice (45 min)', 'Notes + GitHub commit for Day 276 (30 min)']::text[], '', array['Public vs private subnet?', 'What is a NAT gateway?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 277, 'AWS Lambda & Serverless', '2h', 'Run code without managing servers.', '{}'::text[], '{}'::text[], '{}'::text[], array['Deploy a Lambda', 'Trigger it from an event']::text[], array['Learn: AWS Lambda & Serverless (45 min)', 'Code: apply aws lambda & serverless in practice (45 min)', 'Notes + GitHub commit for Day 277 (30 min)']::text[], '', array['What is serverless?', 'What is a cold start?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 278, 'AWS ECS / EKS', '2h', 'Run containers on AWS.', '{}'::text[], '{}'::text[], '{}'::text[], array['Deploy a container to ECS', 'Compare ECS and EKS']::text[], array['Learn: AWS ECS / EKS (45 min)', 'Code: apply aws ecs / eks in practice (45 min)', 'Notes + GitHub commit for Day 278 (30 min)']::text[], '', array['ECS vs EKS?', 'What is Fargate?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 279, 'CloudWatch & Logging', '4h', 'Observe apps with logs and metrics.', '{}'::text[], '{}'::text[], '{}'::text[], array['Ship logs to CloudWatch', 'Create an alarm']::text[], array['Learn: CloudWatch & Logging (45 min)', 'Code: apply cloudwatch & logging in practice (45 min)', 'Notes + GitHub commit for Day 279 (30 min)']::text[], '', array['What is a metric alarm?', 'How do you centralize logs?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 280, 'Secrets Manager', '4h', 'Store and rotate secrets.', '{}'::text[], '{}'::text[], '{}'::text[], array['Store a secret', 'Read it from the app']::text[], array['Learn: Secrets Manager (45 min)', 'Code: apply secrets manager in practice (45 min)', 'Notes + GitHub commit for Day 280 (30 min)']::text[], '', array['Why use a secrets manager?', 'How do you rotate secrets?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 281, 'Deploying FastAPI on AWS', '2h', 'Deploy the API to AWS.', '{}'::text[], '{}'::text[], '{}'::text[], array['Containerize and deploy', 'Wire up RDS and secrets']::text[], array['Learn: Deploying FastAPI on AWS (45 min)', 'Code: apply deploying fastapi on aws in practice (45 min)', 'Notes + GitHub commit for Day 281 (30 min)']::text[], '', array['How do you deploy a container to AWS?', 'Where do env vars come from?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 282, 'Infrastructure as Code', '2h', 'Provision infra with Terraform.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write Terraform for a bucket + DB', 'Plan and apply']::text[], array['Learn: Infrastructure as Code (45 min)', 'Code: apply infrastructure as code in practice (45 min)', 'Notes + GitHub commit for Day 282 (30 min)']::text[], '', array['Why use IaC?', 'What is Terraform state?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 283, 'GCP Compute & Cloud Run', '2h', 'Deploy containers on Cloud Run.', '{}'::text[], '{}'::text[], '{}'::text[], array['Deploy to Cloud Run', 'Set concurrency']::text[], array['Learn: GCP Compute & Cloud Run (45 min)', 'Code: apply gcp compute & cloud run in practice (45 min)', 'Notes + GitHub commit for Day 283 (30 min)']::text[], '', array['What is Cloud Run?', 'How does it scale to zero?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 284, 'GCP Storage & BigQuery', '2h', 'Use GCS and query with BigQuery.', '{}'::text[], '{}'::text[], '{}'::text[], array['Store objects in GCS', 'Run a BigQuery query']::text[], array['Learn: GCP Storage & BigQuery (45 min)', 'Code: apply gcp storage & bigquery in practice (45 min)', 'Notes + GitHub commit for Day 284 (30 min)']::text[], '', array['What is BigQuery?', 'GCS vs S3?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 285, 'GCP GKE', '2h', 'Run Kubernetes on GCP.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a GKE cluster', 'Deploy the app']::text[], array['Learn: GCP GKE (45 min)', 'Code: apply gcp gke in practice (45 min)', 'Notes + GitHub commit for Day 285 (30 min)']::text[], '', array['What does GKE manage?', 'Autopilot vs standard?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 286, 'GCP IAM & Networking', '4h', 'Configure GCP identity and networks.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a service account', 'Set up a VPC']::text[], array['Learn: GCP IAM & Networking (45 min)', 'Code: apply gcp iam & networking in practice (45 min)', 'Notes + GitHub commit for Day 286 (30 min)']::text[], '', array['What is a service account?', 'How does GCP IAM differ from AWS?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 287, 'Deploying to Cloud Run', '4h', 'Ship the AI service on Cloud Run.', '{}'::text[], '{}'::text[], '{}'::text[], array['Deploy with env + secrets', 'Connect Cloud SQL']::text[], array['Learn: Deploying to Cloud Run (45 min)', 'Code: apply deploying to cloud run in practice (45 min)', 'Notes + GitHub commit for Day 287 (30 min)']::text[], '', array['How do you connect Cloud SQL?', 'How do you manage secrets on GCP?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 288, 'Azure App Service & VMs', '2h', 'Deploy apps on Azure.', '{}'::text[], '{}'::text[], '{}'::text[], array['Deploy to App Service', 'Compare with VMs']::text[], array['Learn: Azure App Service & VMs (45 min)', 'Code: apply azure app service & vms in practice (45 min)', 'Notes + GitHub commit for Day 288 (30 min)']::text[], '', array['What is App Service?', 'When use a VM instead?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 289, 'Azure Storage & Postgres', '2h', 'Use Azure storage and managed Postgres.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create a storage account', 'Provision Azure Database for PostgreSQL']::text[], array['Learn: Azure Storage & Postgres (45 min)', 'Code: apply azure storage & postgres in practice (45 min)', 'Notes + GitHub commit for Day 289 (30 min)']::text[], '', array['What is a storage account?', 'How does Azure manage Postgres?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 290, 'Azure AKS', '2h', 'Run Kubernetes on Azure.', '{}'::text[], '{}'::text[], '{}'::text[], array['Create an AKS cluster', 'Deploy the app']::text[], array['Learn: Azure AKS (45 min)', 'Code: apply azure aks in practice (45 min)', 'Notes + GitHub commit for Day 290 (30 min)']::text[], '', array['What does AKS manage?', 'How does AKS integrate with Azure AD?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 291, 'Azure AI Services', '2h', 'Use Azure OpenAI / AI services.', '{}'::text[], '{}'::text[], '{}'::text[], array['Call an Azure AI endpoint', 'Compare with direct API']::text[], array['Learn: Azure AI Services (45 min)', 'Code: apply azure ai services in practice (45 min)', 'Notes + GitHub commit for Day 291 (30 min)']::text[], '', array['What does Azure OpenAI provide?', 'Why use a cloud AI service?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 292, 'Multi-cloud Considerations', '2h', 'Weigh portability vs lock-in.', '{}'::text[], '{}'::text[], '{}'::text[], array['List lock-in risks', 'Design for portability']::text[], array['Learn: Multi-cloud Considerations (45 min)', 'Code: apply multi-cloud considerations in practice (45 min)', 'Notes + GitHub commit for Day 292 (30 min)']::text[], '', array['What is vendor lock-in?', 'How do you stay portable?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 293, 'Cost Management', '4h', 'Monitor and control cloud spend.', '{}'::text[], '{}'::text[], '{}'::text[], array['Set a budget alert', 'Estimate monthly cost']::text[], array['Learn: Cost Management (45 min)', 'Code: apply cost management in practice (45 min)', 'Notes + GitHub commit for Day 293 (30 min)']::text[], '', array['How do you control cloud cost?', 'What is a common cost surprise?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 294, 'CDN & Caching', '4h', 'Serve content fast with a CDN.', '{}'::text[], '{}'::text[], '{}'::text[], array['Put a CDN in front of assets', 'Set cache headers']::text[], array['Learn: CDN & Caching (45 min)', 'Code: apply cdn & caching in practice (45 min)', 'Notes + GitHub commit for Day 294 (30 min)']::text[], '', array['What does a CDN do?', 'What is cache TTL at the edge?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 295, 'Load Balancers & Auto Scaling', '2h', 'Scale compute behind a load balancer.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a load balancer', 'Configure autoscaling']::text[], array['Learn: Load Balancers & Auto Scaling (45 min)', 'Code: apply load balancers & auto scaling in practice (45 min)', 'Notes + GitHub commit for Day 295 (30 min)']::text[], '', array['How does a load balancer distribute traffic?', 'What triggers autoscaling?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 296, 'Managed Vector/Search Services', '2h', 'Use managed vector and search offerings.', '{}'::text[], '{}'::text[], '{}'::text[], array['Try a managed vector service', 'Compare with self-hosted']::text[], array['Learn: Managed Vector/Search Services (45 min)', 'Code: apply managed vector/search services in practice (45 min)', 'Notes + GitHub commit for Day 296 (30 min)']::text[], '', array['Managed vs self-hosted tradeoffs?', 'When use a managed vector DB?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 297, 'Secrets & Config Management', '2h', 'Manage config across environments.', '{}'::text[], '{}'::text[], '{}'::text[], array['Separate config per environment', 'Inject secrets at deploy']::text[], array['Learn: Secrets & Config Management (45 min)', 'Code: apply secrets & config management in practice (45 min)', 'Notes + GitHub commit for Day 297 (30 min)']::text[], '', array['How do you manage multi-env config?', 'Where should secrets live?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 298, 'CI/CD to Cloud', '2h', 'Automate deploys with a pipeline.', '{}'::text[], '{}'::text[], '{}'::text[], array['Build a deploy pipeline', 'Deploy on merge']::text[], array['Learn: CI/CD to Cloud (45 min)', 'Code: apply ci/cd to cloud in practice (45 min)', 'Notes + GitHub commit for Day 298 (30 min)']::text[], '', array['What are CI/CD stages?', 'How do you gate a deploy?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 299, 'Cloud Security Best Practices', '2h', 'Harden a cloud deployment.', '{}'::text[], '{}'::text[], '{}'::text[], array['Audit IAM and network rules', 'Enable encryption at rest']::text[], array['Learn: Cloud Security Best Practices (45 min)', 'Code: apply cloud security best practices in practice (45 min)', 'Notes + GitHub commit for Day 299 (30 min)']::text[], '', array['What are cloud security basics?', 'What is encryption at rest?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 10), 300, 'Project: Cloud-Deployed AI Service', '4h', 'Ship the AI service to the cloud with IaC and CI/CD.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize IaC and pipeline', 'Add monitoring and alerts']::text[], array['Learn: Project: Cloud-Deployed AI Service (45 min)', 'Code: apply project: cloud-deployed ai service in practice (45 min)', 'Notes + GitHub commit for Day 300 (30 min)']::text[], '', array['Walk through your cloud architecture.', 'How is it deployed and monitored?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 11: System Design + AI Evaluation
insert into public.months (month_number, title, goal, project, status)
values (11, 'System Design + AI Evaluation', 'Design scalable systems and rigorously evaluate AI features for production.', '{"name":"AI Evaluation Harness","prd":"A harness that runs eval datasets, LLM-as-judge scoring, and regression tracking for AI features.","architecture":"Eval dataset store + runner + LLM judge + metrics dashboard, integrated with CI.","techStack":["System Design","LLM Eval","Python","FastAPI","Claude API"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 301, 'System Design Fundamentals', '4h', 'Learn a framework for design problems.', '{}'::text[], '{}'::text[], '{}'::text[], array['Practice the design framework', 'Estimate scale for a system']::text[], array['Learn: System Design Fundamentals (45 min)', 'Code: apply system design fundamentals in practice (45 min)', 'Notes + GitHub commit for Day 301 (30 min)']::text[], '', array['How do you approach a design question?', 'How do you estimate QPS?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 302, 'Scalability Concepts', '2h', 'Understand vertical vs horizontal scaling.', '{}'::text[], '{}'::text[], '{}'::text[], array['Identify bottlenecks', 'Plan horizontal scaling']::text[], array['Learn: Scalability Concepts (45 min)', 'Code: apply scalability concepts in practice (45 min)', 'Notes + GitHub commit for Day 302 (30 min)']::text[], '', array['Vertical vs horizontal scaling?', 'What is a bottleneck?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 303, 'Load Balancing', '2h', 'Distribute traffic across servers.', '{}'::text[], '{}'::text[], '{}'::text[], array['Compare LB algorithms', 'Handle sticky sessions']::text[], array['Learn: Load Balancing (45 min)', 'Code: apply load balancing in practice (45 min)', 'Notes + GitHub commit for Day 303 (30 min)']::text[], '', array['Load balancing algorithms?', 'What is a sticky session?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 304, 'Caching Strategies', '2h', 'Apply caching at multiple layers.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design a cache layer', 'Choose an eviction policy']::text[], array['Learn: Caching Strategies (45 min)', 'Code: apply caching strategies in practice (45 min)', 'Notes + GitHub commit for Day 304 (30 min)']::text[], '', array['Cache-aside vs write-through?', 'What is cache stampede?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 305, 'Database Scaling', '2h', 'Scale databases with replication/sharding.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design read replicas', 'Plan a sharding key']::text[], array['Learn: Database Scaling (45 min)', 'Code: apply database scaling in practice (45 min)', 'Notes + GitHub commit for Day 305 (30 min)']::text[], '', array['Replication vs sharding?', 'How do you pick a shard key?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 306, 'CAP Theorem & Consistency', '2h', 'Reason about consistency tradeoffs.', '{}'::text[], '{}'::text[], '{}'::text[], array['Place systems on CAP', 'Explain eventual consistency']::text[], array['Learn: CAP Theorem & Consistency (45 min)', 'Code: apply cap theorem & consistency in practice (45 min)', 'Notes + GitHub commit for Day 306 (30 min)']::text[], '', array['What is the CAP theorem?', 'Strong vs eventual consistency?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 307, 'Message Queues & Async', '4h', 'Decouple systems with queues.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design an async workflow', 'Handle retries and DLQs']::text[], array['Learn: Message Queues & Async (45 min)', 'Code: apply message queues & async in practice (45 min)', 'Notes + GitHub commit for Day 307 (30 min)']::text[], '', array['Why use a message queue?', 'How do you ensure idempotency?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 308, 'API Gateway & Rate Limiting', '4h', 'Front services with a gateway.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design gateway responsibilities', 'Add rate limiting']::text[], array['Learn: API Gateway & Rate Limiting (45 min)', 'Code: apply api gateway & rate limiting in practice (45 min)', 'Notes + GitHub commit for Day 308 (30 min)']::text[], '', array['What does an API gateway do?', 'How do you rate limit fairly?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 309, 'Microservices vs Monolith', '2h', 'Choose an architecture style.', '{}'::text[], '{}'::text[], '{}'::text[], array['List tradeoffs', 'Decide for a scenario']::text[], array['Learn: Microservices vs Monolith (45 min)', 'Code: apply microservices vs monolith in practice (45 min)', 'Notes + GitHub commit for Day 309 (30 min)']::text[], '', array['When choose microservices?', 'What are their costs?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 310, 'Event-driven Architecture', '2h', 'Design around events.', '{}'::text[], '{}'::text[], '{}'::text[], array['Model an event flow', 'Handle ordering']::text[], array['Learn: Event-driven Architecture (45 min)', 'Code: apply event-driven architecture in practice (45 min)', 'Notes + GitHub commit for Day 310 (30 min)']::text[], '', array['What is event-driven architecture?', 'How do you handle event ordering?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 311, 'Designing for Reliability', '2h', 'Add redundancy and graceful degradation.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design for failure', 'Add a fallback path']::text[], array['Learn: Designing for Reliability (45 min)', 'Code: apply designing for reliability in practice (45 min)', 'Notes + GitHub commit for Day 311 (30 min)']::text[], '', array['What is graceful degradation?', 'How do you avoid single points of failure?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 312, 'Observability', '2h', 'Design metrics, logs, and traces.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define key metrics/SLIs', 'Add tracing to a flow']::text[], array['Learn: Observability (45 min)', 'Code: apply observability in practice (45 min)', 'Notes + GitHub commit for Day 312 (30 min)']::text[], '', array['Metrics vs logs vs traces?', 'What is an SLI/SLO?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 313, 'Design: URL Shortener', '2h', 'Design a URL shortener at scale.', '{}'::text[], '{}'::text[], '{}'::text[], array['Estimate scale and storage', 'Design the key generation']::text[], array['Learn: Design: URL Shortener (45 min)', 'Code: apply design: url shortener in practice (45 min)', 'Notes + GitHub commit for Day 313 (30 min)']::text[], '', array['How do you generate short keys?', 'How do you scale reads?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 314, 'Design: Chat System', '4h', 'Design a real-time chat system.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design message delivery', 'Handle presence and history']::text[], array['Learn: Design: Chat System (45 min)', 'Code: apply design: chat system in practice (45 min)', 'Notes + GitHub commit for Day 314 (30 min)']::text[], '', array['How do you deliver messages in real time?', 'How do you store chat history?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 315, 'Design: RAG System', '4h', 'Design a production RAG system.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design ingestion and retrieval at scale', 'Plan freshness and caching']::text[], array['Learn: Design: RAG System (45 min)', 'Code: apply design: rag system in practice (45 min)', 'Notes + GitHub commit for Day 315 (30 min)']::text[], '', array['How do you scale ingestion?', 'How do you keep the index fresh?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 316, 'Design: Agent Platform', '2h', 'Design a scalable agent platform.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design run isolation and limits', 'Plan observability']::text[], array['Learn: Design: Agent Platform (45 min)', 'Code: apply design: agent platform in practice (45 min)', 'Notes + GitHub commit for Day 316 (30 min)']::text[], '', array['How do you isolate agent runs?', 'How do you bound cost?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 317, 'LLM Evaluation Fundamentals', '2h', 'Understand why and how to evaluate LLMs.', '{}'::text[], '{}'::text[], '{}'::text[], array['List failure modes to catch', 'Define quality dimensions']::text[], array['Learn: LLM Evaluation Fundamentals (45 min)', 'Code: apply llm evaluation fundamentals in practice (45 min)', 'Notes + GitHub commit for Day 317 (30 min)']::text[], '', array['Why is LLM eval hard?', 'What dimensions do you evaluate?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 318, 'Building Eval Datasets', '2h', 'Curate representative eval sets.', '{}'::text[], '{}'::text[], '{}'::text[], array['Build a labeled eval set', 'Cover edge cases']::text[], array['Learn: Building Eval Datasets (45 min)', 'Code: apply building eval datasets in practice (45 min)', 'Notes + GitHub commit for Day 318 (30 min)']::text[], '', array['What makes a good eval set?', 'How many cases do you need?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 319, 'LLM-as-Judge', '2h', 'Score outputs with a judge model.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write a judge prompt', 'Validate judge reliability']::text[], array['Learn: LLM-as-Judge (45 min)', 'Code: apply llm-as-judge in practice (45 min)', 'Notes + GitHub commit for Day 319 (30 min)']::text[], '', array['What is LLM-as-judge?', 'How do you trust the judge?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 320, 'Offline vs Online Eval', '2h', 'Compare pre-ship and in-production eval.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design an offline suite', 'Design online metrics']::text[], array['Learn: Offline vs Online Eval (45 min)', 'Code: apply offline vs online eval in practice (45 min)', 'Notes + GitHub commit for Day 320 (30 min)']::text[], '', array['Offline vs online eval?', 'What do you measure in production?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 321, 'RAG Evaluation Metrics', '4h', 'Measure retrieval and answer quality.', '{}'::text[], '{}'::text[], '{}'::text[], array['Compute faithfulness/relevance', 'Track recall@k']::text[], array['Learn: RAG Evaluation Metrics (45 min)', 'Code: apply rag evaluation metrics in practice (45 min)', 'Notes + GitHub commit for Day 321 (30 min)']::text[], '', array['What is faithfulness?', 'How do you measure groundedness?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 322, 'Agent Evaluation', '4h', 'Measure agent task success and cost.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define task success', 'Track steps and cost']::text[], array['Learn: Agent Evaluation (45 min)', 'Code: apply agent evaluation in practice (45 min)', 'Notes + GitHub commit for Day 322 (30 min)']::text[], '', array['How do you evaluate an agent?', 'What is trajectory evaluation?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 323, 'Regression Testing for Prompts', '2h', 'Catch regressions when prompts change.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add prompt regression tests', 'Run them in CI']::text[], array['Learn: Regression Testing for Prompts (45 min)', 'Code: apply regression testing for prompts in practice (45 min)', 'Notes + GitHub commit for Day 323 (30 min)']::text[], '', array['How do you regression-test prompts?', 'Why version prompts?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 324, 'A/B Testing LLM Features', '2h', 'Compare variants with experiments.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design an A/B test', 'Pick success metrics']::text[], array['Learn: A/B Testing LLM Features (45 min)', 'Code: apply a/b testing llm features in practice (45 min)', 'Notes + GitHub commit for Day 324 (30 min)']::text[], '', array['How do you A/B test an LLM feature?', 'What is statistical significance?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 325, 'Monitoring LLMs in Production', '2h', 'Track quality, cost, and drift live.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add production LLM metrics', 'Detect drift']::text[], array['Learn: Monitoring LLMs in Production (45 min)', 'Code: apply monitoring llms in production in practice (45 min)', 'Notes + GitHub commit for Day 325 (30 min)']::text[], '', array['What do you monitor for LLMs?', 'What is drift?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 326, 'Guardrails & Safety Evaluation', '2h', 'Evaluate safety and guardrails.', '{}'::text[], '{}'::text[], '{}'::text[], array['Test jailbreak resistance', 'Measure refusal accuracy']::text[], array['Learn: Guardrails & Safety Evaluation (45 min)', 'Code: apply guardrails & safety evaluation in practice (45 min)', 'Notes + GitHub commit for Day 326 (30 min)']::text[], '', array['How do you evaluate safety?', 'What is a jailbreak?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 327, 'Cost & Latency SLOs', '2h', 'Set and enforce SLOs for AI features.', '{}'::text[], '{}'::text[], '{}'::text[], array['Define latency/cost SLOs', 'Alert on breaches']::text[], array['Learn: Cost & Latency SLOs (45 min)', 'Code: apply cost & latency slos in practice (45 min)', 'Notes + GitHub commit for Day 327 (30 min)']::text[], '', array['How do you set an SLO?', 'How do you balance cost vs quality?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 328, 'Building an Eval Harness', '4h', 'Assemble a reusable eval harness.', '{}'::text[], '{}'::text[], '{}'::text[], array['Wire dataset → runner → judge', 'Report metrics']::text[], array['Learn: Building an Eval Harness (45 min)', 'Code: apply building an eval harness in practice (45 min)', 'Notes + GitHub commit for Day 328 (30 min)']::text[], '', array['What are the parts of an eval harness?', 'How do you integrate it with CI?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 329, 'Mock System Design Interview', '4h', 'Practice a full design interview.', '{}'::text[], '{}'::text[], '{}'::text[], array['Do a timed mock design', 'Get and apply feedback']::text[], array['Learn: Mock System Design Interview (45 min)', 'Code: apply mock system design interview in practice (45 min)', 'Notes + GitHub commit for Day 329 (30 min)']::text[], '', array['Walk through a system design end to end.', 'How do you handle scale follow-ups?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 11), 330, 'Project: AI Evaluation Harness', '2h', 'Ship an eval harness with judge scoring and CI integration.', '{}'::text[], '{}'::text[], '{}'::text[], array['Finalize runner and judge', 'Add a metrics dashboard']::text[], array['Learn: Project: AI Evaluation Harness (45 min)', 'Code: apply project: ai evaluation harness in practice (45 min)', 'Notes + GitHub commit for Day 330 (30 min)']::text[], '', array['Walk through your eval pipeline.', 'How does it catch regressions?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

-- Month 12: Build Production AI SaaS
insert into public.months (month_number, title, goal, project, status)
values (12, 'Build Production AI SaaS', 'Combine everything into a production-grade, multi-tenant AI SaaS capstone.', '{"name":"Enterprise AI SaaS (Capstone)","prd":"A multi-tenant AI SaaS with auth, billing, RAG/agents, observability, and a full production deployment.","architecture":"FastAPI + Postgres + pgvector + Redis + agents, containerized, on Kubernetes/cloud with CI/CD and monitoring.","techStack":["FastAPI","PostgreSQL","pgvector","Kubernetes","Claude API"],"tasks":["Define scope","Build core features","Test and document","Ship and push to GitHub"],"progress":0,"githubUrl":""}'::jsonb, 'published')
on conflict (month_number) do update set
  title = excluded.title, goal = excluded.goal, project = excluded.project, status = excluded.status;

insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 331, 'Capstone Scope & PRD', '2h', 'Define the product, users, and scope.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write the capstone PRD', 'List MVP features']::text[], array['Learn: Capstone Scope & PRD (45 min)', 'Code: apply capstone scope & prd in practice (45 min)', 'Notes + GitHub commit for Day 331 (30 min)']::text[], '', array['How do you scope an MVP?', 'What belongs in a PRD?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 332, 'Architecture Design', '2h', 'Design the end-to-end architecture.', '{}'::text[], '{}'::text[], '{}'::text[], array['Draw the architecture diagram', 'Choose components']::text[], array['Learn: Architecture Design (45 min)', 'Code: apply architecture design in practice (45 min)', 'Notes + GitHub commit for Day 332 (30 min)']::text[], '', array['Walk through your architecture.', 'What are the main tradeoffs?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 333, 'Tech Stack & Repo Setup', '2h', 'Set up the monorepo and tooling.', '{}'::text[], '{}'::text[], '{}'::text[], array['Scaffold the repo', 'Configure linting/CI']::text[], array['Learn: Tech Stack & Repo Setup (45 min)', 'Code: apply tech stack & repo setup in practice (45 min)', 'Notes + GitHub commit for Day 333 (30 min)']::text[], '', array['How do you structure a SaaS repo?', 'What tooling do you standardize?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 334, 'Auth & Multi-tenancy', '2h', 'Implement tenant isolation and auth.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add tenant-scoped auth', 'Isolate tenant data']::text[], array['Learn: Auth & Multi-tenancy (45 min)', 'Code: apply auth & multi-tenancy in practice (45 min)', 'Notes + GitHub commit for Day 334 (30 min)']::text[], '', array['How do you isolate tenants?', 'Row-level vs schema-per-tenant?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 335, 'Database Schema Design', '4h', 'Design the multi-tenant schema.', '{}'::text[], '{}'::text[], '{}'::text[], array['Design core tables', 'Add tenant keys and indexes']::text[], array['Learn: Database Schema Design (45 min)', 'Code: apply database schema design in practice (45 min)', 'Notes + GitHub commit for Day 335 (30 min)']::text[], '', array['How do you index multi-tenant tables?', 'How do you prevent cross-tenant leaks?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 336, 'Core API Development', '4h', 'Build the core CRUD and domain APIs.', '{}'::text[], '{}'::text[], '{}'::text[], array['Implement core endpoints', 'Add validation and errors']::text[], array['Learn: Core API Development (45 min)', 'Code: apply core api development in practice (45 min)', 'Notes + GitHub commit for Day 336 (30 min)']::text[], '', array['How do you structure a large API?', 'Where does business logic live?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 337, 'RAG / Agent Integration', '2h', 'Add the core AI feature.', '{}'::text[], '{}'::text[], '{}'::text[], array['Integrate RAG or an agent', 'Ground responses']::text[], array['Learn: RAG / Agent Integration (45 min)', 'Code: apply rag / agent integration in practice (45 min)', 'Notes + GitHub commit for Day 337 (30 min)']::text[], '', array['How do you productionize RAG/agents?', 'How do you keep responses grounded?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 338, 'Vector Store Integration', '2h', 'Wire pgvector for per-tenant retrieval.', '{}'::text[], '{}'::text[], '{}'::text[], array['Store per-tenant embeddings', 'Scope retrieval by tenant']::text[], array['Learn: Vector Store Integration (45 min)', 'Code: apply vector store integration in practice (45 min)', 'Notes + GitHub commit for Day 338 (30 min)']::text[], '', array['How do you isolate vectors per tenant?', 'How do you scale the vector store?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 339, 'Async Jobs & Queues', '2h', 'Offload heavy work to workers.', '{}'::text[], '{}'::text[], '{}'::text[], array['Move ingestion to a queue', 'Report job status']::text[], array['Learn: Async Jobs & Queues (45 min)', 'Code: apply async jobs & queues in practice (45 min)', 'Notes + GitHub commit for Day 339 (30 min)']::text[], '', array['What work should be async?', 'How do you report progress?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 340, 'Caching Layer', '2h', 'Add caching for performance and cost.', '{}'::text[], '{}'::text[], '{}'::text[], array['Cache hot reads and LLM calls', 'Set invalidation rules']::text[], array['Learn: Caching Layer (45 min)', 'Code: apply caching layer in practice (45 min)', 'Notes + GitHub commit for Day 340 (30 min)']::text[], '', array['What do you cache in a SaaS?', 'How do you invalidate safely?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 341, 'Billing & Usage Metering', '2h', 'Meter usage and integrate billing.', '{}'::text[], '{}'::text[], '{}'::text[], array['Meter API/LLM usage', 'Add plan limits']::text[], array['Learn: Billing & Usage Metering (45 min)', 'Code: apply billing & usage metering in practice (45 min)', 'Notes + GitHub commit for Day 341 (30 min)']::text[], '', array['How do you meter LLM usage?', 'How do you enforce plan limits?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 342, 'Admin Dashboard', '4h', 'Build internal admin tooling.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add a tenant/usage admin view', 'Add feature flags']::text[], array['Learn: Admin Dashboard (45 min)', 'Code: apply admin dashboard in practice (45 min)', 'Notes + GitHub commit for Day 342 (30 min)']::text[], '', array['What do admins need to see?', 'Why use feature flags?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 343, 'Frontend Integration', '4h', 'Connect the React frontend.', '{}'::text[], '{}'::text[], '{}'::text[], array['Wire auth and core flows', 'Add streaming UI']::text[], array['Learn: Frontend Integration (45 min)', 'Code: apply frontend integration in practice (45 min)', 'Notes + GitHub commit for Day 343 (30 min)']::text[], '', array['How do you handle auth in the frontend?', 'How do you stream AI responses?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 344, 'Observability & Logging', '2h', 'Add metrics, logs, and traces.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add structured logging', 'Trace a request end to end']::text[], array['Learn: Observability & Logging (45 min)', 'Code: apply observability & logging in practice (45 min)', 'Notes + GitHub commit for Day 344 (30 min)']::text[], '', array['What do you instrument first?', 'How do you trace across services?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 345, 'Evaluation & Guardrails', '2h', 'Integrate the eval harness and guardrails.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run evals in CI', 'Add output guardrails']::text[], array['Learn: Evaluation & Guardrails (45 min)', 'Code: apply evaluation & guardrails in practice (45 min)', 'Notes + GitHub commit for Day 345 (30 min)']::text[], '', array['How do you gate releases on evals?', 'What guardrails are essential?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 346, 'Rate Limiting & Abuse Prevention', '2h', 'Protect the service from abuse.', '{}'::text[], '{}'::text[], '{}'::text[], array['Add per-tenant rate limits', 'Detect abusive patterns']::text[], array['Learn: Rate Limiting & Abuse Prevention (45 min)', 'Code: apply rate limiting & abuse prevention in practice (45 min)', 'Notes + GitHub commit for Day 346 (30 min)']::text[], '', array['How do you rate limit per tenant?', 'How do you prevent abuse?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 347, 'Security Hardening', '2h', 'Harden the application and infra.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run a security checklist', 'Fix top findings']::text[], array['Learn: Security Hardening (45 min)', 'Code: apply security hardening in practice (45 min)', 'Notes + GitHub commit for Day 347 (30 min)']::text[], '', array['What are the OWASP top risks?', 'How do you handle secrets?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 348, 'Containerization', '2h', 'Containerize all services.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write production Dockerfiles', 'Compose for local dev']::text[], array['Learn: Containerization (45 min)', 'Code: apply containerization in practice (45 min)', 'Notes + GitHub commit for Day 348 (30 min)']::text[], '', array['What makes a production image?', 'How do you keep images small?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 349, 'Kubernetes Deployment', '4h', 'Deploy to Kubernetes.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write manifests/Helm chart', 'Add probes and autoscaling']::text[], array['Learn: Kubernetes Deployment (45 min)', 'Code: apply kubernetes deployment in practice (45 min)', 'Notes + GitHub commit for Day 349 (30 min)']::text[], '', array['How do you deploy this to K8s?', 'How does it scale and heal?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 350, 'CI/CD Pipeline', '4h', 'Automate build, test, and deploy.', '{}'::text[], '{}'::text[], '{}'::text[], array['Build a full pipeline', 'Gate on tests and evals']::text[], array['Learn: CI/CD Pipeline (45 min)', 'Code: apply ci/cd pipeline in practice (45 min)', 'Notes + GitHub commit for Day 350 (30 min)']::text[], '', array['What stages are in your pipeline?', 'How do you do safe deploys?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 351, 'Cloud Deployment', '2h', 'Deploy to a cloud provider.', '{}'::text[], '{}'::text[], '{}'::text[], array['Provision infra with IaC', 'Deploy the stack']::text[], array['Learn: Cloud Deployment (45 min)', 'Code: apply cloud deployment in practice (45 min)', 'Notes + GitHub commit for Day 351 (30 min)']::text[], '', array['Walk through your cloud setup.', 'How do you manage environments?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 352, 'Monitoring & Alerting', '2h', 'Add dashboards and alerts.', '{}'::text[], '{}'::text[], '{}'::text[], array['Build a metrics dashboard', 'Add on-call alerts']::text[], array['Learn: Monitoring & Alerting (45 min)', 'Code: apply monitoring & alerting in practice (45 min)', 'Notes + GitHub commit for Day 352 (30 min)']::text[], '', array['What do you alert on?', 'What is an actionable alert?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 353, 'Load Testing', '2h', 'Validate performance under load.', '{}'::text[], '{}'::text[], '{}'::text[], array['Run a load test', 'Fix the top bottleneck']::text[], array['Learn: Load Testing (45 min)', 'Code: apply load testing in practice (45 min)', 'Notes + GitHub commit for Day 353 (30 min)']::text[], '', array['How do you load test?', 'What do you tune first?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 354, 'Documentation & Diagrams', '2h', 'Document the system thoroughly.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write architecture docs', 'Add API docs and diagrams']::text[], array['Learn: Documentation & Diagrams (45 min)', 'Code: apply documentation & diagrams in practice (45 min)', 'Notes + GitHub commit for Day 354 (30 min)']::text[], '', array['What docs does a SaaS need?', 'How do you keep docs current?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 355, 'Demo & Walkthrough Prep', '2h', 'Prepare a compelling demo.', '{}'::text[], '{}'::text[], '{}'::text[], array['Script a demo flow', 'Record a walkthrough']::text[], array['Learn: Demo & Walkthrough Prep (45 min)', 'Code: apply demo & walkthrough prep in practice (45 min)', 'Notes + GitHub commit for Day 355 (30 min)']::text[], '', array['How do you demo a product?', 'What story do you tell?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 356, 'Interview Prep: Backend', '4h', 'Review backend and database topics.', '{}'::text[], '{}'::text[], '{}'::text[], array['Answer 10 backend questions', 'Review your project code']::text[], array['Learn: Interview Prep: Backend (45 min)', 'Code: apply interview prep: backend in practice (45 min)', 'Notes + GitHub commit for Day 356 (30 min)']::text[], '', array['Explain your API design.', 'How do you scale the database?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 357, 'Interview Prep: AI Engineering', '4h', 'Review RAG, agents, and LLM topics.', '{}'::text[], '{}'::text[], '{}'::text[], array['Answer 10 AI questions', 'Explain your AI feature']::text[], array['Learn: Interview Prep: AI Engineering (45 min)', 'Code: apply interview prep: ai engineering in practice (45 min)', 'Notes + GitHub commit for Day 357 (30 min)']::text[], '', array['Explain your RAG/agent design.', 'How do you evaluate quality?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 358, 'Interview Prep: System Design', '2h', 'Review and practice system design.', '{}'::text[], '{}'::text[], '{}'::text[], array['Do a mock design', 'Refine your framework']::text[], array['Learn: Interview Prep: System Design (45 min)', 'Code: apply interview prep: system design in practice (45 min)', 'Notes + GitHub commit for Day 358 (30 min)']::text[], '', array['Design your capstone at scale.', 'What are the failure modes?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 359, 'Portfolio Polish & README', '2h', 'Polish the portfolio and repository.', '{}'::text[], '{}'::text[], '{}'::text[], array['Write strong READMEs', 'Curate the GitHub profile']::text[], array['Learn: Portfolio Polish & README (45 min)', 'Code: apply portfolio polish & readme in practice (45 min)', 'Notes + GitHub commit for Day 359 (30 min)']::text[], '', array['What makes a strong portfolio?', 'How do you present projects?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;
insert into public.days (month_id, day_number, title, duration, learning_objective, videos, docs, reading, practice, tasks, mini_project, interview_questions, status)
values ((select id from public.months where month_number = 12), 360, 'Capstone Launch & Retrospective', '2h', 'Launch the capstone and reflect on the year.', '{}'::text[], '{}'::text[], '{}'::text[], array['Deploy the final version', 'Write a year-in-review retrospective']::text[], array['Learn: Capstone Launch & Retrospective (45 min)', 'Code: apply capstone launch & retrospective in practice (45 min)', 'Notes + GitHub commit for Day 360 (30 min)']::text[], '', array['What did you build this year?', 'What would you do differently?']::text[], 'published')
on conflict (day_number) do update set
  month_id = excluded.month_id, title = excluded.title, duration = excluded.duration,
  learning_objective = excluded.learning_objective, videos = excluded.videos, docs = excluded.docs,
  reading = excluded.reading, practice = excluded.practice, tasks = excluded.tasks,
  mini_project = excluded.mini_project, interview_questions = excluded.interview_questions,
  status = excluded.status;

commit;

-- ---------- 3. PROMOTE ADMIN ----------
-- Sets is_admin on the profile once the account has signed up.
-- Idempotent: no-op until the row exists, safe to run before/after signup.
update public.profiles set is_admin = true where email = 'bharathravi.in@gmail.com';

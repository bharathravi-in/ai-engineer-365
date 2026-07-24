# Supabase setup — AI Engineer 365

The app connects directly to the hosted project at
`https://urmqmsruqmwpmmnusvqc.supabase.co`. Row Level Security protects the data,
so only the **anon/public** key is used in the browser.

## One-time setup

1. **Configure the client**
   - Copy `app/.env.example` → `app/.env.local`.
   - Set `VITE_SUPABASE_ANON_KEY` to your project's anon key
     (Supabase dashboard → Project Settings → API → Project API keys → `anon public`).
   - Restart `npm run dev` so Vite picks up the new env.

2. **Create the schema** — open the Supabase **SQL Editor** and run:
   - [`migrations/0001_init.sql`](./migrations/0001_init.sql) — tables, enum, triggers, and RLS policies.

3. **Seed the 12 months / 360 days** — run:
   - [`seed.sql`](./seed.sql) — inserts all plan content as **published**.
     (Regenerate any time with `node scripts/gen-seed-sql.mjs`.)

4. **Create your account** — in the app, go to **Sign in → Sign up** with your email/password.
   > If email confirmation is enabled on the project (Authentication → Providers → Email),
   > confirm via the email link before signing in. To skip that during development,
   > turn "Confirm email" off in the dashboard.

5. **Become an admin** — after signing up, run [`promote_admin.sql`](./promote_admin.sql)
   (edit the email first). Reload the app; the **Admin** nav item appears.

## What each table does

| Table | Purpose | Access |
|-------|---------|--------|
| `months` / `days` | Plan content, each with `draft`/`published` status | Public reads **published**; admins read/write all |
| `profiles` | One row per auth user, `is_admin` flag | Owner + admins |
| `progress` | Per-user day completion | Owner only |
| `notes` | Per-user Markdown notes | Owner only |

## How the app behaves

- **No anon key set** → runs offline from the bundled JSON + `localStorage` (current behaviour).
- **Anon key set, signed out** → reads published plans from Supabase; progress/notes stay local.
- **Signed in** → progress + notes sync to Supabase per user.
- **Admin** → sees drafts too and can create / edit / publish via the Admin panel.

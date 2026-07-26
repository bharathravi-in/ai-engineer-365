# SkillMap — study roadmaps for every stack

SkillMap is a roadmap.sh-style learning planner. Admins author **tracks**
(Frontend, Backend, DevOps, AI Engineer, …) as **modules → concepts** with
reference materials; learners pick a track, see it as a **visual journey** (or
accordion list), open any concept in a **side panel** with docs/videos, and get
a **day-by-day plan** scheduled around their weekday/weekend study hours.

## Architecture

```
Browser (React SPA)  ──/api──►  Node API (Express)  ──service-role──►  Supabase (Postgres)
        │                              │
   Supabase Auth (JWT) ───────────────┘  verifies JWT, enforces authz, is the only DB gate
```

- **app/** — React 19 + TypeScript + Vite + MUI. Auth via Supabase (browser); all data via the Node API.
- **server/** — Express API. Holds the service-role key, verifies the Supabase JWT, re-enforces every authorization rule. In production it also serves the built frontend (single origin).
- **supabase/** — SQL migrations (`0002_tracks.sql` is the live schema) + seed. RLS is enabled as defense-in-depth.
- **scripts/** — `curriculum.mjs` (content source) → `gen-tracks-seed.mjs` → `supabase/seed_tracks.sql`.

Data model: `tracks → modules → topics` (topic = concept with `est_hours` +
`resources` JSONB) · `enrollments` (start date + weekday/weekend hours) ·
`topic_progress` / `topic_notes` · `profiles` (admin flag).

## Run locally

```bash
# 1. API
cd server && cp .env.example .env   # fill SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY
npm install && npm run dev          # http://localhost:8787

# 2. Frontend
cd app && cp .env.example .env.local # fill VITE_SUPABASE_URL + VITE_SUPABASE_ANON_KEY
npm install && npm run dev           # http://localhost:5173 (proxies /api → :8787)
```

## Provision the database

Run the SQL against your Supabase Postgres (SQL editor or `psql`):

```bash
psql "$DATABASE_URL" -f supabase/migrations/0001_init.sql   # profiles, is_admin(), auth trigger
psql "$DATABASE_URL" -f supabase/migrations/0002_tracks.sql # tracks/modules/topics + enrollment/progress
psql "$DATABASE_URL" -f supabase/seed_tracks.sql            # starter curriculum (4 tracks)
```

Grant yourself admin after signing up: `update public.profiles set is_admin=true where email='you@example.com';`

Edit curriculum in `scripts/curriculum.mjs`, then `node scripts/gen-tracks-seed.mjs` and re-run the seed. Or author tracks in-app via the **Admin** panel.

## Production deploy (Docker, single image)

The API serves the built SPA, so one container is the whole app.

```bash
cp .env.example .env     # fill Supabase + public origin values
docker compose up --build -d
# → http://localhost:8787   (put a TLS-terminating reverse proxy / CDN in front)
```

Without Docker: `cd app && npm run build`, then run the server with
`NODE_ENV=production` and `STATIC_DIR=../app/dist` (`cd server && npm start`).

### Production hardening built in
- `helmet` security headers, `compression` (gzip), request logging (`morgan`).
- Rate limiting on `/api` (+ stricter on `/api/tracks/admin`).
- `trust proxy`, JSON body cap (1 MB), JSON 404s, graceful shutdown, `/health` probe.

### Operational checklist (do before going live)
1. **Rotate the Supabase service-role key and DB password** if they were ever shared, and set them only via server env / secrets — never in the repo or the frontend build.
2. **Configure SMTP** in Supabase Auth (or disable email confirmation) so real signups can verify.
3. Set **`CORS_ORIGIN`** and the frontend build args (`VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`) to production values; terminate **TLS** at your proxy/CDN.
4. Keep RLS enabled; the service-role key stays server-side only.

## Repository layout

```text
app/        React SPA (pages/, components/, lib/, trackStore.ts, store.ts)
server/     Express API (routes/tracks.ts, routes/me.ts, auth.ts, supabase.ts)
supabase/   migrations/ + seed_tracks.sql
scripts/    curriculum.mjs, gen-tracks-seed.mjs
Dockerfile, docker-compose.yml, .env.example
```

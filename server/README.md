# AI Engineer 365 — API server

A small Node.js (Express) service that sits between the React app and Supabase.

```
React app  ──fetch /api/*──►  this server  ──service-role key──►  Supabase
```

## Why it exists

The browser used to talk to Supabase directly, protected only by Row Level
Security. This server centralizes all data access so that:

- The **service-role key** (which bypasses RLS) never leaves the server.
- Every authorization rule is re-enforced in code (`src/auth.ts` + route
  handlers) before any database call.

Authentication still happens **in the browser** via Supabase Auth. The client
sends its session JWT as `Authorization: Bearer <token>`; this server verifies
it (`supabase.auth.getUser`) and derives the user id and admin flag itself — it
never trusts identity from the request body.

## Setup

```bash
cd server
cp .env.example .env      # fill in SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY
npm install
npm run dev               # http://localhost:8787
```

Then run the frontend (`cd app && npm run dev`). The Vite dev server proxies
`/api` → `http://localhost:8787`, so no CORS setup is needed in dev.

## Endpoints

| Method + path | Auth | Purpose |
|---|---|---|
| `GET /health` | — | Liveness check |
| `GET /api/plans` | optional | Months + days (published only unless admin) |
| `GET /api/me` | user | Caller's profile (`is_admin`) |
| `GET /api/me/state` | user | Caller's progress + notes |
| `PUT /api/me/progress/:day` | user | Mark a day complete/incomplete |
| `PUT /api/me/notes/:day` | user | Save a day note |
| `POST /api/admin/months` | admin | Create/update a month |
| `POST /api/admin/days` | admin | Create/update a day |
| `PATCH /api/admin/months/:month/status` | admin | Publish/unpublish a month |
| `PATCH /api/admin/days/:day/status` | admin | Publish/unpublish a day |
| `DELETE /api/admin/days/:day` | admin | Delete a day |
| `DELETE /api/admin/months/:month` | admin | Delete a month (cascades days) |

RLS in `supabase/migrations` is kept as defense-in-depth; the service-role key
legitimately bypasses it, so these handlers are the real gate.

import { createClient, type SupabaseClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined;

/** True only when both env vars are present and the key isn't a placeholder. */
export const isSupabaseConfigured = Boolean(
  url && anonKey && !anonKey.startsWith('PASTE_') && !anonKey.startsWith('your-'),
);

/** Shared client used for AUTH ONLY (login, session, sign-out). All data access
 *  goes through the Node API (see lib/api.ts) — this client never reads/writes
 *  application tables directly. Null when unconfigured, so the app falls back to
 *  bundled JSON + localStorage and runs offline. */
export const supabase: SupabaseClient | null = isSupabaseConfigured
  ? createClient(url as string, anonKey as string, {
      auth: { persistSession: true, autoRefreshToken: true },
    })
  : null;

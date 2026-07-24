import { createClient } from '@supabase/supabase-js';

const url = process.env.SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceKey) {
  throw new Error(
    'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. Copy server/.env.example to server/.env and fill in the values.',
  );
}

/**
 * Single service-role client for the whole process. The service-role key
 * BYPASSES Row Level Security, so every route MUST re-enforce authorization
 * itself (see src/auth.ts and the route handlers) before using this client.
 * It is created without session persistence — the server is stateless.
 */
export const admin = createClient(url, serviceKey, {
  auth: { persistSession: false, autoRefreshToken: false },
});

export type PlanStatus = 'draft' | 'published';

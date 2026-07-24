import type { NextFunction, Request, Response } from 'express';
import { admin } from './supabase.js';

/**
 * Authenticated user attached to the request by the middleware below.
 * `isAdmin` is resolved from the profiles table, never trusted from the client.
 */
export type AuthUser = { id: string; email: string | null; isAdmin: boolean };

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      authUser?: AuthUser;
    }
  }
}

function bearerToken(req: Request): string | null {
  const header = req.header('authorization') ?? '';
  const [scheme, token] = header.split(' ');
  if (scheme?.toLowerCase() === 'bearer' && token) return token;
  return null;
}

/** Verify the forwarded Supabase JWT and load the caller's admin flag. */
async function resolveUser(token: string): Promise<AuthUser | null> {
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return null;
  const { data: profile } = await admin
    .from('profiles')
    .select('is_admin')
    .eq('id', data.user.id)
    .maybeSingle();
  return {
    id: data.user.id,
    email: data.user.email ?? null,
    isAdmin: Boolean(profile?.is_admin),
  };
}

/** Attaches req.authUser when a valid token is present; never rejects. */
export async function optionalUser(req: Request, _res: Response, next: NextFunction) {
  const token = bearerToken(req);
  if (token) {
    try {
      req.authUser = (await resolveUser(token)) ?? undefined;
    } catch {
      req.authUser = undefined;
    }
  }
  next();
}

/** Rejects with 401 unless a valid token identifies a user. */
export async function requireUser(req: Request, res: Response, next: NextFunction) {
  const token = bearerToken(req);
  if (!token) return res.status(401).json({ error: 'Authentication required.' });
  let user: AuthUser | null = null;
  try {
    user = await resolveUser(token);
  } catch {
    return res.status(401).json({ error: 'Invalid or expired session.' });
  }
  if (!user) return res.status(401).json({ error: 'Invalid or expired session.' });
  req.authUser = user;
  next();
}

/** Rejects with 401/403 unless the caller is an authenticated admin. */
export async function requireAdmin(req: Request, res: Response, next: NextFunction) {
  await requireUser(req, res, () => {
    if (!req.authUser?.isAdmin) {
      res.status(403).json({ error: 'Admin access required.' });
      return;
    }
    next();
  });
}

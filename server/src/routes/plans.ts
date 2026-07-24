import { Router } from 'express';
import { admin } from '../supabase.js';
import { optionalUser } from '../auth.js';

export const plansRouter = Router();

/**
 * GET /api/plans
 * Mirrors the months_read / days_read RLS policies: anonymous and non-admin
 * users see only PUBLISHED rows; admins see everything. Returns raw rows so the
 * client can keep using assembleMonths() from app/src/lib/mappers.ts.
 */
plansRouter.get('/', optionalUser, async (req, res) => {
  const isAdmin = Boolean(req.authUser?.isAdmin);

  let monthsQuery = admin.from('months').select('*');
  let daysQuery = admin.from('days').select('*');
  if (!isAdmin) {
    monthsQuery = monthsQuery.eq('status', 'published');
    daysQuery = daysQuery.eq('status', 'published');
  }

  const [monthsRes, daysRes] = await Promise.all([monthsQuery, daysQuery]);
  if (monthsRes.error || daysRes.error) {
    return res
      .status(500)
      .json({ error: monthsRes.error?.message ?? daysRes.error?.message ?? 'Failed to load plans.' });
  }

  res.json({ months: monthsRes.data ?? [], days: daysRes.data ?? [] });
});

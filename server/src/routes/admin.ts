import { Router } from 'express';
import { admin } from '../supabase.js';
import { requireAdmin } from '../auth.js';

export const adminRouter = Router();

// Every /api/admin route requires an authenticated admin (mirrors the
// *_admin_write RLS policies, which gate on public.is_admin(auth.uid())).
adminRouter.use(requireAdmin);

/** POST /api/admin/months — upsert a month on month_number. */
adminRouter.post('/months', async (req, res) => {
  const b = req.body ?? {};
  if (!Number.isInteger(b.month_number)) {
    return res.status(400).json({ error: 'month_number is required.' });
  }
  const { error } = await admin.from('months').upsert(
    {
      month_number: b.month_number,
      title: b.title ?? '',
      goal: b.goal ?? '',
      project: b.project ?? {},
      status: b.status ?? 'draft',
    },
    { onConflict: 'month_number' },
  );
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/**
 * POST /api/admin/days — upsert a day on day_number.
 * Resolves month_id from month_number first (as adminSaveDay did in the store).
 */
adminRouter.post('/days', async (req, res) => {
  const b = req.body ?? {};
  const monthNumber = Number(b.month_number);
  if (!Number.isInteger(monthNumber) || !Number.isInteger(b.day_number)) {
    return res.status(400).json({ error: 'month_number and day_number are required.' });
  }

  const { data: monthRow, error: monthErr } = await admin
    .from('months')
    .select('id')
    .eq('month_number', monthNumber)
    .maybeSingle();
  if (monthErr) return res.status(500).json({ error: monthErr.message });
  if (!monthRow) {
    return res.status(400).json({ error: `Month ${monthNumber} does not exist yet — create it first.` });
  }

  const { error } = await admin.from('days').upsert(
    {
      month_id: monthRow.id,
      day_number: b.day_number,
      title: b.title ?? '',
      duration: b.duration ?? '2h',
      learning_objective: b.learning_objective ?? '',
      videos: b.videos ?? [],
      docs: b.docs ?? [],
      reading: b.reading ?? [],
      practice: b.practice ?? [],
      tasks: b.tasks ?? [],
      mini_project: b.mini_project ?? '',
      interview_questions: b.interview_questions ?? [],
      status: b.status ?? 'draft',
    },
    { onConflict: 'day_number' },
  );
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/** PATCH /api/admin/months/:month/status  body { status } */
adminRouter.patch('/months/:month/status', async (req, res) => {
  const monthNumber = Number(req.params.month);
  const status = req.body?.status;
  if (!Number.isInteger(monthNumber)) return res.status(400).json({ error: 'Invalid month number.' });
  const { error } = await admin.from('months').update({ status }).eq('month_number', monthNumber);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/** PATCH /api/admin/days/:day/status  body { status } */
adminRouter.patch('/days/:day/status', async (req, res) => {
  const dayNumber = Number(req.params.day);
  const status = req.body?.status;
  if (!Number.isInteger(dayNumber)) return res.status(400).json({ error: 'Invalid day number.' });
  const { error } = await admin.from('days').update({ status }).eq('day_number', dayNumber);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/** DELETE /api/admin/days/:day */
adminRouter.delete('/days/:day', async (req, res) => {
  const dayNumber = Number(req.params.day);
  if (!Number.isInteger(dayNumber)) return res.status(400).json({ error: 'Invalid day number.' });
  const { error } = await admin.from('days').delete().eq('day_number', dayNumber);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/** DELETE /api/admin/months/:month (cascades to days via FK) */
adminRouter.delete('/months/:month', async (req, res) => {
  const monthNumber = Number(req.params.month);
  if (!Number.isInteger(monthNumber)) return res.status(400).json({ error: 'Invalid month number.' });
  const { error } = await admin.from('months').delete().eq('month_number', monthNumber);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

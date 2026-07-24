import { Router } from 'express';
import { admin } from '../supabase.js';
import { requireUser } from '../auth.js';

export const meRouter = Router();

// All /api/me routes require a valid session; the user id always comes from the
// verified JWT (req.authUser.id), never from the request body or params.
meRouter.use(requireUser);

/** GET /api/me — the caller's profile (used for the admin gate on the client). */
meRouter.get('/', (req, res) => {
  const user = req.authUser!;
  res.json({ id: user.id, email: user.email, is_admin: user.isAdmin });
});

/**
 * GET /api/me/state — the caller's progress + notes.
 * Replaces loadUserState(); owner-scoped like the progress/notes RLS policies.
 */
meRouter.get('/state', async (req, res) => {
  const userId = req.authUser!.id;
  const [progressRes, notesRes] = await Promise.all([
    admin.from('progress').select('day_number, completed').eq('user_id', userId),
    admin.from('notes').select('day_number, content').eq('user_id', userId),
  ]);
  if (progressRes.error || notesRes.error) {
    return res
      .status(500)
      .json({ error: progressRes.error?.message ?? notesRes.error?.message ?? 'Failed to load state.' });
  }
  res.json({ progress: progressRes.data ?? [], notes: notesRes.data ?? [] });
});

/** PUT /api/me/progress/:day  body { completed } — replaces toggleDay(). */
meRouter.put('/progress/:day', async (req, res) => {
  const userId = req.authUser!.id;
  const day = Number(req.params.day);
  if (!Number.isInteger(day)) return res.status(400).json({ error: 'Invalid day number.' });
  const completed = Boolean(req.body?.completed);

  const { error } = completed
    ? await admin.from('progress').upsert({ user_id: userId, day_number: day, completed: true })
    : await admin.from('progress').delete().eq('user_id', userId).eq('day_number', day);

  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/** PUT /api/me/notes/:day  body { content } — replaces saveNote(). */
meRouter.put('/notes/:day', async (req, res) => {
  const userId = req.authUser!.id;
  const day = Number(req.params.day);
  if (!Number.isInteger(day)) return res.status(400).json({ error: 'Invalid day number.' });
  const content = typeof req.body?.content === 'string' ? req.body.content : '';

  const { error } = await admin
    .from('notes')
    .upsert({ user_id: userId, day_number: day, content });

  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

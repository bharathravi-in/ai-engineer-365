import { Router } from 'express';
import { admin } from '../supabase.js';
import { optionalUser, requireUser, requireAdmin } from '../auth.js';

export const tracksRouter = Router();

// ---------------------------------------------------------------------------
// Admin: create/edit study plans (tracks -> modules -> topics). Admin only.
// Defined first so their concrete paths win over GET '/:slug'.
// ---------------------------------------------------------------------------
const adminApi = Router();
adminApi.use(requireAdmin);

/** POST /api/tracks/admin/track — create or update a track (upsert by slug). */
adminApi.post('/track', async (req, res) => {
  const b = req.body ?? {};
  if (!b.slug || !b.title) return res.status(400).json({ error: 'slug and title are required.' });
  const { error } = await admin.from('tracks').upsert(
    {
      slug: b.slug,
      title: b.title,
      subtitle: b.subtitle ?? '',
      description: b.description ?? '',
      icon: b.icon || '📚',
      color: b.color || '#6366f1',
      difficulty: b.difficulty ?? 'Beginner → Advanced',
      status: b.status ?? 'draft',
      sort_order: Number.isFinite(b.sort_order) ? b.sort_order : 0,
    },
    { onConflict: 'slug' },
  );
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

adminApi.delete('/track/:id', async (req, res) => {
  const { error } = await admin.from('tracks').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/** POST /api/tracks/admin/module — upsert a module (update by id, else insert). */
adminApi.post('/module', async (req, res) => {
  const b = req.body ?? {};
  if (!b.track_id || !b.slug || !b.title) return res.status(400).json({ error: 'track_id, slug and title are required.' });
  const row = { track_id: b.track_id, slug: b.slug, title: b.title, goal: b.goal ?? '', sort_order: Number(b.sort_order) || 0 };
  const { error } = b.id
    ? await admin.from('modules').update(row).eq('id', b.id)
    : await admin.from('modules').insert(row);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

adminApi.delete('/module/:id', async (req, res) => {
  const { error } = await admin.from('modules').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/** POST /api/tracks/admin/topic — upsert a topic (update by id, else insert). */
adminApi.post('/topic', async (req, res) => {
  const b = req.body ?? {};
  if (!b.module_id || !b.slug || !b.title) return res.status(400).json({ error: 'module_id, slug and title are required.' });
  const resources = Array.isArray(b.resources)
    ? b.resources.filter((r: any) => r && r.title && r.url).map((r: any) => ({ kind: r.kind || 'doc', title: r.title, url: r.url }))
    : [];
  const row = {
    module_id: b.module_id,
    slug: b.slug,
    title: b.title,
    description: b.description ?? '',
    est_hours: Number(b.est_hours) || 2,
    resources,
    status: b.status ?? 'draft',
    sort_order: Number(b.sort_order) || 0,
  };
  const { error } = b.id
    ? await admin.from('topics').update(row).eq('id', b.id)
    : await admin.from('topics').insert(row);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

adminApi.delete('/topic/:id', async (req, res) => {
  const { error } = await admin.from('topics').delete().eq('id', req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

const slugify = (s: string) =>
  String(s || '').toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');

/**
 * POST /api/tracks/admin/import — create a whole track from a single JSON doc.
 * Upserts the track (by slug) then REPLACES its modules/topics with the payload.
 * Body: { slug?, title, subtitle?, description?, icon?, color?, difficulty?,
 *         status?, modules: [{ slug?, title, goal?, topics: [{ slug?, title,
 *         description?, est_hours?, status?, resources?: [{kind,title,url}] }] }] }
 */
adminApi.post('/import', async (req, res) => {
  const b = req.body ?? {};
  if (!b.title || !Array.isArray(b.modules)) {
    return res.status(400).json({ error: 'JSON must include a "title" and a "modules" array.' });
  }
  const trackSlug = slugify(b.slug || b.title);

  const { data: track, error: te } = await admin
    .from('tracks')
    .upsert(
      {
        slug: trackSlug,
        title: b.title,
        subtitle: b.subtitle ?? '',
        description: b.description ?? '',
        icon: b.icon || '📚',
        color: b.color || '#6366f1',
        difficulty: b.difficulty ?? 'Beginner → Advanced',
        status: b.status ?? 'draft',
        sort_order: Number.isFinite(b.sort_order) ? b.sort_order : 0,
      },
      { onConflict: 'slug' },
    )
    .select('id')
    .single();
  if (te || !track) return res.status(500).json({ error: te?.message ?? 'Failed to save track.' });

  // Replace existing content.
  const del = await admin.from('modules').delete().eq('track_id', track.id);
  if (del.error) return res.status(500).json({ error: del.error.message });

  let moduleCount = 0;
  let topicCount = 0;
  for (const [mi, m] of (b.modules as any[]).entries()) {
    if (!m?.title) continue;
    const { data: moduleRow, error: me } = await admin
      .from('modules')
      .insert({ track_id: track.id, slug: slugify(m.slug || m.title) || `module-${mi + 1}`, title: m.title, goal: m.goal ?? '', sort_order: mi })
      .select('id')
      .single();
    if (me || !moduleRow) return res.status(500).json({ error: me?.message ?? 'Failed to save a module.' });
    moduleCount += 1;

    const topics = Array.isArray(m.topics) ? m.topics : [];
    const rows = topics
      .filter((t: any) => t?.title)
      .map((t: any, ti: number) => ({
        module_id: moduleRow.id,
        slug: slugify(t.slug || t.title) || `topic-${ti + 1}`,
        title: t.title,
        description: t.description ?? '',
        est_hours: Number(t.est_hours) || 2,
        resources: Array.isArray(t.resources)
          ? t.resources.filter((r: any) => r?.title && r?.url).map((r: any) => ({ kind: r.kind || 'doc', title: r.title, url: r.url }))
          : [],
        status: t.status ?? b.status ?? 'published',
        sort_order: ti,
      }));
    if (rows.length) {
      const { error: pe } = await admin.from('topics').insert(rows);
      if (pe) return res.status(500).json({ error: pe.message });
      topicCount += rows.length;
    }
  }

  res.json({ ok: true, slug: trackSlug, modules: moduleCount, topics: topicCount });
});

tracksRouter.use('/admin', adminApi);

// ---------------------------------------------------------------------------
// Public catalog + detail (admins additionally see drafts)
// ---------------------------------------------------------------------------

/** GET /api/tracks — catalog with module/topic counts + total hours. */
tracksRouter.get('/', optionalUser, async (req, res) => {
  const isAdmin = Boolean(req.authUser?.isAdmin);
  let tq = admin.from('tracks').select('*').order('sort_order');
  if (!isAdmin) tq = tq.eq('status', 'published');
  const { data: tracks, error } = await tq;
  if (error) return res.status(500).json({ error: error.message });

  const trackIds = (tracks ?? []).map((t) => t.id);
  const { data: modules } = await admin.from('modules').select('id, track_id').in('track_id', trackIds.length ? trackIds : ['00000000-0000-0000-0000-000000000000']);
  const moduleIds = (modules ?? []).map((m) => m.id);
  let topicsQ = admin.from('topics').select('module_id, est_hours').in('module_id', moduleIds.length ? moduleIds : ['00000000-0000-0000-0000-000000000000']);
  if (!isAdmin) topicsQ = topicsQ.eq('status', 'published');
  const { data: topics } = await topicsQ;

  const moduleToTrack = new Map((modules ?? []).map((m) => [m.id, m.track_id]));
  const stats = new Map<string, { modules: number; topics: number; hours: number }>();
  for (const m of modules ?? []) {
    const s = stats.get(m.track_id) ?? { modules: 0, topics: 0, hours: 0 };
    s.modules += 1;
    stats.set(m.track_id, s);
  }
  for (const t of topics ?? []) {
    const trackId = moduleToTrack.get(t.module_id);
    if (!trackId) continue;
    const s = stats.get(trackId) ?? { modules: 0, topics: 0, hours: 0 };
    s.topics += 1;
    s.hours += Number(t.est_hours) || 0;
    stats.set(trackId, s);
  }

  res.json({
    tracks: (tracks ?? []).map((t) => ({
      ...t,
      module_count: stats.get(t.id)?.modules ?? 0,
      topic_count: stats.get(t.id)?.topics ?? 0,
      total_hours: Math.round(stats.get(t.id)?.hours ?? 0),
    })),
  });
});

/** GET /api/tracks/:slug — track + nested modules -> topics (with resources). */
tracksRouter.get('/:slug', optionalUser, async (req, res) => {
  const isAdmin = Boolean(req.authUser?.isAdmin);
  let trackQ = admin.from('tracks').select('*').eq('slug', req.params.slug);
  if (!isAdmin) trackQ = trackQ.eq('status', 'published');
  const { data: track, error } = await trackQ.maybeSingle();
  if (error) return res.status(500).json({ error: error.message });
  if (!track) return res.status(404).json({ error: 'Track not found.' });

  const { data: modules } = await admin
    .from('modules')
    .select('*')
    .eq('track_id', track.id)
    .order('sort_order');
  const moduleIds = (modules ?? []).map((m) => m.id);
  let topicsQ = admin
    .from('topics')
    .select('*')
    .in('module_id', moduleIds.length ? moduleIds : ['00000000-0000-0000-0000-000000000000'])
    .order('sort_order');
  if (!isAdmin) topicsQ = topicsQ.eq('status', 'published');
  const { data: topics } = await topicsQ;

  const topicsByModule = new Map<string, unknown[]>();
  for (const t of topics ?? []) {
    const list = topicsByModule.get(t.module_id) ?? [];
    list.push(t);
    topicsByModule.set(t.module_id, list);
  }

  res.json({
    track,
    modules: (modules ?? []).map((m) => ({ ...m, topics: topicsByModule.get(m.id) ?? [] })),
  });
});

// ---------------------------------------------------------------------------
// Enrollment + learner state (all require a signed-in user)
// ---------------------------------------------------------------------------

/** GET /api/tracks/me/enrollments — the caller's enrollments. */
tracksRouter.get('/me/enrollments', requireUser, async (req, res) => {
  const { data, error } = await admin
    .from('enrollments')
    .select('*')
    .eq('user_id', req.authUser!.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ enrollments: data ?? [] });
});

/** POST /api/tracks/enroll — upsert an enrollment (track + availability). */
tracksRouter.post('/enroll', requireUser, async (req, res) => {
  const b = req.body ?? {};
  if (!b.track_id) return res.status(400).json({ error: 'track_id is required.' });
  const row = {
    user_id: req.authUser!.id,
    track_id: b.track_id,
    start_date: b.start_date ?? new Date().toISOString().slice(0, 10),
    weekday_hours: Number(b.weekday_hours) || 2,
    weekend_hours: Number(b.weekend_hours) || 4,
    updated_at: new Date().toISOString(),
  };
  const { error } = await admin.from('enrollments').upsert(row, { onConflict: 'user_id,track_id' });
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/** DELETE /api/tracks/enroll/:trackId — leave a track. */
tracksRouter.delete('/enroll/:trackId', requireUser, async (req, res) => {
  const { error } = await admin
    .from('enrollments')
    .delete()
    .eq('user_id', req.authUser!.id)
    .eq('track_id', req.params.trackId);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/** GET /api/tracks/me/state/:trackId — progress + notes for a track's topics. */
tracksRouter.get('/me/state/:trackId', requireUser, async (req, res) => {
  const userId = req.authUser!.id;
  // topic ids in this track
  const { data: modules } = await admin.from('modules').select('id').eq('track_id', req.params.trackId);
  const moduleIds = (modules ?? []).map((m) => m.id);
  const { data: topics } = await admin
    .from('topics')
    .select('id')
    .in('module_id', moduleIds.length ? moduleIds : ['00000000-0000-0000-0000-000000000000']);
  const topicIds = (topics ?? []).map((t) => t.id);
  const idFilter = topicIds.length ? topicIds : ['00000000-0000-0000-0000-000000000000'];

  const [progressRes, notesRes] = await Promise.all([
    admin.from('topic_progress').select('topic_id, completed').eq('user_id', userId).in('topic_id', idFilter),
    admin.from('topic_notes').select('topic_id, content').eq('user_id', userId).in('topic_id', idFilter),
  ]);
  if (progressRes.error || notesRes.error) {
    return res.status(500).json({ error: progressRes.error?.message ?? notesRes.error?.message });
  }
  res.json({ progress: progressRes.data ?? [], notes: notesRes.data ?? [] });
});

/** PUT /api/tracks/me/progress/:topicId  body { completed } */
tracksRouter.put('/me/progress/:topicId', requireUser, async (req, res) => {
  const userId = req.authUser!.id;
  const topicId = req.params.topicId;
  const completed = Boolean(req.body?.completed);
  const { error } = completed
    ? await admin.from('topic_progress').upsert({ user_id: userId, topic_id: topicId, completed: true })
    : await admin.from('topic_progress').delete().eq('user_id', userId).eq('topic_id', topicId);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/** PUT /api/tracks/me/notes/:topicId  body { content } */
tracksRouter.put('/me/notes/:topicId', requireUser, async (req, res) => {
  const userId = req.authUser!.id;
  const topicId = req.params.topicId;
  const content = typeof req.body?.content === 'string' ? req.body.content : '';
  const { error } = await admin.from('topic_notes').upsert({ user_id: userId, topic_id: topicId, content });
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

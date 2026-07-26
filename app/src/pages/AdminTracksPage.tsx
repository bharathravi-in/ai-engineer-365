import { useEffect, useState } from 'react';
import {
  Alert, Box, Button, Card, CardContent, Chip, Dialog, DialogActions, DialogContent, DialogTitle,
  Divider, IconButton, MenuItem, Stack, TextField, ToggleButton, ToggleButtonGroup, Tooltip, Typography,
} from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutlined';
import EditIcon from '@mui/icons-material/Edit';
import * as api from '../lib/api';
import type { Resource, TrackDetail, TrackSummary, Topic } from '../lib/api';
import { useDashboardStore, useIsAdmin } from '../store';
import PageHeader from '../components/PageHeader';
import TrackJsonImport from '../components/TrackJsonImport';

const slugify = (s: string) => s.toLowerCase().trim().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const KINDS = ['doc', 'article', 'video', 'practice', 'repo', 'course'];
const STATUS = ['draft', 'published'];

export default function AdminTracksPage() {
  const isAdmin = useIsAdmin();
  const authReady = useDashboardStore((s) => s.authReady);
  const [tracks, setTracks] = useState<TrackSummary[]>([]);
  const [slug, setSlug] = useState<string | null>(null);
  const [detail, setDetail] = useState<TrackDetail | null>(null);
  const [msg, setMsg] = useState<{ type: 'success' | 'error'; text: string } | null>(null);
  const [newMode, setNewMode] = useState<'form' | 'json'>('form');

  const reloadTracks = async () => {
    const { tracks } = await api.getTracks();
    setTracks(tracks);
    return tracks;
  };
  const reloadDetail = async (s: string) => setDetail(await api.getTrack(s));

  useEffect(() => { if (isAdmin) void reloadTracks(); }, [isAdmin]);
  useEffect(() => { if (slug) void reloadDetail(slug); else setDetail(null); }, [slug]);

  if (!authReady) return <Box><PageHeader overline="Admin" title="Loading…" /></Box>;
  if (!isAdmin) {
    return (
      <Box>
        <PageHeader overline="Admin" title="Admins only" subtitle="Your account doesn't have admin access." />
        <Alert severity="warning">Ask an existing admin to grant access.</Alert>
      </Box>
    );
  }

  const flash = (type: 'success' | 'error', text: string) => { setMsg({ type, text }); window.setTimeout(() => setMsg(null), 3000); };

  return (
    <Box>
      <PageHeader overline="Admin" title="Build study plans" subtitle="Create tracks, then add modules and concepts with reference materials. Publish to make them visible to learners." />
      {msg && <Alert severity={msg.type} sx={{ mb: 2 }} onClose={() => setMsg(null)}>{msg.text}</Alert>}

      <Stack direction="row" spacing={1} sx={{ mb: 3, flexWrap: 'wrap', gap: 1 }}>
        {tracks.map((t) => (
          <Chip key={t.id} label={`${t.icon} ${t.title}`} onClick={() => setSlug(t.slug)} color={slug === t.slug ? 'primary' : 'default'} variant={slug === t.slug ? 'filled' : 'outlined'} />
        ))}
        <Chip icon={<AddIcon />} label="New track" onClick={() => setSlug('__new__')} color={slug === '__new__' ? 'primary' : 'default'} variant={slug === '__new__' ? 'filled' : 'outlined'} />
      </Stack>

      {slug === '__new__' ? (
        <>
          <ToggleButtonGroup
            size="small"
            exclusive
            value={newMode}
            onChange={(_, v) => v && setNewMode(v)}
            sx={{ mb: 2, '& .MuiToggleButton-root': { textTransform: 'none', px: 2 } }}
          >
            <ToggleButton value="form">Build with form</ToggleButton>
            <ToggleButton value="json">Paste JSON</ToggleButton>
          </ToggleButtonGroup>
          {newMode === 'form' ? (
            <TrackForm
              key="new"
              onSaved={async (newSlug) => { await reloadTracks(); setSlug(newSlug); flash('success', 'Track created.'); }}
              onError={(e) => flash('error', e)}
            />
          ) : (
            <TrackJsonImport
              onImported={async (newSlug, counts) => { await reloadTracks(); setSlug(newSlug); flash('success', `Imported ${counts.modules} modules / ${counts.topics} concepts.`); }}
              onError={(e) => flash('error', e)}
            />
          )}
        </>
      ) : detail ? (
        <>
          <TrackForm
            key={detail.track.slug}
            existing={detail.track}
            onSaved={async () => { await reloadTracks(); await reloadDetail(detail.track.slug); flash('success', 'Track saved.'); }}
            onError={(e) => flash('error', e)}
            onDeleted={async () => { await reloadTracks(); setSlug(null); flash('success', 'Track deleted.'); }}
          />
          <ModulesEditor detail={detail} onChange={() => reloadDetail(detail.track.slug)} onFlash={flash} />
        </>
      ) : (
        <Alert severity="info">Select a track to edit, or create a new one.</Alert>
      )}
    </Box>
  );
}

function TrackForm({ existing, onSaved, onError, onDeleted }: {
  existing?: TrackDetail['track'];
  onSaved: (slug: string) => void;
  onError: (e: string) => void;
  onDeleted?: () => void;
}) {
  const [f, setF] = useState({
    slug: existing?.slug ?? '', title: existing?.title ?? '', subtitle: existing?.subtitle ?? '',
    description: existing?.description ?? '', icon: existing?.icon ?? '📚', color: existing?.color ?? '#6366f1',
    difficulty: existing?.difficulty ?? 'Beginner → Advanced', status: (existing as any)?.status ?? 'draft',
  });
  const set = (k: string, v: string) => setF((s) => ({ ...s, [k]: v }));

  const save = async () => {
    const slug = f.slug || slugify(f.title);
    if (!f.title) return onError('Title is required.');
    try { await api.adminSaveTrack({ ...f, slug }); onSaved(slug); }
    catch (e) { onError(e instanceof Error ? e.message : 'Failed to save track.'); }
  };

  return (
    <Card sx={{ mb: 2 }}>
      <CardContent>
        <Typography variant="h6" sx={{ mb: 2 }}>{existing ? 'Edit track' : 'New track'}</Typography>
        <Stack spacing={2}>
          <Stack direction="row" spacing={2}>
            <TextField label="Icon (emoji)" value={f.icon} onChange={(e) => set('icon', e.target.value)} sx={{ width: 120 }} />
            <TextField label="Title" value={f.title} onChange={(e) => set('title', e.target.value)} fullWidth />
            <TextField label="Color" type="color" value={f.color} onChange={(e) => set('color', e.target.value)} sx={{ width: 90 }} />
          </Stack>
          <Stack direction="row" spacing={2}>
            <TextField label="Slug" value={f.slug} onChange={(e) => set('slug', e.target.value)} placeholder={slugify(f.title)} fullWidth disabled={Boolean(existing)} helperText={existing ? 'Slug is fixed' : 'Auto from title if blank'} />
            <TextField select label="Status" value={f.status} onChange={(e) => set('status', e.target.value)} sx={{ width: 160 }}>
              {STATUS.map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
            </TextField>
          </Stack>
          <TextField label="Subtitle" value={f.subtitle} onChange={(e) => set('subtitle', e.target.value)} fullWidth />
          <TextField label="Description" value={f.description} onChange={(e) => set('description', e.target.value)} fullWidth multiline minRows={2} />
          <TextField label="Difficulty" value={f.difficulty} onChange={(e) => set('difficulty', e.target.value)} fullWidth />
          <Stack direction="row" spacing={1}>
            <Button variant="contained" onClick={() => void save()}>{existing ? 'Save track' : 'Create track'}</Button>
            {existing && onDeleted && (
              <Button color="error" onClick={() => { if (window.confirm(`Delete "${existing.title}" and all its modules/topics?`)) api.adminDeleteTrack((existing as any).id).then(onDeleted).catch((e) => onError(e.message)); }}>Delete</Button>
            )}
          </Stack>
        </Stack>
      </CardContent>
    </Card>
  );
}

function ModulesEditor({ detail, onChange, onFlash }: {
  detail: TrackDetail;
  onChange: () => void;
  onFlash: (t: 'success' | 'error', m: string) => void;
}) {
  const trackId = (detail.track as any).id as string;
  const [topicDialog, setTopicDialog] = useState<{ moduleId: string; topic?: Topic } | null>(null);

  const addModule = async () => {
    const title = window.prompt('Module title?');
    if (!title) return;
    try { await api.adminSaveModule({ track_id: trackId, slug: slugify(title), title, sort_order: detail.modules.length }); onChange(); onFlash('success', 'Module added.'); }
    catch (e) { onFlash('error', e instanceof Error ? e.message : 'Failed.'); }
  };
  const renameModule = async (m: TrackDetail['modules'][number]) => {
    const title = window.prompt('Module title', m.title); if (!title) return;
    const goal = window.prompt('Module goal (short)', m.goal) ?? m.goal;
    try { await api.adminSaveModule({ id: m.id, track_id: trackId, slug: m.slug, title, goal, sort_order: m.sort_order }); onChange(); }
    catch (e) { onFlash('error', e instanceof Error ? e.message : 'Failed.'); }
  };

  return (
    <Card>
      <CardContent>
        <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
          <Typography variant="h6">Modules & concepts</Typography>
          <Button size="small" startIcon={<AddIcon />} onClick={() => void addModule()}>Add module</Button>
        </Stack>
        {detail.modules.length === 0 && <Typography variant="body2" color="text.secondary">No modules yet. Add the first one.</Typography>}
        <Stack spacing={2} sx={{ mt: 1 }}>
          {detail.modules.map((m) => (
            <Box key={m.id} sx={{ p: 2, border: 1, borderColor: 'divider', borderRadius: 3 }}>
              <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center' }}>
                <Box>
                  <Typography sx={{ fontWeight: 700 }}>{m.title}</Typography>
                  {m.goal && <Typography variant="caption" color="text.secondary">{m.goal}</Typography>}
                </Box>
                <Stack direction="row">
                  <Tooltip title="Rename"><IconButton size="small" onClick={() => void renameModule(m)}><EditIcon fontSize="small" /></IconButton></Tooltip>
                  <Tooltip title="Delete module"><IconButton size="small" color="error" onClick={() => { if (window.confirm(`Delete module "${m.title}"?`)) api.adminDeleteModule(m.id).then(onChange).catch((e) => onFlash('error', e.message)); }}><DeleteOutlineIcon fontSize="small" /></IconButton></Tooltip>
                </Stack>
              </Stack>
              <Divider sx={{ my: 1 }} />
              <Stack spacing={0.5}>
                {m.topics.map((t) => (
                  <Stack key={t.id} direction="row" spacing={1} sx={{ alignItems: 'center' }}>
                    <Typography variant="body2" sx={{ flexGrow: 1 }}>{t.title} <Chip size="small" variant="outlined" label={`${t.est_hours}h`} sx={{ ml: 0.5, height: 18 }} /> {(t as any).status === 'draft' && <Chip size="small" color="warning" variant="outlined" label="draft" sx={{ height: 18 }} />}</Typography>
                    <Typography variant="caption" color="text.secondary">{t.resources.length} links</Typography>
                    <IconButton size="small" onClick={() => setTopicDialog({ moduleId: m.id, topic: t })}><EditIcon fontSize="small" /></IconButton>
                    <IconButton size="small" color="error" onClick={() => { if (window.confirm(`Delete "${t.title}"?`)) api.adminDeleteTopic(t.id).then(onChange).catch((e) => onFlash('error', e.message)); }}><DeleteOutlineIcon fontSize="small" /></IconButton>
                  </Stack>
                ))}
                <Button size="small" startIcon={<AddIcon />} sx={{ alignSelf: 'flex-start' }} onClick={() => setTopicDialog({ moduleId: m.id })}>Add concept</Button>
              </Stack>
            </Box>
          ))}
        </Stack>
      </CardContent>

      {topicDialog && (
        <TopicDialog
          moduleId={topicDialog.moduleId}
          topic={topicDialog.topic}
          sortOrder={detail.modules.find((m) => m.id === topicDialog.moduleId)?.topics.length ?? 0}
          onClose={() => setTopicDialog(null)}
          onSaved={() => { setTopicDialog(null); onChange(); onFlash('success', 'Concept saved.'); }}
          onError={(e) => onFlash('error', e)}
        />
      )}
    </Card>
  );
}

function TopicDialog({ moduleId, topic, sortOrder, onClose, onSaved, onError }: {
  moduleId: string; topic?: Topic; sortOrder: number;
  onClose: () => void; onSaved: () => void; onError: (e: string) => void;
}) {
  const [title, setTitle] = useState(topic?.title ?? '');
  const [desc, setDesc] = useState(topic?.description ?? '');
  const [hours, setHours] = useState(String(topic?.est_hours ?? 2));
  const [status, setStatus] = useState((topic as any)?.status ?? 'published');
  const [resources, setResources] = useState<Resource[]>(topic?.resources ?? []);

  const addRes = () => setResources((r) => [...r, { kind: 'doc', title: '', url: '' }]);
  const setRes = (i: number, k: keyof Resource, v: string) => setResources((r) => r.map((x, j) => (j === i ? { ...x, [k]: v } : x)));
  const delRes = (i: number) => setResources((r) => r.filter((_, j) => j !== i));

  const save = async () => {
    if (!title) return onError('Concept title is required.');
    try {
      await api.adminSaveTopic({
        id: topic?.id, module_id: moduleId, slug: topic?.slug || slugify(title), title,
        description: desc, est_hours: Number(hours) || 2, status,
        resources: resources.filter((r) => r.title && r.url), sort_order: topic?.sort_order ?? sortOrder,
      });
      onSaved();
    } catch (e) { onError(e instanceof Error ? e.message : 'Failed to save concept.'); }
  };

  return (
    <Dialog open onClose={onClose} maxWidth="sm" fullWidth>
      <DialogTitle>{topic ? 'Edit concept' : 'New concept'}</DialogTitle>
      <DialogContent dividers>
        <Stack spacing={2} sx={{ mt: 0.5 }}>
          <Stack direction="row" spacing={2}>
            <TextField label="Title" value={title} onChange={(e) => setTitle(e.target.value)} fullWidth autoFocus />
            <TextField label="Hours" type="number" value={hours} onChange={(e) => setHours(e.target.value)} sx={{ width: 100 }} />
            <TextField select label="Status" value={status} onChange={(e) => setStatus(e.target.value)} sx={{ width: 130 }}>
              {STATUS.map((s) => <MenuItem key={s} value={s}>{s}</MenuItem>)}
            </TextField>
          </Stack>
          <TextField label="Explanation" value={desc} onChange={(e) => setDesc(e.target.value)} fullWidth multiline minRows={2} />
          <Divider textAlign="left">Reference materials</Divider>
          {resources.map((r, i) => (
            <Stack key={i} direction="row" spacing={1} sx={{ alignItems: 'center' }}>
              <TextField select size="small" label="Type" value={r.kind} onChange={(e) => setRes(i, 'kind', e.target.value)} sx={{ width: 120 }}>
                {KINDS.map((k) => <MenuItem key={k} value={k}>{k}</MenuItem>)}
              </TextField>
              <TextField size="small" label="Title" value={r.title} onChange={(e) => setRes(i, 'title', e.target.value)} sx={{ width: 160 }} />
              <TextField size="small" label="URL" value={r.url} onChange={(e) => setRes(i, 'url', e.target.value)} fullWidth />
              <IconButton size="small" color="error" onClick={() => delRes(i)}><DeleteOutlineIcon fontSize="small" /></IconButton>
            </Stack>
          ))}
          <Button size="small" startIcon={<AddIcon />} onClick={addRes} sx={{ alignSelf: 'flex-start' }}>Add link</Button>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={() => void save()}>Save concept</Button>
      </DialogActions>
    </Dialog>
  );
}

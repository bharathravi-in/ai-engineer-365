import { useMemo, useState } from 'react';
import {
  Alert, Box, Button, Card, CardContent, Chip, Divider, Stack, TextField, Typography,
} from '@mui/material';
import * as api from '../lib/api';

const EXAMPLE = {
  slug: 'nodejs',
  title: 'Node.js Developer',
  subtitle: 'Server-side JavaScript',
  description: 'Build fast, scalable backends with Node.js and Express.',
  icon: '🟢',
  color: '#16a34a',
  difficulty: 'Beginner → Advanced',
  status: 'published',
  modules: [
    {
      title: 'Node Fundamentals',
      goal: 'Understand the runtime and modules.',
      topics: [
        {
          title: 'Event loop & modules',
          description: 'How Node runs JavaScript; CommonJS vs ES modules.',
          est_hours: 3,
          resources: [
            { kind: 'doc', title: 'Node.js API docs', url: 'https://nodejs.org/docs/latest/api/' },
            { kind: 'video', title: 'Node.js crash course', url: 'https://www.youtube.com/results?search_query=node.js+crash+course' },
          ],
        },
        {
          title: 'npm & package.json',
          description: 'Managing dependencies and scripts.',
          est_hours: 2,
          resources: [{ kind: 'doc', title: 'npm docs', url: 'https://docs.npmjs.com/' }],
        },
      ],
    },
    {
      title: 'Building APIs with Express',
      goal: 'Create REST APIs.',
      topics: [
        {
          title: 'Routing & middleware',
          description: 'Handle requests with Express.',
          est_hours: 4,
          resources: [{ kind: 'doc', title: 'Express guide', url: 'https://expressjs.com/en/guide/routing.html' }],
        },
      ],
    },
  ],
};

type Parsed = { ok: true; data: any; modules: number; topics: number; links: number } | { ok: false; error: string };

function analyze(text: string): Parsed | null {
  if (!text.trim()) return null;
  let data: any;
  try {
    data = JSON.parse(text);
  } catch (e) {
    return { ok: false, error: `Invalid JSON: ${e instanceof Error ? e.message : 'parse error'}` };
  }
  if (!data || typeof data !== 'object') return { ok: false, error: 'Root must be an object.' };
  if (!data.title) return { ok: false, error: 'Missing "title".' };
  if (!Array.isArray(data.modules)) return { ok: false, error: 'Missing "modules" array.' };
  let topics = 0;
  let links = 0;
  for (const m of data.modules) {
    for (const t of m?.topics ?? []) {
      topics += 1;
      links += Array.isArray(t?.resources) ? t.resources.length : 0;
    }
  }
  return { ok: true, data, modules: data.modules.length, topics, links };
}

export default function TrackJsonImport({ onImported, onError }: {
  onImported: (slug: string, counts: { modules: number; topics: number }) => void;
  onError: (e: string) => void;
}) {
  const [text, setText] = useState('');
  const [busy, setBusy] = useState(false);
  const parsed = useMemo(() => analyze(text), [text]);

  const importIt = async () => {
    if (!parsed || !parsed.ok) return;
    setBusy(true);
    try {
      const r = await api.adminImportTrack(parsed.data);
      onImported(r.slug, { modules: r.modules, topics: r.topics });
    } catch (e) {
      onError(e instanceof Error ? e.message : 'Import failed.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <Card>
      <CardContent>
        <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
          <Typography variant="h6">Import a track from JSON</Typography>
          <Button size="small" onClick={() => setText(JSON.stringify(EXAMPLE, null, 2))}>Load example</Button>
        </Stack>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Paste a track as JSON — <code>title</code> + <code>modules[]</code> (each with <code>topics[]</code>,
          each topic optionally with <code>resources[]</code> of <code>{'{ kind, title, url }'}</code>).
          Importing replaces this track's content.
        </Typography>

        <TextField
          value={text}
          onChange={(e) => setText(e.target.value)}
          placeholder='{ "title": "Node.js Developer", "modules": [ … ] }'
          multiline
          minRows={12}
          fullWidth
          slotProps={{ htmlInput: { style: { fontFamily: 'ui-monospace, SFMono-Regular, Menlo, monospace', fontSize: 13 } } }}
        />

        {parsed && !parsed.ok && <Alert severity="error" sx={{ mt: 2 }}>{parsed.error}</Alert>}
        {parsed && parsed.ok && (
          <Box sx={{ mt: 2 }}>
            <Alert severity="success" sx={{ mb: 1.5 }}>Looks valid — ready to import.</Alert>
            <Stack direction="row" spacing={1} sx={{ flexWrap: 'wrap', gap: 0.75, mb: 1.5 }}>
              <Chip label={`${parsed.data.icon ?? '📚'} ${parsed.data.title}`} />
              <Chip variant="outlined" label={`${parsed.modules} modules`} />
              <Chip variant="outlined" label={`${parsed.topics} concepts`} />
              <Chip variant="outlined" label={`${parsed.links} links`} />
              <Chip variant="outlined" color={parsed.data.status === 'published' ? 'success' : 'default'} label={parsed.data.status ?? 'draft'} />
            </Stack>
            <Divider textAlign="left" sx={{ mb: 1 }}>Preview</Divider>
            <Stack spacing={0.5} sx={{ maxHeight: 220, overflowY: 'auto' }}>
              {parsed.data.modules.map((m: any, i: number) => (
                <Box key={i}>
                  <Typography variant="body2" sx={{ fontWeight: 700 }}>{i + 1}. {m.title} <Typography component="span" variant="caption" color="text.secondary">· {(m.topics ?? []).length} concepts</Typography></Typography>
                  <Stack sx={{ pl: 2 }}>
                    {(m.topics ?? []).slice(0, 6).map((t: any, j: number) => (
                      <Typography key={j} variant="caption" color="text.secondary">• {t.title} {t.est_hours ? `(${t.est_hours}h)` : ''}</Typography>
                    ))}
                    {(m.topics ?? []).length > 6 && <Typography variant="caption" color="text.secondary">…and {(m.topics ?? []).length - 6} more</Typography>}
                  </Stack>
                </Box>
              ))}
            </Stack>
          </Box>
        )}

        <Box sx={{ mt: 2 }}>
          <Button variant="contained" disabled={busy || !parsed || !parsed.ok} onClick={() => void importIt()}>
            {busy ? 'Importing…' : 'Import track'}
          </Button>
        </Box>
      </CardContent>
    </Card>
  );
}

import { useEffect, useState, type ReactElement } from 'react';
import {
  Box,
  Button,
  Chip,
  Divider,
  Drawer,
  IconButton,
  Link,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import CloseIcon from '@mui/icons-material/Close';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import RadioButtonUncheckedIcon from '@mui/icons-material/RadioButtonUnchecked';
import OpenInNewIcon from '@mui/icons-material/OpenInNew';
import MenuBookIcon from '@mui/icons-material/MenuBook';
import DescriptionIcon from '@mui/icons-material/Description';
import OndemandVideoIcon from '@mui/icons-material/OndemandVideo';
import CodeIcon from '@mui/icons-material/Code';
import GitHubIcon from '@mui/icons-material/GitHub';
import SchoolIcon from '@mui/icons-material/School';
import type { Topic } from '../lib/api';

const KIND: Record<string, { label: string; icon: ReactElement; color: string }> = {
  doc: { label: 'Documentation', icon: <MenuBookIcon fontSize="small" />, color: '#6366f1' },
  article: { label: 'Article', icon: <DescriptionIcon fontSize="small" />, color: '#0ea5e9' },
  video: { label: 'Video', icon: <OndemandVideoIcon fontSize="small" />, color: '#ef4444' },
  practice: { label: 'Practice', icon: <CodeIcon fontSize="small" />, color: '#22c55e' },
  repo: { label: 'Repository', icon: <GitHubIcon fontSize="small" />, color: '#64748b' },
  course: { label: 'Course', icon: <SchoolIcon fontSize="small" />, color: '#f59e0b' },
};

export default function TopicDrawer({
  topic, moduleTitle, index, done, note, canTrack, onClose, onToggle, onSaveNote,
}: {
  topic: Topic | null;
  moduleTitle: string;
  index: number | null;
  done: boolean;
  note: string;
  canTrack: boolean;
  onClose: () => void;
  onToggle: () => void;
  onSaveNote: (v: string) => void;
}) {
  const [draft, setDraft] = useState(note);
  const [dirty, setDirty] = useState(false);
  const [saved, setSaved] = useState(false);

  useEffect(() => { setDraft(note); setDirty(false); }, [note, topic?.id]);

  const commit = () => {
    if (!dirty) return;
    onSaveNote(draft);
    setDirty(false);
    setSaved(true);
    window.setTimeout(() => setSaved(false), 1500);
  };

  return (
    <Drawer
      anchor="right"
      open={Boolean(topic)}
      onClose={onClose}
      slotProps={{ paper: { sx: { width: { xs: '100%', sm: 440 }, p: 0 } } }}
    >
      {topic && (
        <Box sx={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
          <Box sx={{ p: 2.5, borderBottom: 1, borderColor: 'divider' }}>
            <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <Typography variant="overline" color="primary">
                {index != null ? `Step ${index} · ` : ''}{moduleTitle}
              </Typography>
              <IconButton size="small" onClick={onClose}><CloseIcon fontSize="small" /></IconButton>
            </Stack>
            <Typography variant="h5" sx={{ mt: 0.5 }}>{topic.title}</Typography>
            <Stack direction="row" spacing={1} sx={{ mt: 1.5, alignItems: 'center' }}>
              <Chip size="small" variant="outlined" label={`~${topic.est_hours} hours`} />
              {canTrack ? (
                <Button
                  size="small"
                  variant={done ? 'outlined' : 'contained'}
                  color={done ? 'success' : 'primary'}
                  startIcon={done ? <CheckCircleIcon /> : <RadioButtonUncheckedIcon />}
                  onClick={onToggle}
                >
                  {done ? 'Completed' : 'Mark complete'}
                </Button>
              ) : (
                <Button size="small" variant="contained" href="#login">Sign in to track</Button>
              )}
            </Stack>
          </Box>

          <Box sx={{ p: 2.5, overflowY: 'auto', flexGrow: 1 }}>
            <Typography variant="subtitle2" sx={{ mb: 0.5 }}>What you'll learn</Typography>
            <Typography variant="body2" color="text.secondary">{topic.description || 'No description yet.'}</Typography>

            {topic.resources.length > 0 && (
              <>
                <Typography variant="subtitle2" sx={{ mt: 3, mb: 1 }}>Reference materials</Typography>
                <Stack spacing={1}>
                  {topic.resources.map((r) => {
                    const meta = KIND[r.kind] ?? KIND.doc;
                    return (
                      <Link
                        key={r.url}
                        href={r.url}
                        target="_blank"
                        rel="noopener noreferrer"
                        underline="none"
                        sx={{
                          display: 'flex', alignItems: 'center', gap: 1.25, p: 1.25, borderRadius: 2,
                          border: 1, borderColor: 'divider', color: 'text.primary',
                          transition: 'all .15s',
                          '&:hover': { borderColor: meta.color, bgcolor: `${meta.color}0d` },
                        }}
                      >
                        <Box sx={{ color: meta.color, display: 'flex' }}>{meta.icon}</Box>
                        <Box sx={{ flexGrow: 1, minWidth: 0 }}>
                          <Typography variant="body2" sx={{ fontWeight: 600 }} noWrap>{r.title}</Typography>
                          <Typography variant="caption" sx={{ color: meta.color }}>{meta.label}</Typography>
                        </Box>
                        <OpenInNewIcon sx={{ fontSize: 16, color: 'text.secondary' }} />
                      </Link>
                    );
                  })}
                </Stack>
              </>
            )}

            {canTrack && (
              <>
                <Stack direction="row" spacing={1} sx={{ mt: 3, mb: 1, alignItems: 'center' }}>
                  <Typography variant="subtitle2">My notes</Typography>
                  {saved && <Typography variant="caption" color="success.main">Saved ✓</Typography>}
                </Stack>
                <TextField
                  value={draft}
                  onChange={(e) => { setDraft(e.target.value); setDirty(true); }}
                  onBlur={commit}
                  placeholder="Jot down what you learned… (saved when you click away)"
                  multiline
                  minRows={4}
                  fullWidth
                  size="small"
                />
              </>
            )}
          </Box>
        </Box>
      )}
    </Drawer>
  );
}

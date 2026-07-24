import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  Divider,
  Grid,
  IconButton,
  MenuItem,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Tooltip,
  Typography,
} from '@mui/material';
import AddIcon from '@mui/icons-material/Add';
import EditIcon from '@mui/icons-material/Edit';
import DeleteOutlineIcon from '@mui/icons-material/DeleteOutlined';
import PublishIcon from '@mui/icons-material/Publish';
import UnpublishedIcon from '@mui/icons-material/UnpublishedOutlined';
import { emptyDay, emptyProject, useDashboardStore, useIsAdmin } from '../store';
import { linesToList, listToLines } from '../plannerExport';
import type { PlanStatus } from '../lib/mappers';
import type { PlannerDay } from '../types';
import PageHeader from '../components/PageHeader';

type Feedback = { severity: 'success' | 'error'; message: string } | null;

export default function AdminPage() {
  const isAdmin = useIsAdmin();
  const {
    supabaseEnabled,
    authReady,
    months,
    adminSaveMonth,
    adminSaveDay,
    adminSetMonthStatus,
    adminSetDayStatus,
    adminDeleteDay,
    adminDeleteMonth,
  } = useDashboardStore();

  const [feedback, setFeedback] = useState<Feedback>(null);
  const [selectedMonth, setSelectedMonth] = useState<number | 'new'>(months[0]?.month ?? 'new');

  // month form
  const [mNumber, setMNumber] = useState('');
  const [mTitle, setMTitle] = useState('');
  const [mGoal, setMGoal] = useState('');
  const [mStatus, setMStatus] = useState<PlanStatus>('draft');
  const [pName, setPName] = useState('');
  const [pPrd, setPPrd] = useState('');
  const [pArch, setPArch] = useState('');
  const [pTech, setPTech] = useState('');
  const [pTasks, setPTasks] = useState('');
  const [pGithub, setPGithub] = useState('');

  const activeMonth = useMemo(
    () => (selectedMonth === 'new' ? null : months.find((m) => m.month === selectedMonth) ?? null),
    [months, selectedMonth],
  );

  // Load the selected month into the form.
  useEffect(() => {
    if (!activeMonth) {
      const next = months.length ? Math.max(...months.map((m) => m.month)) + 1 : 1;
      setMNumber(String(next));
      setMTitle('');
      setMGoal('');
      setMStatus('draft');
      setPName('');
      setPPrd('');
      setPArch('');
      setPTech('');
      setPTasks('');
      setPGithub('');
      return;
    }
    setMNumber(String(activeMonth.month));
    setMTitle(activeMonth.title);
    setMGoal(activeMonth.goal);
    setPName(activeMonth.project.name);
    setPPrd(activeMonth.project.prd);
    setPArch(activeMonth.project.architecture);
    setPTech(listToLines(activeMonth.project.techStack));
    setPTasks(listToLines(activeMonth.project.tasks));
    setPGithub(activeMonth.project.githubUrl);
  }, [activeMonth, months]);

  if (!supabaseEnabled) {
    return (
      <Box>
        <PageHeader overline="Admin" title="Admin panel needs Supabase" />
        <Alert severity="info">Configure Supabase in <code>app/.env.local</code> to manage plans in the cloud.</Alert>
      </Box>
    );
  }
  if (!authReady) {
    return (
      <Box>
        <PageHeader overline="Admin" title="Loading…" />
      </Box>
    );
  }
  if (!isAdmin) {
    return (
      <Box>
        <PageHeader overline="Admin" title="Admins only" subtitle="Your account doesn't have admin access." />
        <Alert severity="warning">
          Ask an existing admin to grant access, or run the promote-to-admin SQL for your email.
        </Alert>
      </Box>
    );
  }

  const saveMonth = async () => {
    const month_number = Number.parseInt(mNumber, 10);
    if (!Number.isInteger(month_number) || !mTitle.trim()) {
      setFeedback({ severity: 'error', message: 'Month number and title are required.' });
      return;
    }
    const { error } = await adminSaveMonth({
      month_number,
      title: mTitle.trim(),
      goal: mGoal.trim(),
      status: mStatus,
      project: {
        ...emptyProject(),
        name: pName.trim(),
        prd: pPrd.trim(),
        architecture: pArch.trim(),
        techStack: linesToList(pTech.replace(/,/g, '\n')),
        tasks: linesToList(pTasks),
        githubUrl: pGithub.trim(),
      },
    });
    if (error) setFeedback({ severity: 'error', message: error });
    else {
      setFeedback({ severity: 'success', message: `Saved Month ${month_number}.` });
      setSelectedMonth(month_number);
    }
  };

  return (
    <Box>
      <PageHeader
        overline="Admin"
        title="Manage the learning plan"
        subtitle="Create and edit months and days, then publish them. Published content appears in the learner Planner; drafts are visible only to admins."
      />

      {feedback && (
        <Alert severity={feedback.severity} sx={{ mb: 2 }} onClose={() => setFeedback(null)}>
          {feedback.message}
        </Alert>
      )}

      <Stack direction="row" spacing={1} sx={{ mb: 3, flexWrap: 'wrap', gap: 1 }}>
        {months.map((m) => (
          <Chip
            key={m.month}
            label={`M${m.month} · ${m.title}`}
            onClick={() => setSelectedMonth(m.month)}
            color={selectedMonth === m.month ? 'primary' : 'default'}
            variant={selectedMonth === m.month ? 'filled' : 'outlined'}
          />
        ))}
        <Chip
          icon={<AddIcon />}
          label="New month"
          onClick={() => setSelectedMonth('new')}
          color={selectedMonth === 'new' ? 'primary' : 'default'}
          variant={selectedMonth === 'new' ? 'filled' : 'outlined'}
        />
      </Stack>

      <Grid container spacing={2.5}>
        {/* Month editor */}
        <Grid size={{ xs: 12, md: 5 }}>
          <Card>
            <CardContent>
              <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
                <Typography variant="h6">{activeMonth ? `Edit Month ${activeMonth.month}` : 'New month'}</Typography>
                {activeMonth && (
                  <Chip
                    size="small"
                    label={activeMonth === null ? 'draft' : mStatus}
                    color={mStatus === 'published' ? 'success' : 'default'}
                  />
                )}
              </Stack>
              <Stack spacing={2}>
                <Stack direction="row" spacing={2}>
                  <TextField label="Month #" type="number" value={mNumber} onChange={(e) => setMNumber(e.target.value)} sx={{ width: 120 }} disabled={Boolean(activeMonth)} />
                  <TextField label="Title" value={mTitle} onChange={(e) => setMTitle(e.target.value)} fullWidth />
                </Stack>
                <TextField label="Goal" value={mGoal} onChange={(e) => setMGoal(e.target.value)} fullWidth multiline minRows={2} />
                <TextField select label="Status" value={mStatus} onChange={(e) => setMStatus(e.target.value as PlanStatus)}>
                  <MenuItem value="draft">Draft</MenuItem>
                  <MenuItem value="published">Published</MenuItem>
                </TextField>
                <Divider textAlign="left">Monthly project</Divider>
                <TextField label="Project name" value={pName} onChange={(e) => setPName(e.target.value)} fullWidth />
                <TextField label="PRD" value={pPrd} onChange={(e) => setPPrd(e.target.value)} fullWidth multiline minRows={2} />
                <TextField label="Architecture" value={pArch} onChange={(e) => setPArch(e.target.value)} fullWidth multiline minRows={2} />
                <TextField label="Tech stack" helperText="One per line (or comma-separated)" value={pTech} onChange={(e) => setPTech(e.target.value)} fullWidth multiline minRows={2} />
                <TextField label="Project tasks" helperText="One per line" value={pTasks} onChange={(e) => setPTasks(e.target.value)} fullWidth multiline minRows={2} />
                <TextField label="GitHub URL" value={pGithub} onChange={(e) => setPGithub(e.target.value)} fullWidth />
                <Stack direction="row" spacing={1}>
                  <Button variant="contained" onClick={() => void saveMonth()}>
                    {activeMonth ? 'Save month' : 'Create month'}
                  </Button>
                  {activeMonth && (
                    <Button
                      color="error"
                      onClick={() => {
                        if (window.confirm(`Delete Month ${activeMonth.month} and all its days?`)) {
                          void adminDeleteMonth(activeMonth.month);
                          setSelectedMonth('new');
                        }
                      }}
                    >
                      Delete
                    </Button>
                  )}
                </Stack>
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        {/* Days table */}
        <Grid size={{ xs: 12, md: 7 }}>
          <DaysManager
            monthNumber={activeMonth?.month ?? null}
            days={activeMonth?.days ?? []}
            onSetStatus={(dayNumber, status) => void adminSetDayStatus(dayNumber, status)}
            onDelete={(dayNumber) => void adminDeleteDay(dayNumber)}
            onSave={async (day, status) => {
              if (activeMonth == null) return { error: 'Create the month first.' };
              const res = await adminSaveDay(activeMonth.month, day, status);
              if (res.error) setFeedback({ severity: 'error', message: res.error });
              else setFeedback({ severity: 'success', message: `Saved Day ${day.day}.` });
              return res;
            }}
          />
          {activeMonth && (
            <Button
              sx={{ mt: 2 }}
              variant="outlined"
              startIcon={mStatus === 'published' ? <UnpublishedIcon /> : <PublishIcon />}
              onClick={() => {
                const next: PlanStatus = mStatus === 'published' ? 'draft' : 'published';
                setMStatus(next);
                void adminSetMonthStatus(activeMonth.month, next);
              }}
            >
              {mStatus === 'published' ? 'Unpublish month' : 'Publish month'}
            </Button>
          )}
        </Grid>
      </Grid>
    </Box>
  );
}

function DaysManager({
  monthNumber,
  days,
  onSave,
  onSetStatus,
  onDelete,
}: {
  monthNumber: number | null;
  days: PlannerDay[];
  onSave: (day: PlannerDay, status: PlanStatus) => Promise<{ error: string | null }>;
  onSetStatus: (dayNumber: number, status: PlanStatus) => void;
  onDelete: (dayNumber: number) => void;
}) {
  const [open, setOpen] = useState(false);
  const [editing, setEditing] = useState<PlannerDay | null>(null);
  const [status, setStatus] = useState<PlanStatus>('published');
  // publish state per day isn't in the model; we track only via toggle actions.

  const [f, setF] = useState(emptyDay(1));
  const [videos, setVideos] = useState('');
  const [docs, setDocs] = useState('');
  const [reading, setReading] = useState('');
  const [practice, setPractice] = useState('');
  const [tasks, setTasks] = useState('');
  const [interview, setInterview] = useState('');

  const openEditor = (day: PlannerDay | null) => {
    const base = day ?? emptyDay(days.length ? Math.max(...days.map((d) => d.day)) + 1 : (monthNumber ?? 1) * 30 - 29);
    setEditing(day);
    setF(base);
    setVideos(listToLines(base.videos));
    setDocs(listToLines(base.docs));
    setReading(listToLines(base.reading));
    setPractice(listToLines(base.practice));
    setTasks(listToLines(base.tasks));
    setInterview(listToLines(base.interviewQuestions));
    setStatus('published');
    setOpen(true);
  };

  const save = async () => {
    const day: PlannerDay = {
      ...f,
      videos: linesToList(videos),
      docs: linesToList(docs),
      reading: linesToList(reading),
      practice: linesToList(practice),
      tasks: linesToList(tasks),
      interviewQuestions: linesToList(interview),
    };
    const { error } = await onSave(day, status);
    if (!error) setOpen(false);
  };

  return (
    <Card>
      <CardContent>
        <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
          <Typography variant="h6">Days {monthNumber ? `· Month ${monthNumber}` : ''}</Typography>
          <Button size="small" variant="contained" startIcon={<AddIcon />} disabled={monthNumber == null} onClick={() => openEditor(null)}>
            Add day
          </Button>
        </Stack>
        {monthNumber == null ? (
          <Typography variant="body2" color="text.secondary">
            Create the month first, then add days.
          </Typography>
        ) : days.length === 0 ? (
          <Typography variant="body2" color="text.secondary">
            No days yet. Add the first one.
          </Typography>
        ) : (
          <Box sx={{ maxHeight: 480, overflowY: 'auto' }}>
            <Table size="small" stickyHeader>
              <TableHead>
                <TableRow>
                  <TableCell>#</TableCell>
                  <TableCell>Title</TableCell>
                  <TableCell align="right">Actions</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {days.map((day) => (
                  <TableRow key={day.day} hover>
                    <TableCell>{day.day}</TableCell>
                    <TableCell>{day.title}</TableCell>
                    <TableCell align="right">
                      <Tooltip title="Edit">
                        <IconButton size="small" onClick={() => openEditor(day)}>
                          <EditIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Publish">
                        <IconButton size="small" onClick={() => onSetStatus(day.day, 'published')}>
                          <PublishIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Unpublish (draft)">
                        <IconButton size="small" onClick={() => onSetStatus(day.day, 'draft')}>
                          <UnpublishedIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                      <Tooltip title="Delete">
                        <IconButton size="small" color="error" onClick={() => { if (window.confirm(`Delete Day ${day.day}?`)) onDelete(day.day); }}>
                          <DeleteOutlineIcon fontSize="small" />
                        </IconButton>
                      </Tooltip>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </Box>
        )}
      </CardContent>

      <Dialog open={open} onClose={() => setOpen(false)} maxWidth="md" fullWidth>
        <DialogTitle>{editing ? `Edit Day ${editing.day}` : 'New day'}</DialogTitle>
        <DialogContent dividers>
          <Stack spacing={2} sx={{ mt: 0.5 }}>
            <Stack direction="row" spacing={2}>
              <TextField label="Day #" type="number" value={f.day} onChange={(e) => setF({ ...f, day: Number(e.target.value) })} sx={{ width: 120 }} disabled={Boolean(editing)} />
              <TextField label="Duration" value={f.duration} onChange={(e) => setF({ ...f, duration: e.target.value })} sx={{ width: 140 }} />
              <TextField select label="Status" value={status} onChange={(e) => setStatus(e.target.value as PlanStatus)} sx={{ width: 160 }}>
                <MenuItem value="draft">Draft</MenuItem>
                <MenuItem value="published">Published</MenuItem>
              </TextField>
            </Stack>
            <TextField label="Title" value={f.title} onChange={(e) => setF({ ...f, title: e.target.value })} fullWidth />
            <TextField label="Learning objective" value={f.learningObjective} onChange={(e) => setF({ ...f, learningObjective: e.target.value })} fullWidth multiline minRows={2} />
            <Grid container spacing={2}>
              <Grid size={{ xs: 12, md: 6 }}><TextField label="Practice" helperText="One per line" value={practice} onChange={(e) => setPractice(e.target.value)} fullWidth multiline minRows={3} /></Grid>
              <Grid size={{ xs: 12, md: 6 }}><TextField label="Tasks" helperText="One per line" value={tasks} onChange={(e) => setTasks(e.target.value)} fullWidth multiline minRows={3} /></Grid>
              <Grid size={{ xs: 12, md: 6 }}><TextField label="Videos" helperText="One per line" value={videos} onChange={(e) => setVideos(e.target.value)} fullWidth multiline minRows={3} /></Grid>
              <Grid size={{ xs: 12, md: 6 }}><TextField label="Docs" helperText="One per line" value={docs} onChange={(e) => setDocs(e.target.value)} fullWidth multiline minRows={3} /></Grid>
              <Grid size={{ xs: 12, md: 6 }}><TextField label="Reading" helperText="One per line" value={reading} onChange={(e) => setReading(e.target.value)} fullWidth multiline minRows={3} /></Grid>
              <Grid size={{ xs: 12, md: 6 }}><TextField label="Interview questions" helperText="One per line" value={interview} onChange={(e) => setInterview(e.target.value)} fullWidth multiline minRows={3} /></Grid>
            </Grid>
            <TextField label="Mini project" value={f.miniProject} onChange={(e) => setF({ ...f, miniProject: e.target.value })} fullWidth multiline minRows={2} />
          </Stack>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpen(false)}>Cancel</Button>
          <Button variant="contained" onClick={() => void save()}>Save day</Button>
        </DialogActions>
      </Dialog>
    </Card>
  );
}

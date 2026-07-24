import { useRef, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Divider,
  Grid,
  Stack,
  TextField,
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material';
import DownloadIcon from '@mui/icons-material/Download';
import UploadFileIcon from '@mui/icons-material/UploadFile';
import { emptyDay, emptyProject, useDashboardStore } from '../store';
import { downloadMonth, linesToList, monthFileName, parseMonthFile } from '../plannerExport';
import type { PlannerDay, PlannerMonth } from '../types';
import PageHeader from '../components/PageHeader';

type Feedback = { severity: 'success' | 'error'; message: string } | null;

const helper = 'One item per line';

export default function PlannerEditorPage() {
  const { months, addDay, addMonth, resetCustomData, supabaseEnabled } = useDashboardStore();

  // When Supabase is configured, all content lives in the database and is
  // authored through the Admin panel (which writes via the Node API). This
  // local JSON editor writes only to the browser, so it is disabled to keep a
  // single, database-backed source of truth.
  if (supabaseEnabled) {
    return (
      <Box>
        <PageHeader
          overline="Add Entry"
          title="Content is managed in the Admin panel"
          subtitle="This project is backed by the Supabase database."
        />
        <Alert severity="info">
          Months and days are stored in the database and edited from the{' '}
          <strong>Admin</strong> panel (admins only), which saves through the Node API.
          The local JSON editor is disabled so there is a single source of truth.
        </Alert>
      </Box>
    );
  }
  const [mode, setMode] = useState<'day' | 'month'>('day');
  const [feedback, setFeedback] = useState<Feedback>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  // Add-day form state
  const [dayMonth, setDayMonth] = useState('1');
  const [dayNumber, setDayNumber] = useState('');
  const [title, setTitle] = useState('');
  const [duration, setDuration] = useState('2h');
  const [objective, setObjective] = useState('');
  const [videos, setVideos] = useState('');
  const [docs, setDocs] = useState('');
  const [reading, setReading] = useState('');
  const [practice, setPractice] = useState('');
  const [tasks, setTasks] = useState('');
  const [miniProject, setMiniProject] = useState('');
  const [interview, setInterview] = useState('');

  // Add-month form state
  const [newMonthNumber, setNewMonthNumber] = useState('');
  const [monthTitle, setMonthTitle] = useState('');
  const [monthGoal, setMonthGoal] = useState('');
  const [projectName, setProjectName] = useState('');
  const [projectPrd, setProjectPrd] = useState('');
  const [projectArchitecture, setProjectArchitecture] = useState('');
  const [projectTech, setProjectTech] = useState('');

  const resetDayForm = () => {
    setDayNumber('');
    setTitle('');
    setDuration('2h');
    setObjective('');
    setVideos('');
    setDocs('');
    setReading('');
    setPractice('');
    setTasks('');
    setMiniProject('');
    setInterview('');
  };

  const handleAddDay = () => {
    const month = Number.parseInt(dayMonth, 10);
    const day = Number.parseInt(dayNumber, 10);
    if (!Number.isInteger(month) || !Number.isInteger(day) || !title.trim()) {
      setFeedback({ severity: 'error', message: 'Month, day number, and title are required.' });
      return;
    }
    const entry: PlannerDay = {
      ...emptyDay(day),
      title: title.trim(),
      duration: duration.trim() || '2h',
      learningObjective: objective.trim(),
      videos: linesToList(videos),
      docs: linesToList(docs),
      reading: linesToList(reading),
      practice: linesToList(practice),
      tasks: linesToList(tasks),
      miniProject: miniProject.trim(),
      interviewQuestions: linesToList(interview),
    };
    addDay(month, entry);
    resetDayForm();
    setFeedback({ severity: 'success', message: `Added Day ${day} to Month ${month}. Export ${monthFileName(month)} below to commit it.` });
  };

  const handleAddMonth = () => {
    const month = Number.parseInt(newMonthNumber, 10);
    if (!Number.isInteger(month) || !monthTitle.trim()) {
      setFeedback({ severity: 'error', message: 'Month number and title are required.' });
      return;
    }
    if (months.some((m) => m.month === month)) {
      setFeedback({ severity: 'error', message: `Month ${month} already exists. Add days to it instead.` });
      return;
    }
    const entry: PlannerMonth = {
      month,
      title: monthTitle.trim(),
      goal: monthGoal.trim(),
      project: {
        ...emptyProject(),
        name: projectName.trim(),
        prd: projectPrd.trim(),
        architecture: projectArchitecture.trim(),
        techStack: linesToList(projectTech.replace(/,/g, '\n')),
      },
      days: [],
    };
    addMonth(entry);
    setNewMonthNumber('');
    setMonthTitle('');
    setMonthGoal('');
    setProjectName('');
    setProjectPrd('');
    setProjectArchitecture('');
    setProjectTech('');
    setDayMonth(String(month));
    setFeedback({ severity: 'success', message: `Added Month ${month}. Now add its days, then export the JSON.` });
  };

  const handleImport = async (file: File) => {
    try {
      const month = parseMonthFile(await file.text());
      addMonth(month);
      setFeedback({ severity: 'success', message: `Imported Month ${month.month} (${month.days.length} days) from ${file.name}.` });
    } catch (error) {
      setFeedback({ severity: 'error', message: error instanceof Error ? error.message : 'Could not import file.' });
    }
  };

  return (
    <Box>
      <PageHeader
        overline="Add Entry"
        title="Build the planner from the UI"
        subtitle="Add days and months here — they persist in your browser. Export the JSON and commit it under /planner to push it into the repo."
      />

      {feedback && (
        <Alert severity={feedback.severity} sx={{ mb: 2 }} onClose={() => setFeedback(null)}>
          {feedback.message}
        </Alert>
      )}

      <ToggleButtonGroup
        exclusive
        value={mode}
        onChange={(_, next) => next && setMode(next)}
        sx={{ mb: 2 }}
      >
        <ToggleButton value="day">Add a day</ToggleButton>
        <ToggleButton value="month">Add a month</ToggleButton>
      </ToggleButtonGroup>

      <Grid container spacing={2}>
        <Grid size={{ xs: 12, md: 7 }}>
          <Card className="soft-card">
            <CardContent>
              {mode === 'day' ? (
                <Stack spacing={2}>
                  <Typography variant="h6">New planner day</Typography>
                  <Stack direction="row" spacing={2}>
                    <TextField label="Month" type="number" value={dayMonth} onChange={(e) => setDayMonth(e.target.value)} fullWidth />
                    <TextField label="Day number" type="number" value={dayNumber} onChange={(e) => setDayNumber(e.target.value)} fullWidth />
                    <TextField label="Duration" value={duration} onChange={(e) => setDuration(e.target.value)} fullWidth />
                  </Stack>
                  <TextField label="Title" value={title} onChange={(e) => setTitle(e.target.value)} fullWidth />
                  <TextField label="Learning objective" value={objective} onChange={(e) => setObjective(e.target.value)} fullWidth multiline minRows={2} />
                  <Grid container spacing={2}>
                    <Grid size={{ xs: 12, md: 6 }}><TextField label="Videos" helperText={helper} value={videos} onChange={(e) => setVideos(e.target.value)} fullWidth multiline minRows={3} /></Grid>
                    <Grid size={{ xs: 12, md: 6 }}><TextField label="Docs" helperText={helper} value={docs} onChange={(e) => setDocs(e.target.value)} fullWidth multiline minRows={3} /></Grid>
                    <Grid size={{ xs: 12, md: 6 }}><TextField label="Reading" helperText={helper} value={reading} onChange={(e) => setReading(e.target.value)} fullWidth multiline minRows={3} /></Grid>
                    <Grid size={{ xs: 12, md: 6 }}><TextField label="Practice" helperText={helper} value={practice} onChange={(e) => setPractice(e.target.value)} fullWidth multiline minRows={3} /></Grid>
                    <Grid size={{ xs: 12, md: 6 }}><TextField label="Checklist tasks" helperText={helper} value={tasks} onChange={(e) => setTasks(e.target.value)} fullWidth multiline minRows={3} /></Grid>
                    <Grid size={{ xs: 12, md: 6 }}><TextField label="Interview questions" helperText={helper} value={interview} onChange={(e) => setInterview(e.target.value)} fullWidth multiline minRows={3} /></Grid>
                  </Grid>
                  <TextField label="Mini project" value={miniProject} onChange={(e) => setMiniProject(e.target.value)} fullWidth multiline minRows={2} />
                  <Box><Button variant="contained" onClick={handleAddDay}>Add day</Button></Box>
                </Stack>
              ) : (
                <Stack spacing={2}>
                  <Typography variant="h6">New month</Typography>
                  <Stack direction="row" spacing={2}>
                    <TextField label="Month number" type="number" value={newMonthNumber} onChange={(e) => setNewMonthNumber(e.target.value)} fullWidth />
                    <TextField label="Title" value={monthTitle} onChange={(e) => setMonthTitle(e.target.value)} fullWidth />
                  </Stack>
                  <TextField label="Goal" value={monthGoal} onChange={(e) => setMonthGoal(e.target.value)} fullWidth multiline minRows={2} />
                  <Divider textAlign="left">Monthly project</Divider>
                  <TextField label="Project name" value={projectName} onChange={(e) => setProjectName(e.target.value)} fullWidth />
                  <TextField label="PRD" value={projectPrd} onChange={(e) => setProjectPrd(e.target.value)} fullWidth multiline minRows={2} />
                  <TextField label="Architecture" value={projectArchitecture} onChange={(e) => setProjectArchitecture(e.target.value)} fullWidth multiline minRows={2} />
                  <TextField label="Tech stack" helperText="Comma or newline separated" value={projectTech} onChange={(e) => setProjectTech(e.target.value)} fullWidth multiline minRows={2} />
                  <Box><Button variant="contained" onClick={handleAddMonth}>Add month</Button></Box>
                </Stack>
              )}
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, md: 5 }}>
          <Card className="soft-card">
            <CardContent>
              <Typography variant="h6">Export &amp; sync</Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                Download each month and drop it into <code>/planner</code>, then commit — e.g. <code>feat(day-004): add PostgreSQL indexing plan</code>.
              </Typography>
              <Stack spacing={1}>
                {months.map((month) => (
                  <Button
                    key={month.month}
                    variant="outlined"
                    startIcon={<DownloadIcon />}
                    onClick={() => downloadMonth(month)}
                    sx={{ justifyContent: 'flex-start' }}
                  >
                    {monthFileName(month.month)} · {month.days.length} days
                  </Button>
                ))}
              </Stack>
              <Divider sx={{ my: 2 }} />
              <Button variant="outlined" startIcon={<UploadFileIcon />} onClick={() => fileRef.current?.click()} fullWidth>
                Import a month JSON
              </Button>
              <input
                ref={fileRef}
                type="file"
                accept="application/json,.json"
                hidden
                onChange={(event) => {
                  const file = event.target.files?.[0];
                  if (file) void handleImport(file);
                  event.target.value = '';
                }}
              />
              <Divider sx={{ my: 2 }} />
              <Button
                color="error"
                onClick={() => {
                  if (window.confirm('Reset all UI-added months, days, notes, and completion state?')) {
                    resetCustomData();
                    setFeedback({ severity: 'success', message: 'Cleared local changes. Repo JSON is unchanged.' });
                  }
                }}
                fullWidth
              >
                Reset local changes
              </Button>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}

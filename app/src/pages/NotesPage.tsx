import { Box, Card, CardContent, Grid, MenuItem, Stack, TextField, Typography } from '@mui/material';
import ReactMarkdown from 'react-markdown';
import { useDashboardStore } from '../store';
import PageHeader from '../components/PageHeader';

export default function NotesPage() {
  const { selectedDay, setSelectedDay, notesByDay, saveNote, days: plannerDays } = useDashboardStore();
  const day = plannerDays.find((entry) => entry.day === selectedDay) ?? plannerDays[0];
  const note = day ? notesByDay[day.day] ?? '' : '';

  if (!day) {
    return (
      <Box>
        <PageHeader overline="Notes" title="No days to take notes on yet" subtitle="Add planner days first." />
      </Box>
    );
  }

  return (
    <Box>
      <PageHeader
        overline="Notes"
        title="Markdown notes for each day"
        subtitle="Capture what you learned. Notes are saved in your browser and keyed to each study day."
        action={
          <TextField
            select
            size="small"
            label="Day"
            value={day.day}
            onChange={(e) => setSelectedDay(Number(e.target.value))}
            sx={{ minWidth: 240 }}
          >
            {plannerDays.map((entry) => (
              <MenuItem key={entry.day} value={entry.day}>
                Day {entry.day}: {entry.title}
              </MenuItem>
            ))}
          </TextField>
        }
      />
      <Grid container spacing={2.5}>
        <Grid size={{ xs: 12, md: 6 }}>
          <TextField
            label={`Day ${day.day} notes (Markdown)`}
            value={note}
            onChange={(event) => saveNote(day.day, event.target.value)}
            multiline
            minRows={16}
            fullWidth
          />
        </Grid>
        <Grid size={{ xs: 12, md: 6 }}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="overline" color="text.secondary">
                Preview
              </Typography>
              {note.trim() ? (
                <Box className="markdown-preview">
                  <ReactMarkdown>{note}</ReactMarkdown>
                </Box>
              ) : (
                <Stack sx={{ py: 6, alignItems: 'center' }}>
                  <Typography color="text.secondary">Start typing to see a live preview.</Typography>
                </Stack>
              )}
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}

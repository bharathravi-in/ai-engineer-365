import { Box, Card, CardContent, Grid, Stack, TextField, Typography } from '@mui/material';
import ReactMarkdown from 'react-markdown';
import { plannerDays } from '../plannerData';
import { useDashboardStore } from '../store';

export default function NotesPage() {
  const { selectedDay, notesByDay, saveNote } = useDashboardStore();
  const day = plannerDays.find((entry) => entry.day === selectedDay) ?? plannerDays[0];
  const note = notesByDay[day.day] ?? '';

  return (
    <Box id="notes" className="page-section">
      <Stack spacing={1} sx={{ mb: 3 }}><Typography variant="overline" color="primary">Notes</Typography><Typography variant="h4">Markdown editor for daily learning</Typography></Stack>
      <Grid container spacing={2}>
        <Grid item xs={12} md={6}><TextField label={`Day ${day.day} notes`} value={note} onChange={(event) => saveNote(day.day, event.target.value)} multiline minRows={12} fullWidth /></Grid>
        <Grid item xs={12} md={6}><Card className="soft-card markdown-preview"><CardContent><Typography variant="h6">Preview</Typography><ReactMarkdown>{note}</ReactMarkdown></CardContent></Card></Grid>
      </Grid>
    </Box>
  );
}

import { Box, Button, Card, CardContent, Chip, Grid, List, ListItem, Stack, Typography } from '@mui/material';
import { plannerDays } from '../plannerData';
import { useDashboardStore } from '../store';

function BulletList({ title, items }: { title: string; items: string[] }) {
  return (
    <Box>
      <Typography variant="subtitle2" sx={{ mb: 1 }}>{title}</Typography>
      <List dense>{items.map((item) => <ListItem key={item} sx={{ pl: 0 }}>• {item}</ListItem>)}</List>
    </Box>
  );
}

export default function PlannerPage() {
  const { completedDays, selectedDay, setSelectedDay, toggleDay } = useDashboardStore();
  const day = plannerDays.find((entry) => entry.day === selectedDay) ?? plannerDays[0];

  return (
    <Box id="planner" className="page-section">
      <Stack spacing={1} sx={{ mb: 3 }}>
        <Typography variant="overline" color="primary">Daily Planner</Typography>
        <Typography variant="h4">Render every study day from JSON</Typography>
      </Stack>
      <Grid container spacing={2}>
        <Grid item xs={12} md={4}>
          <Stack spacing={1}>
            {plannerDays.map((entry) => (
              <Button key={entry.day} variant={entry.day === selectedDay ? 'contained' : 'outlined'} onClick={() => setSelectedDay(entry.day)} sx={{ justifyContent: 'space-between' }}>
                Day {entry.day}: {entry.title} {completedDays.has(entry.day) ? '✓' : ''}
              </Button>
            ))}
          </Stack>
        </Grid>
        <Grid item xs={12} md={8}>
          <Card className="soft-card"><CardContent>
            <Stack direction="row" justifyContent="space-between" alignItems="center" gap={2} flexWrap="wrap">
              <Box>
                <Typography variant="h5">Day {day.day}: {day.title}</Typography>
                <Typography color="text.secondary">{day.learningObjective}</Typography>
              </Box>
              <Button variant={completedDays.has(day.day) ? 'outlined' : 'contained'} onClick={() => toggleDay(day.day)}>
                {completedDays.has(day.day) ? 'Mark incomplete' : 'Mark complete'}
              </Button>
            </Stack>
            <Stack direction="row" spacing={1} sx={{ my: 2 }} flexWrap="wrap">
              <Chip label={day.duration} color="primary" />
              <Chip label={completedDays.has(day.day) ? 'Completed' : 'In progress'} color={completedDays.has(day.day) ? 'success' : 'default'} />
            </Stack>
            <Grid container spacing={2}>
              <Grid item xs={12} md={6}><BulletList title="Videos" items={day.videos} /></Grid>
              <Grid item xs={12} md={6}><BulletList title="Official documentation" items={day.docs} /></Grid>
              <Grid item xs={12} md={6}><BulletList title="Reading" items={day.reading} /></Grid>
              <Grid item xs={12} md={6}><BulletList title="Coding exercises" items={day.practice} /></Grid>
              <Grid item xs={12} md={6}><BulletList title="Completion checklist" items={day.tasks} /></Grid>
              <Grid item xs={12} md={6}><BulletList title="Interview questions" items={day.interviewQuestions} /></Grid>
            </Grid>
            <Box className="mini-project"><Typography variant="subtitle2">Mini project</Typography><Typography>{day.miniProject}</Typography></Box>
          </CardContent></Card>
        </Grid>
      </Grid>
    </Box>
  );
}

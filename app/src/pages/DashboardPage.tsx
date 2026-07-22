import { Box, Card, CardContent, Grid, LinearProgress, Stack, Typography } from '@mui/material';
import { LineChart, Line, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { dashboardStats, plannerDays } from '../store';
import { useDashboardStore } from '../store';

const chartData = plannerDays.map((day, index) => ({ day: `D${day.day}`, hours: Number.parseFloat(day.duration), cumulative: index + 1 }));

function StatCard({ label, value, helper }: { label: string; value: string; helper: string }) {
  return (
    <Card className="soft-card">
      <CardContent>
        <Typography variant="body2" color="text.secondary">{label}</Typography>
        <Typography variant="h4" sx={{ mt: 1 }}>{value}</Typography>
        <Typography variant="body2" color="text.secondary">{helper}</Typography>
      </CardContent>
    </Card>
  );
}

export default function DashboardPage() {
  const completedDays = useDashboardStore((state) => state.completedDays);
  const currentDay = plannerDays.find((day) => !completedDays.has(day.day)) ?? plannerDays.at(-1)!;
  const progress = Math.round((completedDays.size / dashboardStats.totalDays) * 100);

  return (
    <Box id="dashboard" className="page-section">
      <Stack spacing={1} sx={{ mb: 3 }}>
        <Typography variant="overline" color="primary">Dashboard</Typography>
        <Typography variant="h4">Your AI engineering cockpit</Typography>
        <Typography color="text.secondary">Track study progress, current day, hours, projects, and future GitHub activity from one place.</Typography>
      </Stack>
      <Grid container spacing={2}>
        <Grid item xs={12} md={3}><StatCard label="Overall progress" value={`${progress}%`} helper={`${completedDays.size}/${dashboardStats.totalDays} days complete`} /></Grid>
        <Grid item xs={12} md={3}><StatCard label="Current day" value={`Day ${currentDay.day}`} helper={currentDay.title} /></Grid>
        <Grid item xs={12} md={3}><StatCard label="Hours planned" value={`${dashboardStats.totalHours}h`} helper="Across loaded JSON plans" /></Grid>
        <Grid item xs={12} md={3}><StatCard label="Projects" value={`${dashboardStats.totalProjects}`} helper="Monthly portfolio builds" /></Grid>
        <Grid item xs={12} md={7}>
          <Card className="soft-card"><CardContent>
            <Typography variant="h6">Completion progress</Typography>
            <LinearProgress variant="determinate" value={progress} sx={{ my: 2, height: 12, borderRadius: 99 }} />
            <Typography color="text.secondary">GitHub commits can be added later through the GitHub API once the core planner is stable.</Typography>
          </CardContent></Card>
        </Grid>
        <Grid item xs={12} md={5}>
          <Card className="soft-card chart-card"><CardContent>
            <Typography variant="h6">Planned study load</Typography>
            <ResponsiveContainer width="100%" height={180}>
              <LineChart data={chartData}><XAxis dataKey="day" /><YAxis /><Tooltip /><Line type="monotone" dataKey="hours" stroke="#2563eb" strokeWidth={3} /></LineChart>
            </ResponsiveContainer>
          </CardContent></Card>
        </Grid>
      </Grid>
    </Box>
  );
}

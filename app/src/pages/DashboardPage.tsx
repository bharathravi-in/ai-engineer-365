import { Box, Card, CardContent, Chip, Grid, LinearProgress, Stack, Typography, useTheme } from '@mui/material';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import { useDashboardStats, useDashboardStore, useMonthlyProgress } from '../store';
import PageHeader from '../components/PageHeader';

function StatCard({ label, value, helper, accent }: { label: string; value: string; helper: string; accent: string }) {
  return (
    <Card sx={{ height: '100%' }}>
      <CardContent>
        <Stack direction="row" spacing={1} sx={{ alignItems: 'center', mb: 1 }}>
          <Box sx={{ width: 10, height: 10, borderRadius: 99, bgcolor: accent }} />
          <Typography variant="body2" color="text.secondary">
            {label}
          </Typography>
        </Stack>
        <Typography variant="h4">{value}</Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5 }}>
          {helper}
        </Typography>
      </CardContent>
    </Card>
  );
}

export default function DashboardPage() {
  const theme = useTheme();
  const completedDays = useDashboardStore((state) => state.completedDays);
  const setSelectedDay = useDashboardStore((state) => state.setSelectedDay);
  const plannerDays = useDashboardStore((state) => state.days);
  const stats = useDashboardStats();
  const monthly = useMonthlyProgress();

  const currentDay = plannerDays.find((day) => !completedDays.has(day.day)) ?? plannerDays.at(-1);
  const currentMonth = monthly.find(
    (m) => currentDay && m.firstDay !== undefined && currentDay.day >= m.firstDay && currentDay.day < m.firstDay + m.totalDays,
  );
  const progress = stats.totalDays ? Math.round((completedDays.size / stats.totalDays) * 100) : 0;
  const doneHours = plannerDays
    .filter((d) => completedDays.has(d.day))
    .reduce((sum, d) => sum + (Number.parseFloat(d.duration) || 0), 0);

  const chartData = monthly.map((m) => ({ name: `M${m.month}`, percent: m.percent }));
  const gridColor = theme.palette.mode === 'dark' ? 'rgba(148,163,184,0.16)' : 'rgba(15,23,42,0.08)';

  return (
    <Box>
      <PageHeader
        overline="Dashboard"
        title="Your AI engineering cockpit"
        subtitle="Track progress across the 365-day roadmap — current day, hours, monthly completion, and portfolio projects in one place."
        action={<Chip color="primary" label={`${completedDays.size} / ${stats.totalDays} days`} />}
      />

      <Grid container spacing={2.5}>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <StatCard label="Overall progress" value={`${progress}%`} helper={`${completedDays.size}/${stats.totalDays} days complete`} accent={theme.palette.primary.main} />
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <StatCard
            label="Current focus"
            value={currentDay ? `Day ${currentDay.day}` : '—'}
            helper={currentDay?.title ?? 'All days complete 🎉'}
            accent={theme.palette.secondary.main}
          />
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <StatCard label="Hours invested" value={`${doneHours}h`} helper={`${stats.totalHours}h planned across the year`} accent={theme.palette.success.main} />
        </Grid>
        <Grid size={{ xs: 12, sm: 6, md: 3 }}>
          <StatCard label="Projects" value={`${stats.totalProjects}`} helper="Monthly portfolio builds" accent={theme.palette.warning.main} />
        </Grid>

        <Grid size={{ xs: 12, md: 5 }}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6">Completion progress</Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                {currentMonth ? `Currently in Month ${currentMonth.month}: ${currentMonth.title}` : 'Ready to begin'}
              </Typography>
              <LinearProgress variant="determinate" value={progress} sx={{ height: 12, borderRadius: 99, mb: 2 }} />
              <Stack spacing={1.5} sx={{ mt: 2 }}>
                {currentDay && (
                  <Box
                    onClick={() => {
                      setSelectedDay(currentDay.day);
                      window.location.hash = 'planner';
                    }}
                    sx={{
                      p: 2,
                      borderRadius: 2.5,
                      border: 1,
                      borderColor: 'divider',
                      cursor: 'pointer',
                      '&:hover': { borderColor: 'primary.main' },
                    }}
                  >
                    <Typography variant="caption" color="text.secondary">
                      Next up
                    </Typography>
                    <Typography variant="subtitle1" sx={{ fontWeight: 700 }}>
                      Day {currentDay.day}: {currentDay.title}
                    </Typography>
                    <Typography variant="body2" color="text.secondary">
                      {currentDay.learningObjective}
                    </Typography>
                  </Box>
                )}
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, md: 7 }}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="h6">Monthly completion</Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                Percentage of each month's days marked complete.
              </Typography>
              <ResponsiveContainer width="100%" height={240}>
                <BarChart data={chartData} margin={{ top: 8, right: 8, left: -20, bottom: 0 }}>
                  <CartesianGrid strokeDasharray="3 3" stroke={gridColor} vertical={false} />
                  <XAxis dataKey="name" tick={{ fontSize: 12, fill: theme.palette.text.secondary }} axisLine={false} tickLine={false} />
                  <YAxis domain={[0, 100]} tick={{ fontSize: 12, fill: theme.palette.text.secondary }} axisLine={false} tickLine={false} unit="%" />
                  <Tooltip
                    cursor={{ fill: gridColor }}
                    contentStyle={{
                      background: theme.palette.background.paper,
                      border: `1px solid ${gridColor}`,
                      borderRadius: 12,
                      color: theme.palette.text.primary,
                    }}
                    formatter={(value) => [`${value}%`, 'Complete']}
                  />
                  <Bar dataKey="percent" radius={[6, 6, 0, 0]}>
                    {chartData.map((entry) => (
                      <Cell key={entry.name} fill={entry.percent > 0 ? theme.palette.primary.main : gridColor} />
                    ))}
                  </Bar>
                </BarChart>
              </ResponsiveContainer>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}

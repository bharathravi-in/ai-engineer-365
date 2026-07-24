import { Box, Card, CardContent, Chip, Grid, LinearProgress, Stack, Typography } from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import { useDashboardStore, useMonthlyProgress } from '../store';
import PageHeader from '../components/PageHeader';

export default function MonthsPage() {
  const monthly = useMonthlyProgress();
  const setSelectedDay = useDashboardStore((state) => state.setSelectedDay);

  const openMonth = (firstDay?: number) => {
    if (firstDay !== undefined) setSelectedDay(firstDay);
    window.location.hash = 'planner';
  };

  return (
    <Box>
      <PageHeader
        overline="Roadmap"
        title="12 months, 12 technologies"
        subtitle="The full year at a glance. Each month builds toward a portfolio project — click a month to jump into its days."
      />
      <Grid container spacing={2.5}>
        {monthly.map((m) => {
          const complete = m.percent === 100;
          return (
            <Grid size={{ xs: 12, sm: 6, md: 4 }} key={m.month}>
              <Card
                onClick={() => openMonth(m.firstDay)}
                sx={{
                  height: '100%',
                  cursor: 'pointer',
                  transition: 'transform 0.15s ease, border-color 0.15s ease',
                  '&:hover': { transform: 'translateY(-3px)', borderColor: 'primary.main' },
                }}
              >
                <CardContent>
                  <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                    <Chip size="small" color="primary" variant="outlined" label={`Month ${m.month}`} />
                    {complete && <CheckCircleIcon color="success" fontSize="small" />}
                  </Stack>
                  <Typography variant="h6" sx={{ mb: 0.5 }}>
                    {m.title}
                  </Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2, minHeight: 40 }}>
                    {m.goal}
                  </Typography>
                  <Stack direction="row" sx={{ justifyContent: 'space-between', mb: 0.5 }}>
                    <Typography variant="caption" color="text.secondary">
                      {m.completedDays}/{m.totalDays} days
                    </Typography>
                    <Typography variant="caption" sx={{ fontWeight: 700 }} color={complete ? 'success.main' : 'primary.main'}>
                      {m.percent}%
                    </Typography>
                  </Stack>
                  <LinearProgress
                    variant="determinate"
                    value={m.percent}
                    color={complete ? 'success' : 'primary'}
                    sx={{ height: 7, borderRadius: 99 }}
                  />
                  <Stack direction="row" spacing={1} sx={{ alignItems: 'center', mt: 2 }}>
                    <RocketDot />
                    <Typography variant="body2" sx={{ fontWeight: 600 }} noWrap>
                      {m.project.name}
                    </Typography>
                  </Stack>
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>
    </Box>
  );
}

function RocketDot() {
  return (
    <Box
      sx={{
        width: 22,
        height: 22,
        flexShrink: 0,
        borderRadius: 1.5,
        display: 'grid',
        placeItems: 'center',
        fontSize: 12,
        bgcolor: (t) => (t.palette.mode === 'dark' ? 'rgba(129,140,248,0.16)' : 'rgba(99,102,241,0.1)'),
      }}
    >
      🚀
    </Box>
  );
}

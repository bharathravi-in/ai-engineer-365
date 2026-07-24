import { Box, Button, Card, CardContent, Chip, Grid, LinearProgress, Stack, Typography } from '@mui/material';
import GitHubIcon from '@mui/icons-material/GitHub';
import { useDashboardStore, useMonthlyProgress } from '../store';
import PageHeader from '../components/PageHeader';

export default function ProjectsPage() {
  const months = useDashboardStore((state) => state.months);
  const monthly = useMonthlyProgress();
  const progressByMonth = new Map(monthly.map((m) => [m.month, m.percent]));

  return (
    <Box>
      <PageHeader
        overline="Projects"
        title="Monthly portfolio projects"
        subtitle="Every month ships one production-style project. Together they become a portfolio that demonstrates real full-stack AI engineering."
      />
      <Grid container spacing={2.5}>
        {months.map((month) => {
          const percent = progressByMonth.get(month.month) ?? month.project.progress ?? 0;
          return (
            <Grid size={{ xs: 12, md: 6 }} key={month.month}>
              <Card sx={{ height: '100%' }}>
                <CardContent sx={{ p: 3 }}>
                  <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center', mb: 1 }}>
                    <Chip size="small" variant="outlined" color="primary" label={`Month ${month.month} · ${month.title}`} />
                    <Typography variant="caption" sx={{ fontWeight: 700 }} color="text.secondary">
                      {percent}%
                    </Typography>
                  </Stack>
                  <Typography variant="h5" sx={{ mb: 0.5 }}>
                    {month.project.name}
                  </Typography>
                  <Typography color="text.secondary" sx={{ mb: 2 }}>
                    {month.project.prd}
                  </Typography>

                  <Typography variant="subtitle2">Architecture</Typography>
                  <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                    {month.project.architecture}
                  </Typography>

                  <Stack direction="row" spacing={1} sx={{ mb: 2, flexWrap: 'wrap', gap: 1 }}>
                    {month.project.techStack.map((tech) => (
                      <Chip key={tech} label={tech} size="small" />
                    ))}
                  </Stack>

                  <LinearProgress variant="determinate" value={percent} sx={{ height: 8, borderRadius: 99, mb: 2 }} />

                  {month.project.githubUrl ? (
                    <Button
                      size="small"
                      variant="outlined"
                      startIcon={<GitHubIcon />}
                      href={month.project.githubUrl}
                      target="_blank"
                      rel="noreferrer"
                    >
                      View repository
                    </Button>
                  ) : (
                    <Button size="small" variant="outlined" startIcon={<GitHubIcon />} disabled>
                      Add GitHub link
                    </Button>
                  )}
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>
    </Box>
  );
}

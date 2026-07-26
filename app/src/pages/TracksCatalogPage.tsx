import { useEffect } from 'react';
import { Alert, Box, Card, CardActionArea, CardContent, Chip, Grid, Stack, Typography } from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import { useTrackStore } from '../trackStore';
import { useDashboardStore } from '../store';
import PageHeader from '../components/PageHeader';

export default function TracksCatalogPage() {
  const { catalog, catalogLoading, loadCatalog, enrollments, loadEnrollments, error } = useTrackStore();
  const user = useDashboardStore((s) => s.user);

  useEffect(() => {
    void loadCatalog();
  }, [loadCatalog]);
  useEffect(() => {
    if (user) void loadEnrollments();
  }, [user, loadEnrollments]);

  return (
    <Box>
      <PageHeader
        overline="Roadmaps"
        title="Choose your learning path"
        subtitle="Pick a track to get a concept-by-concept roadmap with reference materials and a day-by-day plan built around your schedule."
      />

      {!user && (
        <Alert severity="info" sx={{ mb: 2 }}>
          Browsing as a guest — explore any roadmap freely. Sign in to enroll, track progress, and generate your personalized day planner.
        </Alert>
      )}
      {error && <Alert severity="error" sx={{ mb: 2 }}>{error}</Alert>}

      <Grid container spacing={2.5}>
        {(catalogLoading && !catalog.length ? Array.from({ length: 4 }) : catalog).map((t: any, i) => {
          if (!t) {
            return (
              <Grid key={i} size={{ xs: 12, sm: 6, md: 4 }}>
                <Card sx={{ height: 200, opacity: 0.5 }} />
              </Grid>
            );
          }
          const enrolled = Boolean(enrollments[t.id]);
          return (
            <Grid key={t.id} size={{ xs: 12, sm: 6, md: 4 }}>
              <Card
                sx={{
                  height: '100%',
                  '&:hover': { transform: 'translateY(-4px)', boxShadow: (th) => (th.palette.mode === 'dark' ? '0 16px 40px rgba(0,0,0,0.5)' : '0 18px 40px rgba(15,23,42,0.12)'), borderColor: `${t.color}55` },
                }}
              >
                <CardActionArea sx={{ height: '100%' }} href={`#track/${t.slug}`}>
                  <CardContent sx={{ p: 2.75 }}>
                    <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'flex-start' }}>
                      <Box sx={{ width: 52, height: 52, borderRadius: 3, display: 'grid', placeItems: 'center', fontSize: 26, background: `${t.color}1a`, border: `1px solid ${t.color}33` }}>{t.icon}</Box>
                      {enrolled && <Chip size="small" color="success" icon={<CheckCircleIcon />} label="Enrolled" />}
                    </Stack>
                    <Typography variant="h6" sx={{ mt: 1.75 }}>{t.title}</Typography>
                    <Typography variant="body2" sx={{ color: t.color, fontWeight: 600 }}>{t.subtitle}</Typography>
                    <Typography variant="body2" color="text.secondary" sx={{ mt: 1.25, minHeight: 40 }}>{t.description}</Typography>
                    <Stack direction="row" spacing={0.75} sx={{ mt: 2, flexWrap: 'wrap', gap: 0.5 }}>
                      <Chip size="small" variant="outlined" label={t.difficulty} />
                      <Chip size="small" variant="outlined" label={`${t.topic_count} concepts`} />
                      <Chip size="small" variant="outlined" label={`~${t.total_hours} hrs`} />
                    </Stack>
                  </CardContent>
                </CardActionArea>
              </Card>
            </Grid>
          );
        })}
      </Grid>
    </Box>
  );
}

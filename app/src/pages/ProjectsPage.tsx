import { Box, Card, CardContent, Chip, Grid, LinearProgress, Stack, Typography } from '@mui/material';
import { plannerMonths } from '../plannerData';

export default function ProjectsPage() {
  return (
    <Box id="projects" className="page-section">
      <Stack spacing={1} sx={{ mb: 3 }}><Typography variant="overline" color="primary">Projects</Typography><Typography variant="h4">Monthly portfolio projects</Typography></Stack>
      <Grid container spacing={2}>{plannerMonths.map((month) => (
        <Grid item xs={12} md={6} key={month.month}><Card className="soft-card"><CardContent>
          <Typography variant="overline">Month {month.month}</Typography>
          <Typography variant="h5">{month.project.name}</Typography>
          <Typography color="text.secondary" sx={{ my: 1 }}>{month.project.prd}</Typography>
          <Typography variant="subtitle2">Architecture</Typography><Typography sx={{ mb: 2 }}>{month.project.architecture}</Typography>
          <Stack direction="row" spacing={1} flexWrap="wrap" sx={{ mb: 2 }}>{month.project.techStack.map((tech) => <Chip key={tech} label={tech} />)}</Stack>
          <LinearProgress variant="determinate" value={month.project.progress} sx={{ height: 10, borderRadius: 99 }} />
          <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>{month.project.progress}% complete</Typography>
        </CardContent></Card></Grid>
      ))}</Grid>
    </Box>
  );
}

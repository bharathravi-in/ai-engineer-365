import { Box, Card, CardContent, Chip, Grid, Stack, Typography } from '@mui/material';

const resources = [
  { type: 'Official docs', title: 'PostgreSQL Documentation', url: 'https://www.postgresql.org/docs/' },
  { type: 'Official docs', title: 'MDN HTTP Guides', url: 'https://developer.mozilla.org/en-US/docs/Web/HTTP' },
  { type: 'Practice', title: 'SQLBolt', url: 'https://sqlbolt.com/' },
  { type: 'Book', title: 'Designing Data-Intensive Applications', url: 'https://dataintensive.net/' },
  { type: 'Cheat sheet', title: 'TypeScript Handbook', url: 'https://www.typescriptlang.org/docs/' },
];

export default function ResourceLibraryPage() {
  return (
    <Box id="resources" className="page-section">
      <Stack spacing={1} sx={{ mb: 3 }}><Typography variant="overline" color="primary">Resource Library</Typography><Typography variant="h4">Curated references for the plan</Typography></Stack>
      <Grid container spacing={2}>{resources.map((resource) => (
        <Grid item xs={12} md={4} key={resource.title}><Card className="soft-card"><CardContent><Chip label={resource.type} size="small" /><Typography variant="h6" sx={{ mt: 2 }}>{resource.title}</Typography><Typography component="a" href={resource.url} target="_blank" rel="noreferrer" color="primary">{resource.url}</Typography></CardContent></Card></Grid>
      ))}</Grid>
    </Box>
  );
}

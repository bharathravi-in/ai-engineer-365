import { useMemo, useState } from 'react';
import { Box, Card, CardContent, Chip, Grid, Link, Stack, Typography } from '@mui/material';
import PageHeader from '../components/PageHeader';

type Resource = { type: string; title: string; url: string; month: number };

const resources: Resource[] = [
  { type: 'Docs', title: 'PostgreSQL Documentation', url: 'https://www.postgresql.org/docs/', month: 1 },
  { type: 'Practice', title: 'SQLBolt', url: 'https://sqlbolt.com/', month: 1 },
  { type: 'Docs', title: 'Python Official Docs', url: 'https://docs.python.org/3/', month: 2 },
  { type: 'Practice', title: 'Real Python', url: 'https://realpython.com/', month: 2 },
  { type: 'Docs', title: 'FastAPI', url: 'https://fastapi.tiangolo.com/', month: 3 },
  { type: 'Docs', title: 'Redis Documentation', url: 'https://redis.io/docs/latest/', month: 3 },
  { type: 'Docs', title: 'Docker Documentation', url: 'https://docs.docker.com/', month: 4 },
  { type: 'Docs', title: 'Kubernetes Documentation', url: 'https://kubernetes.io/docs/home/', month: 4 },
  { type: 'Docs', title: 'Claude API (Anthropic)', url: 'https://docs.claude.com/', month: 5 },
  { type: 'Course', title: 'Anthropic Prompt Engineering', url: 'https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/overview', month: 5 },
  { type: 'Docs', title: 'pgvector', url: 'https://github.com/pgvector/pgvector', month: 6 },
  { type: 'Docs', title: 'Chroma', url: 'https://docs.trychroma.com/', month: 6 },
  { type: 'Docs', title: 'LangGraph', url: 'https://langchain-ai.github.io/langgraph/', month: 7 },
  { type: 'Docs', title: 'Model Context Protocol', url: 'https://modelcontextprotocol.io/', month: 7 },
  { type: 'Docs', title: 'ClickHouse', url: 'https://clickhouse.com/docs', month: 8 },
  { type: 'Docs', title: 'Apache Kafka', url: 'https://kafka.apache.org/documentation/', month: 8 },
  { type: 'Docs', title: 'Elasticsearch', url: 'https://www.elastic.co/guide/index.html', month: 9 },
  { type: 'Docs', title: 'Neo4j & Cypher', url: 'https://neo4j.com/docs/', month: 9 },
  { type: 'Docs', title: 'AWS Documentation', url: 'https://docs.aws.amazon.com/', month: 10 },
  { type: 'Docs', title: 'Terraform', url: 'https://developer.hashicorp.com/terraform/docs', month: 10 },
  { type: 'Book', title: 'Designing Data-Intensive Applications', url: 'https://dataintensive.net/', month: 11 },
  { type: 'Guide', title: 'System Design Primer', url: 'https://github.com/donnemartin/system-design-primer', month: 11 },
  { type: 'Guide', title: 'Building Effective Agents (Anthropic)', url: 'https://www.anthropic.com/engineering/building-effective-agents', month: 12 },
  { type: 'Cheat sheet', title: 'TypeScript Handbook', url: 'https://www.typescriptlang.org/docs/', month: 12 },
];

const typeColor: Record<string, 'primary' | 'secondary' | 'success' | 'warning' | 'default'> = {
  Docs: 'primary',
  Practice: 'success',
  Book: 'secondary',
  Course: 'warning',
  Guide: 'secondary',
  'Cheat sheet': 'default',
};

export default function ResourceLibraryPage() {
  const types = useMemo(() => ['All', ...Array.from(new Set(resources.map((r) => r.type)))], []);
  const [filter, setFilter] = useState('All');
  const visible = filter === 'All' ? resources : resources.filter((r) => r.type === filter);

  return (
    <Box>
      <PageHeader
        overline="Resource Library"
        title="Curated references for every month"
        subtitle="Official docs, practice sites, and books mapped to the 12-month roadmap."
      />

      <Stack direction="row" spacing={1} sx={{ mb: 3, flexWrap: 'wrap', gap: 1 }}>
        {types.map((t) => (
          <Chip
            key={t}
            label={t}
            onClick={() => setFilter(t)}
            color={filter === t ? 'primary' : 'default'}
            variant={filter === t ? 'filled' : 'outlined'}
          />
        ))}
      </Stack>

      <Grid container spacing={2.5}>
        {visible.map((resource) => (
          <Grid size={{ xs: 12, sm: 6, md: 4 }} key={resource.title}>
            <Card sx={{ height: '100%' }}>
              <CardContent>
                <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center', mb: 1.5 }}>
                  <Chip label={resource.type} size="small" color={typeColor[resource.type] ?? 'default'} />
                  <Typography variant="caption" color="text.secondary">
                    Month {resource.month}
                  </Typography>
                </Stack>
                <Typography variant="h6" sx={{ mb: 1 }}>
                  {resource.title}
                </Typography>
                <Link href={resource.url} target="_blank" rel="noreferrer" variant="body2" sx={{ wordBreak: 'break-all' }}>
                  {resource.url}
                </Link>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Box>
  );
}

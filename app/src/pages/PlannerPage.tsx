import { useMemo, useState } from 'react';
import {
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Grid,
  LinearProgress,
  Stack,
  Tab,
  Tabs,
  Typography,
} from '@mui/material';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import RadioButtonUncheckedIcon from '@mui/icons-material/RadioButtonUnchecked';
import { useDashboardStore } from '../store';
import PageHeader from '../components/PageHeader';

function BulletList({ title, items }: { title: string; items: string[] }) {
  if (!items.length) return null;
  return (
    <Box>
      <Typography variant="subtitle2" sx={{ mb: 1 }}>
        {title}
      </Typography>
      <Stack component="ul" spacing={0.75} sx={{ m: 0, pl: 2.2 }}>
        {items.map((item) => (
          <Typography key={item} component="li" variant="body2" color="text.secondary">
            {item}
          </Typography>
        ))}
      </Stack>
    </Box>
  );
}

export default function PlannerPage() {
  const { completedDays, selectedDay, setSelectedDay, toggleDay, months } = useDashboardStore();
  const day = useDashboardStore((state) => state.days).find((entry) => entry.day === selectedDay);

  const monthOfSelected = useMemo(
    () => months.find((m) => m.days.some((d) => d.day === selectedDay))?.month ?? months[0]?.month ?? 1,
    [months, selectedDay],
  );
  const [activeMonth, setActiveMonth] = useState<number>(monthOfSelected);
  const month = months.find((m) => m.month === activeMonth) ?? months[0];

  if (!month || !day) {
    return (
      <Box>
        <PageHeader overline="Daily Planner" title="No planner days yet" subtitle="Use Add Entry to create your first study day." />
      </Box>
    );
  }

  const monthDays = month.days;
  const monthDone = monthDays.filter((d) => completedDays.has(d.day)).length;

  return (
    <Box>
      <PageHeader
        overline="Daily Planner"
        title="Your day-by-day roadmap"
        subtitle="Pick a month, then work through each day. Everything is driven by the JSON plans under /planner."
      />

      <Tabs
        value={activeMonth}
        onChange={(_, next) => setActiveMonth(next)}
        variant="scrollable"
        scrollButtons="auto"
        sx={{ mb: 3, '& .MuiTab-root': { textTransform: 'none', fontWeight: 600, minHeight: 44 } }}
      >
        {months.map((m) => (
          <Tab key={m.month} value={m.month} label={`M${m.month} · ${m.title}`} />
        ))}
      </Tabs>

      <Grid container spacing={2.5}>
        <Grid size={{ xs: 12, md: 4 }}>
          <Card>
            <CardContent>
              <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'baseline', mb: 1 }}>
                <Typography variant="subtitle2" color="text.secondary">
                  Month {month.month}
                </Typography>
                <Typography variant="caption" color="text.secondary">
                  {monthDone}/{monthDays.length} done
                </Typography>
              </Stack>
              <LinearProgress
                variant="determinate"
                value={monthDays.length ? (monthDone / monthDays.length) * 100 : 0}
                sx={{ height: 8, borderRadius: 99, mb: 2 }}
              />
              <Stack spacing={0.5} sx={{ maxHeight: { md: 560 }, overflowY: { md: 'auto' }, pr: 0.5 }}>
                {monthDays.map((entry) => {
                  const done = completedDays.has(entry.day);
                  const active = entry.day === selectedDay;
                  return (
                    <Button
                      key={entry.day}
                      onClick={() => setSelectedDay(entry.day)}
                      startIcon={
                        done ? (
                          <CheckCircleIcon fontSize="small" color="success" />
                        ) : (
                          <RadioButtonUncheckedIcon fontSize="small" sx={{ opacity: 0.4 }} />
                        )
                      }
                      sx={{
                        justifyContent: 'flex-start',
                        textAlign: 'left',
                        color: active ? 'primary.main' : 'text.primary',
                        bgcolor: active ? 'action.selected' : 'transparent',
                        fontWeight: active ? 700 : 500,
                        px: 1.5,
                      }}
                    >
                      <Box component="span" sx={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        Day {entry.day}: {entry.title}
                      </Box>
                    </Button>
                  );
                })}
              </Stack>
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, md: 8 }}>
          <Card>
            <CardContent sx={{ p: 3 }}>
              <Stack direction="row" sx={{ alignItems: 'flex-start', justifyContent: 'space-between', gap: 2, flexWrap: 'wrap' }}>
                <Box>
                  <Typography variant="overline" color="primary">
                    Month {month.month} · {month.title}
                  </Typography>
                  <Typography variant="h5">
                    Day {day.day}: {day.title}
                  </Typography>
                  <Typography color="text.secondary" sx={{ mt: 0.5 }}>
                    {day.learningObjective}
                  </Typography>
                </Box>
                <Button
                  variant={completedDays.has(day.day) ? 'outlined' : 'contained'}
                  color={completedDays.has(day.day) ? 'success' : 'primary'}
                  onClick={() => toggleDay(day.day)}
                >
                  {completedDays.has(day.day) ? 'Completed ✓' : 'Mark complete'}
                </Button>
              </Stack>

              <Stack direction="row" spacing={1} sx={{ my: 2.5, flexWrap: 'wrap' }}>
                <Chip label={day.duration} color="primary" variant="outlined" />
                <Chip
                  label={completedDays.has(day.day) ? 'Completed' : 'In progress'}
                  color={completedDays.has(day.day) ? 'success' : 'default'}
                />
              </Stack>

              <Grid container spacing={3}>
                <Grid size={{ xs: 12, md: 6 }}><BulletList title="Practice" items={day.practice} /></Grid>
                <Grid size={{ xs: 12, md: 6 }}><BulletList title="Daily tasks" items={day.tasks} /></Grid>
                <Grid size={{ xs: 12, md: 6 }}><BulletList title="Videos" items={day.videos} /></Grid>
                <Grid size={{ xs: 12, md: 6 }}><BulletList title="Documentation" items={day.docs} /></Grid>
                <Grid size={{ xs: 12, md: 6 }}><BulletList title="Reading" items={day.reading} /></Grid>
                <Grid size={{ xs: 12, md: 6 }}><BulletList title="Interview questions" items={day.interviewQuestions} /></Grid>
              </Grid>

              {day.miniProject && (
                <Box
                  sx={{
                    mt: 3,
                    p: 2.5,
                    borderRadius: 3,
                    bgcolor: (t) => (t.palette.mode === 'dark' ? 'rgba(129,140,248,0.12)' : 'rgba(99,102,241,0.08)'),
                    border: 1,
                    borderColor: 'divider',
                  }}
                >
                  <Typography variant="subtitle2">Mini project</Typography>
                  <Typography variant="body2" color="text.secondary">
                    {day.miniProject}
                  </Typography>
                </Box>
              )}
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}

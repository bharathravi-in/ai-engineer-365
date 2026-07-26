import { Accordion, AccordionDetails, AccordionSummary, Box, Chip, Stack, Typography } from '@mui/material';
import ExpandMoreIcon from '@mui/icons-material/ExpandMore';
import CheckCircleIcon from '@mui/icons-material/CheckCircle';
import RadioButtonUncheckedIcon from '@mui/icons-material/RadioButtonUnchecked';
import ChevronRightIcon from '@mui/icons-material/ChevronRight';
import type { Module, Topic } from '../lib/api';

type Selected = { topic: Topic; moduleTitle: string; index: number };

/** Accordion representation of the same journey (module → topics), collapsible. */
export default function RoadmapList({
  modules, completed, accent, onSelect,
}: {
  modules: Module[];
  completed: Set<string>;
  accent: string;
  onSelect: (s: Selected) => void;
}) {
  let step = 0;
  return (
    <Box>
      {modules.map((m, mi) => {
        const done = m.topics.filter((t) => completed.has(t.id)).length;
        return (
          <Accordion key={m.id} defaultExpanded={mi === 0} disableGutters sx={{ mb: 1.25, borderRadius: 3, border: 1, borderColor: 'divider', '&:before': { display: 'none' }, boxShadow: 'none' }}>
            <AccordionSummary expandIcon={<ExpandMoreIcon />} sx={{ px: 2 }}>
              <Stack direction="row" spacing={1.25} sx={{ alignItems: 'center', flexGrow: 1 }}>
                <Box sx={{ width: 24, height: 24, borderRadius: '50%', display: 'grid', placeItems: 'center', fontSize: 12, fontWeight: 800, color: '#fff', bgcolor: accent }}>{mi + 1}</Box>
                <Typography sx={{ fontWeight: 700, flexGrow: 1 }}>{m.title}</Typography>
                <Chip size="small" variant="outlined" label={`${done}/${m.topics.length}`} sx={{ mr: 1 }} />
              </Stack>
            </AccordionSummary>
            <AccordionDetails sx={{ pt: 0, px: 2, pb: 1.5 }}>
              <Stack spacing={0.5}>
                {m.topics.map((topic) => {
                  const gi = step; step += 1;
                  const isDone = completed.has(topic.id);
                  return (
                    <Box
                      key={topic.id}
                      component="button"
                      onClick={() => onSelect({ topic, moduleTitle: m.title, index: gi + 1 })}
                      sx={{
                        width: '100%', textAlign: 'left', cursor: 'pointer', font: 'inherit',
                        display: 'flex', alignItems: 'center', gap: 1.25, p: 1.25, borderRadius: 2,
                        border: 0, bgcolor: 'transparent',
                        '&:hover': { bgcolor: 'action.hover' },
                      }}
                    >
                      {isDone ? <CheckCircleIcon fontSize="small" color="success" /> : <RadioButtonUncheckedIcon fontSize="small" sx={{ opacity: 0.4 }} />}
                      <Typography variant="body2" sx={{ flexGrow: 1, fontWeight: 500, textDecoration: isDone ? 'line-through' : 'none', opacity: isDone ? 0.6 : 1 }}>
                        {topic.title}
                      </Typography>
                      <Chip size="small" variant="outlined" label={`${topic.est_hours}h`} sx={{ height: 20 }} />
                      <ChevronRightIcon fontSize="small" sx={{ color: 'text.disabled' }} />
                    </Box>
                  );
                })}
              </Stack>
            </AccordionDetails>
          </Accordion>
        );
      })}
    </Box>
  );
}

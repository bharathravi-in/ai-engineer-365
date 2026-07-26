import { useEffect, useState } from 'react';
import {
  Alert,
  Button,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { useTrackStore } from '../trackStore';
import type { Enrollment, TrackDetail } from '../lib/api';

const HOUR_OPTIONS = [0, 0.5, 1, 1.5, 2, 3, 4, 5, 6, 8];

/** Set up (or edit) a personalized plan: start date + weekday/weekend hours. */
export default function EnrollDialog({
  open,
  onClose,
  track,
  existing,
  onSaved,
}: {
  open: boolean;
  onClose: () => void;
  track: TrackDetail['track'];
  existing?: Enrollment;
  onSaved?: (wasNew: boolean) => void;
}) {
  const enroll = useTrackStore((s) => s.enroll);
  const [startDate, setStartDate] = useState(existing?.start_date ?? new Date().toISOString().slice(0, 10));
  const [weekday, setWeekday] = useState<number>(existing?.weekday_hours ?? 2);
  const [weekend, setWeekend] = useState<number>(existing?.weekend_hours ?? 4);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      setStartDate(existing?.start_date ?? new Date().toISOString().slice(0, 10));
      setWeekday(existing?.weekday_hours ?? 2);
      setWeekend(existing?.weekend_hours ?? 4);
      setError(null);
    }
  }, [open, existing]);

  const save = async () => {
    setBusy(true);
    setError(null);
    const wasNew = !existing;
    const { error } = await enroll({ track_id: track.id, start_date: startDate, weekday_hours: weekday, weekend_hours: weekend });
    setBusy(false);
    if (error) setError(error);
    else {
      onSaved?.(wasNew);
      onClose();
    }
  };

  return (
    <Dialog open={open} onClose={onClose} maxWidth="xs" fullWidth>
      <DialogTitle>{existing ? 'Adjust your plan' : `Start the ${track.title} roadmap`}</DialogTitle>
      <DialogContent>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          We'll schedule the topics day by day based on how many hours you can study.
        </Typography>
        <Stack spacing={2} sx={{ mt: 0.5 }}>
          {error && <Alert severity="error">{error}</Alert>}
          <TextField
            label="Start date"
            type="date"
            value={startDate}
            onChange={(e) => setStartDate(e.target.value)}
            slotProps={{ inputLabel: { shrink: true } }}
            fullWidth
          />
          <TextField select label="Hours per weekday" value={weekday} onChange={(e) => setWeekday(Number(e.target.value))} fullWidth>
            {HOUR_OPTIONS.filter((h) => h > 0).map((h) => (
              <MenuItem key={h} value={h}>{h} h</MenuItem>
            ))}
          </TextField>
          <TextField select label="Hours per weekend day" value={weekend} onChange={(e) => setWeekend(Number(e.target.value))} fullWidth helperText="Set 0 to keep weekends free.">
            {HOUR_OPTIONS.map((h) => (
              <MenuItem key={h} value={h}>{h} h</MenuItem>
            ))}
          </TextField>
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Cancel</Button>
        <Button variant="contained" onClick={() => void save()} disabled={busy}>
          {busy ? 'Saving…' : existing ? 'Update plan' : 'Start learning'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

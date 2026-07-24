import { useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Divider,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import LogoutIcon from '@mui/icons-material/Logout';
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';
import { useDashboardStore } from '../store';
import PageHeader from '../components/PageHeader';

export default function LoginPage() {
  const { supabaseEnabled, user, profile, signIn, signUp, signOut } = useDashboardStore();
  const [mode, setMode] = useState<'signin' | 'signup'>('signin');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ type: 'error' | 'success'; text: string } | null>(null);

  if (!supabaseEnabled) {
    return (
      <Box>
        <PageHeader overline="Account" title="Supabase isn't configured yet" />
        <Alert severity="info">
          Add your project URL and anon key to <code>app/.env.local</code> and restart the dev server to enable login,
          cloud sync, and the admin panel.
        </Alert>
      </Box>
    );
  }

  if (user) {
    return (
      <Box>
        <PageHeader overline="Account" title="You're signed in" subtitle="Your progress and notes now sync to Supabase." />
        <Card sx={{ maxWidth: 460 }}>
          <CardContent>
            <Stack spacing={1.5}>
              <Typography variant="body2" color="text.secondary">
                Signed in as
              </Typography>
              <Typography variant="h6">{user.email}</Typography>
              {profile?.is_admin ? (
                <Chip icon={<AdminPanelSettingsIcon />} color="primary" label="Admin" sx={{ alignSelf: 'flex-start' }} />
              ) : (
                <Chip label="Learner" variant="outlined" sx={{ alignSelf: 'flex-start' }} />
              )}
              <Divider sx={{ my: 1 }} />
              <Button variant="outlined" color="error" startIcon={<LogoutIcon />} onClick={() => void signOut()} sx={{ alignSelf: 'flex-start' }}>
                Sign out
              </Button>
            </Stack>
          </CardContent>
        </Card>
      </Box>
    );
  }

  const submit = async () => {
    setBusy(true);
    setMessage(null);
    const action = mode === 'signin' ? signIn : signUp;
    const { error } = await action(email.trim(), password);
    setBusy(false);
    if (error) {
      setMessage({ type: 'error', text: error });
    } else if (mode === 'signup') {
      setMessage({ type: 'success', text: 'Account created. If email confirmation is on, confirm via email, then sign in.' });
      setMode('signin');
    }
  };

  return (
    <Box>
      <PageHeader
        overline="Account"
        title={mode === 'signin' ? 'Sign in' : 'Create an account'}
        subtitle="Sign in to sync your progress and notes to the cloud. Admins can manage the plan content."
      />
      <Card sx={{ maxWidth: 460 }}>
        <CardContent>
          <Stack spacing={2} component="form" onSubmit={(e) => { e.preventDefault(); void submit(); }}>
            {message && <Alert severity={message.type}>{message.text}</Alert>}
            <TextField label="Email" type="email" value={email} onChange={(e) => setEmail(e.target.value)} fullWidth required autoComplete="email" />
            <TextField label="Password" type="password" value={password} onChange={(e) => setPassword(e.target.value)} fullWidth required autoComplete={mode === 'signin' ? 'current-password' : 'new-password'} />
            <Button type="submit" variant="contained" disabled={busy || !email || !password}>
              {busy ? 'Please wait…' : mode === 'signin' ? 'Sign in' : 'Sign up'}
            </Button>
            <Divider />
            <Button onClick={() => { setMode(mode === 'signin' ? 'signup' : 'signin'); setMessage(null); }}>
              {mode === 'signin' ? 'Need an account? Sign up' : 'Have an account? Sign in'}
            </Button>
          </Stack>
        </CardContent>
      </Card>
    </Box>
  );
}

import { useState } from 'react';
import { Alert, Button, Divider, Stack, TextField } from '@mui/material';
import { useDashboardStore } from '../store';
import AuthLayout from '../components/AuthLayout';

/** Standalone, full-page registration screen (no app sidebar). */
export default function RegisterPage() {
  const signUp = useDashboardStore((s) => s.signUp);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ type: 'error' | 'success'; text: string } | null>(null);

  const submit = async () => {
    setBusy(true);
    setMessage(null);
    const { error } = await signUp(email.trim(), password);
    setBusy(false);
    if (error) {
      setMessage({ type: 'error', text: error });
    } else {
      setMessage({
        type: 'success',
        text: 'Account created. If email confirmation is enabled, confirm via the email we sent, then sign in.',
      });
    }
  };

  return (
    <AuthLayout title="Create your account" subtitle="Register to start tracking your 360-day roadmap.">
      <Stack spacing={2} component="form" onSubmit={(e) => { e.preventDefault(); void submit(); }}>
        {message && <Alert severity={message.type}>{message.text}</Alert>}
        <TextField
          label="Email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          fullWidth
          required
          autoFocus
          autoComplete="email"
        />
        <TextField
          label="Password"
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          fullWidth
          required
          autoComplete="new-password"
          helperText="At least 6 characters."
        />
        <Button type="submit" variant="contained" size="large" disabled={busy || !email || !password}>
          {busy ? 'Creating account…' : 'Sign up'}
        </Button>
        <Divider>Already registered?</Divider>
        <Button href="#login" variant="outlined">
          Sign in instead
        </Button>
      </Stack>
    </AuthLayout>
  );
}

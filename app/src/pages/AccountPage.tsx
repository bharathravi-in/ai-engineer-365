import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  Chip,
  Divider,
  Stack,
  Typography,
} from '@mui/material';
import LogoutIcon from '@mui/icons-material/Logout';
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';
import { useDashboardStore } from '../store';
import PageHeader from '../components/PageHeader';

/** In-shell account page: profile + sign out when logged in, sign-in CTA otherwise. */
export default function AccountPage() {
  const { supabaseEnabled, user, profile, signOut } = useDashboardStore();

  if (!supabaseEnabled) {
    return (
      <Box>
        <PageHeader overline="Account" title="Accounts are disabled" />
        <Alert severity="info">Supabase isn't configured, so the app runs in local-only mode.</Alert>
      </Box>
    );
  }

  if (!user) {
    return (
      <Box>
        <PageHeader
          overline="Account"
          title="You're browsing as a guest"
          subtitle="Sign in to track day completion and save your notes to the cloud."
        />
        <Stack direction="row" spacing={1}>
          <Button variant="contained" href="#login">
            Sign in
          </Button>
          <Button variant="outlined" href="#register">
            Create account
          </Button>
        </Stack>
      </Box>
    );
  }

  return (
    <Box>
      <PageHeader overline="Account" title="Your account" subtitle="Your progress and notes sync to the cloud." />
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
            <Button
              variant="outlined"
              color="error"
              startIcon={<LogoutIcon />}
              onClick={() => void signOut()}
              sx={{ alignSelf: 'flex-start' }}
            >
              Sign out
            </Button>
          </Stack>
        </CardContent>
      </Card>
    </Box>
  );
}

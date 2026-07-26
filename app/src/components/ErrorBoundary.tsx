import { Component, type ReactNode } from 'react';
import { Box, Button, Stack, Typography } from '@mui/material';

/** Catches render errors so a broken page shows a recovery UI, not a blank screen. */
export default class ErrorBoundary extends Component<{ children: ReactNode }, { error: Error | null }> {
  state = { error: null as Error | null };

  static getDerivedStateFromError(error: Error) {
    return { error };
  }
  componentDidCatch(error: Error) {
    console.error('Render error:', error);
  }

  render() {
    if (this.state.error) {
      return (
        <Box sx={{ display: 'grid', placeItems: 'center', minHeight: '60vh', p: 3 }}>
          <Stack spacing={2} sx={{ textAlign: 'center', maxWidth: 420 }}>
            <Typography variant="h5">Something went wrong</Typography>
            <Typography variant="body2" color="text.secondary">
              An unexpected error occurred while rendering this page.
            </Typography>
            <Box>
              <Button variant="contained" onClick={() => window.location.reload()}>Reload</Button>
            </Box>
          </Stack>
        </Box>
      );
    }
    return this.props.children;
  }
}

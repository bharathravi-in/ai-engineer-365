import type { ReactNode } from 'react';
import { Box, Card, CardContent, Link, Stack, Typography } from '@mui/material';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';

/**
 * Full-viewport, centered shell for the standalone auth pages (login / register).
 * Rendered OUTSIDE the main app sidebar/AppBar layout so these are their own pages.
 */
export default function AuthLayout({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
}) {
  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'grid',
        placeItems: 'center',
        p: 2,
        background: 'linear-gradient(135deg, #4338ca 0%, #4f46e5 45%, #6d28d9 100%)',
      }}
    >
      <Card sx={{ width: '100%', maxWidth: 440, borderRadius: 4, boxShadow: 24 }}>
        <CardContent sx={{ p: { xs: 3, sm: 4 } }}>
          <Stack direction="row" spacing={1.2} sx={{ alignItems: 'center' }}>
            <Box
              sx={{
                width: 40,
                height: 40,
                borderRadius: 2,
                display: 'grid',
                placeItems: 'center',
                fontSize: 22,
                color: '#fff',
                background: 'linear-gradient(135deg,#4f46e5,#6d28d9)',
              }}
            >
              🚀
            </Box>
            <Box>
              <Typography variant="h6" sx={{ lineHeight: 1.1 }}>
                AI Engineer 365
              </Typography>
              <Typography variant="caption" color="text.secondary">
                Learning roadmap
              </Typography>
            </Box>
          </Stack>

          <Typography variant="h5" sx={{ mt: 3, fontWeight: 700 }}>
            {title}
          </Typography>
          {subtitle && (
            <Typography variant="body2" color="text.secondary" sx={{ mt: 0.5, mb: 3 }}>
              {subtitle}
            </Typography>
          )}
          {!subtitle && <Box sx={{ mb: 3 }} />}

          {children}

          <Box sx={{ mt: 3, textAlign: 'center' }}>
            <Link
              href="#dashboard"
              underline="hover"
              sx={{ display: 'inline-flex', alignItems: 'center', gap: 0.5, fontSize: 14 }}
            >
              <ArrowBackIcon fontSize="inherit" /> Continue as guest
            </Link>
          </Box>
        </CardContent>
      </Card>
    </Box>
  );
}

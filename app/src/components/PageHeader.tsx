import { Stack, Typography } from '@mui/material';
import type { ReactNode } from 'react';

/** Consistent hero header used at the top of every page. */
export default function PageHeader({
  overline,
  title,
  subtitle,
  action,
}: {
  overline: string;
  title: string;
  subtitle?: string;
  action?: ReactNode;
}) {
  return (
    <Stack
      direction="row"
      sx={{ justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 2, mb: 3.5 }}
    >
      <Stack spacing={0.75}>
        <Typography variant="overline" color="primary">
          {overline}
        </Typography>
        <Typography variant="h4">{title}</Typography>
        {subtitle && (
          <Typography color="text.secondary" sx={{ maxWidth: 720 }}>
            {subtitle}
          </Typography>
        )}
      </Stack>
      {action}
    </Stack>
  );
}

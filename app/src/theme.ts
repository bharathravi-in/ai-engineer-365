import { createTheme, type PaletteMode, type Theme } from '@mui/material';

/** Build the app theme for a given light/dark mode. Kept in one place so the
 *  whole UI shares one design system. */
export function buildTheme(mode: PaletteMode): Theme {
  const isDark = mode === 'dark';
  return createTheme({
    palette: {
      mode,
      primary: { main: isDark ? '#818cf8' : '#6366f1' },
      secondary: { main: '#14b8a6' },
      success: { main: '#22c55e' },
      warning: { main: '#f59e0b' },
      background: {
        default: isDark ? '#0b1020' : '#f5f6fb',
        paper: isDark ? '#131a2e' : '#ffffff',
      },
      divider: isDark ? 'rgba(148,163,184,0.16)' : 'rgba(15,23,42,0.08)',
      text: {
        primary: isDark ? '#e6ebf5' : '#0f172a',
        secondary: isDark ? '#93a1bd' : '#64748b',
      },
    },
    typography: {
      fontFamily: 'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      h3: { fontWeight: 800, letterSpacing: '-0.02em' },
      h4: { fontWeight: 800, letterSpacing: '-0.02em' },
      h5: { fontWeight: 700, letterSpacing: '-0.01em' },
      h6: { fontWeight: 700 },
      overline: { fontWeight: 700, letterSpacing: '0.14em' },
      button: { fontWeight: 600 },
    },
    shape: { borderRadius: 14 },
    components: {
      MuiButton: {
        defaultProps: { disableElevation: true },
        styleOverrides: {
          root: { textTransform: 'none', borderRadius: 12, paddingInline: 18 },
        },
      },
      MuiCard: {
        styleOverrides: {
          root: {
            borderRadius: 18,
            border: `1px solid ${isDark ? 'rgba(148,163,184,0.14)' : 'rgba(15,23,42,0.07)'}`,
            backgroundImage: 'none',
            boxShadow: isDark
              ? '0 10px 30px rgba(0,0,0,0.35)'
              : '0 12px 32px rgba(15,23,42,0.06)',
          },
        },
      },
      MuiChip: {
        styleOverrides: { root: { fontWeight: 600 } },
      },
      MuiPaper: { styleOverrides: { root: { backgroundImage: 'none' } } },
    },
  });
}

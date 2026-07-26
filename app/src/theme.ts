import { createTheme, type PaletteMode, type Theme } from '@mui/material';

const SANS = 'Inter, ui-sans-serif, system-ui, -apple-system, "Segoe UI", Roboto, sans-serif';
const DISPLAY = '"Plus Jakarta Sans", Inter, ui-sans-serif, system-ui, sans-serif';

/** One shared design system for the whole app (light + dark). */
export function buildTheme(mode: PaletteMode): Theme {
  const isDark = mode === 'dark';
  const border = isDark ? 'rgba(148,163,184,0.16)' : 'rgba(15,23,42,0.08)';
  return createTheme({
    palette: {
      mode,
      primary: { main: isDark ? '#818cf8' : '#4f46e5' },
      secondary: { main: '#0ea5e9' },
      success: { main: '#22c55e' },
      warning: { main: '#f59e0b' },
      error: { main: '#ef4444' },
      background: {
        default: isDark ? '#0a0e1a' : '#f7f8fc',
        paper: isDark ? '#0f1526' : '#ffffff',
      },
      divider: border,
      text: {
        primary: isDark ? '#eef2fb' : '#0f172a',
        secondary: isDark ? '#93a1bd' : '#64748b',
      },
    },
    typography: {
      fontFamily: SANS,
      h3: { fontFamily: DISPLAY, fontWeight: 800, letterSpacing: '-0.025em' },
      h4: { fontFamily: DISPLAY, fontWeight: 800, letterSpacing: '-0.025em' },
      h5: { fontFamily: DISPLAY, fontWeight: 800, letterSpacing: '-0.02em' },
      h6: { fontFamily: DISPLAY, fontWeight: 700, letterSpacing: '-0.01em' },
      subtitle1: { fontWeight: 600 },
      subtitle2: { fontWeight: 600 },
      overline: { fontWeight: 700, letterSpacing: '0.12em', fontSize: 11 },
      button: { fontWeight: 600 },
    },
    shape: { borderRadius: 14 },
    components: {
      MuiCssBaseline: {
        styleOverrides: {
          body: { WebkitFontSmoothing: 'antialiased', MozOsxFontSmoothing: 'grayscale' },
          '::selection': { background: isDark ? 'rgba(129,140,248,0.35)' : 'rgba(79,70,229,0.18)' },
        },
      },
      MuiButton: {
        defaultProps: { disableElevation: true },
        styleOverrides: {
          root: {
            textTransform: 'none', borderRadius: 10, paddingInline: 18, paddingBlock: 8,
            '&.MuiButton-containedPrimary': {
              background: isDark ? '#818cf8' : 'linear-gradient(180deg,#6366f1,#4f46e5)',
              boxShadow: '0 1px 2px rgba(79,70,229,0.35)',
            },
            '&.MuiButton-containedPrimary:hover': { boxShadow: '0 4px 14px rgba(79,70,229,0.4)' },
          },
        },
      },
      MuiCard: {
        styleOverrides: {
          root: {
            borderRadius: 16,
            border: `1px solid ${border}`,
            backgroundImage: 'none',
            boxShadow: isDark ? '0 1px 2px rgba(0,0,0,0.4)' : '0 1px 2px rgba(15,23,42,0.04)',
            transition: 'box-shadow .2s ease, transform .2s ease, border-color .2s ease',
          },
        },
      },
      MuiChip: {
        styleOverrides: {
          root: { fontWeight: 600, borderRadius: 8 },
          sizeSmall: { fontSize: 12, height: 24 },
          outlined: { borderColor: border },
        },
      },
      MuiLinearProgress: {
        styleOverrides: { root: { borderRadius: 99, backgroundColor: isDark ? 'rgba(148,163,184,0.15)' : 'rgba(15,23,42,0.06)' } },
      },
      MuiOutlinedInput: {
        styleOverrides: { root: { borderRadius: 10 } },
      },
      MuiDialog: {
        styleOverrides: { paper: { borderRadius: 18, border: `1px solid ${border}` } },
      },
      MuiPaper: { styleOverrides: { root: { backgroundImage: 'none' } } },
      MuiTooltip: {
        styleOverrides: { tooltip: { borderRadius: 8, fontSize: 12, fontWeight: 500 } },
      },
    },
  });
}

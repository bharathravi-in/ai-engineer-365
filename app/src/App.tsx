import { useEffect, useMemo, useState, type ReactElement } from 'react';
import {
  AppBar,
  Box,
  Chip,
  Container,
  CssBaseline,
  Divider,
  Drawer,
  IconButton,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Stack,
  ThemeProvider,
  Toolbar,
  Tooltip,
  Typography,
  useMediaQuery,
} from '@mui/material';
import DashboardIcon from '@mui/icons-material/Dashboard';
import EventNoteIcon from '@mui/icons-material/EventNote';
import CalendarMonthIcon from '@mui/icons-material/CalendarMonth';
import LibraryBooksIcon from '@mui/icons-material/LibraryBooks';
import NotesIcon from '@mui/icons-material/Notes';
import RocketLaunchIcon from '@mui/icons-material/RocketLaunch';
import AddCircleOutlineIcon from '@mui/icons-material/AddCircleOutlined';
import MenuIcon from '@mui/icons-material/Menu';
import DarkModeIcon from '@mui/icons-material/DarkModeOutlined';
import LightModeIcon from '@mui/icons-material/LightModeOutlined';
import AdminPanelSettingsIcon from '@mui/icons-material/AdminPanelSettings';
import AccountCircleIcon from '@mui/icons-material/AccountCircle';
import DashboardPage from './pages/DashboardPage';
import PlannerPage from './pages/PlannerPage';
import MonthsPage from './pages/MonthsPage';
import ResourceLibraryPage from './pages/ResourceLibraryPage';
import NotesPage from './pages/NotesPage';
import ProjectsPage from './pages/ProjectsPage';
import PlannerEditorPage from './pages/PlannerEditorPage';
import AdminPage from './pages/AdminPage';
import LoginPage from './pages/LoginPage';
import { buildTheme } from './theme';
import { useDashboardStore, useIsAdmin } from './store';

const drawerWidth = 264;

type RouteId =
  | 'dashboard'
  | 'planner'
  | 'months'
  | 'add'
  | 'resources'
  | 'notes'
  | 'projects'
  | 'admin'
  | 'account';

type Section = { id: RouteId; label: string; icon: ReactElement };

const baseSections: Section[] = [
  { id: 'dashboard', label: 'Dashboard', icon: <DashboardIcon /> },
  { id: 'planner', label: 'Daily Planner', icon: <EventNoteIcon /> },
  { id: 'months', label: 'Months', icon: <CalendarMonthIcon /> },
  { id: 'resources', label: 'Resources', icon: <LibraryBooksIcon /> },
  { id: 'notes', label: 'Notes', icon: <NotesIcon /> },
  { id: 'projects', label: 'Projects', icon: <RocketLaunchIcon /> },
  { id: 'add', label: 'Add Entry (JSON)', icon: <AddCircleOutlineIcon /> },
];

const allRouteIds: RouteId[] = [...baseSections.map((s) => s.id), 'admin', 'account'];

function currentRoute(): RouteId {
  const hash = window.location.hash.replace('#', '') as RouteId;
  return allRouteIds.includes(hash) ? hash : 'dashboard';
}

function Page({ route }: { route: RouteId }) {
  switch (route) {
    case 'planner':
      return <PlannerPage />;
    case 'months':
      return <MonthsPage />;
    case 'add':
      return <PlannerEditorPage />;
    case 'resources':
      return <ResourceLibraryPage />;
    case 'notes':
      return <NotesPage />;
    case 'projects':
      return <ProjectsPage />;
    case 'admin':
      return <AdminPage />;
    case 'account':
      return <LoginPage />;
    default:
      return <DashboardPage />;
  }
}

function App() {
  const mode = useDashboardStore((state) => state.themeMode);
  const toggleTheme = useDashboardStore((state) => state.toggleTheme);
  const initApp = useDashboardStore((state) => state.initApp);
  const supabaseEnabled = useDashboardStore((state) => state.supabaseEnabled);
  const user = useDashboardStore((state) => state.user);
  const isAdmin = useIsAdmin();
  const theme = useMemo(() => buildTheme(mode), [mode]);
  const [route, setRoute] = useState<RouteId>(currentRoute());
  const [mobileOpen, setMobileOpen] = useState(false);
  const isDesktop = useMediaQuery(theme.breakpoints.up('md'));

  useEffect(() => {
    void initApp();
  }, [initApp]);

  const sections = useMemo<Section[]>(() => {
    // The local JSON editor ("Add Entry") is offline-only; when Supabase is on,
    // content is authored in the DB-backed Admin panel instead.
    const list = baseSections.filter((s) => !(supabaseEnabled && s.id === 'add'));
    if (isAdmin) list.push({ id: 'admin', label: 'Admin', icon: <AdminPanelSettingsIcon /> });
    if (supabaseEnabled) {
      list.push({ id: 'account', label: user ? 'Account' : 'Sign in', icon: <AccountCircleIcon /> });
    }
    return list;
  }, [isAdmin, supabaseEnabled, user]);

  useEffect(() => {
    const onHash = () => {
      setRoute(currentRoute());
      setMobileOpen(false);
      window.scrollTo({ top: 0 });
    };
    window.addEventListener('hashchange', onHash);
    return () => window.removeEventListener('hashchange', onHash);
  }, []);

  const drawer = (
    <Box
      sx={{
        height: '100%',
        color: '#e6ebf5',
        background: 'linear-gradient(180deg, #4338ca 0%, #4f46e5 42%, #6d28d9 100%)',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      <Box sx={{ px: 3, py: 3.5 }}>
        <Stack direction="row" spacing={1.2} sx={{ alignItems: 'center' }}>
          <Box
            sx={{
              width: 38,
              height: 38,
              borderRadius: 2,
              display: 'grid',
              placeItems: 'center',
              fontSize: 20,
              background: 'rgba(255,255,255,0.16)',
            }}
          >
            🚀
          </Box>
          <Box>
            <Typography variant="h6" sx={{ lineHeight: 1.1 }}>
              AI Engineer 365
            </Typography>
            <Typography variant="caption" sx={{ opacity: 0.8 }}>
              Learning Management
            </Typography>
          </Box>
        </Stack>
      </Box>
      <Divider sx={{ borderColor: 'rgba(255,255,255,0.14)' }} />
      <List sx={{ px: 1.5, py: 2, flexGrow: 1 }}>
        {sections.map((section) => {
          const active = route === section.id;
          return (
            <ListItemButton
              key={section.id}
              component="a"
              href={`#${section.id}`}
              selected={active}
              sx={{
                borderRadius: 2.5,
                mb: 0.5,
                color: active ? '#fff' : 'rgba(255,255,255,0.82)',
                background: active ? 'rgba(255,255,255,0.18)' : 'transparent',
                '&:hover': { background: 'rgba(255,255,255,0.12)' },
                '&.Mui-selected, &.Mui-selected:hover': { background: 'rgba(255,255,255,0.2)' },
              }}
            >
              <ListItemIcon sx={{ color: 'inherit', minWidth: 40 }}>{section.icon}</ListItemIcon>
              <ListItemText primary={section.label} sx={{ '& .MuiListItemText-primary': { fontWeight: active ? 700 : 500 } }} />
            </ListItemButton>
          );
        })}
      </List>
      <Box sx={{ px: 3, pb: 3 }}>
        <Chip
          label="365-day roadmap"
          size="small"
          sx={{ background: 'rgba(255,255,255,0.16)', color: '#fff', mb: 1.5 }}
        />
        <Typography variant="caption" sx={{ opacity: 0.75, display: 'block' }}>
          12 months · 12 projects · one portfolio.
        </Typography>
      </Box>
    </Box>
  );

  const activeLabel = sections.find((s) => s.id === route)?.label ?? 'Dashboard';

  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <Box sx={{ display: 'flex', minHeight: '100vh', bgcolor: 'background.default' }}>
        {/* Top bar: theme toggle everywhere, menu button on mobile */}
        <AppBar
          position="fixed"
          elevation={0}
          color="transparent"
          sx={{
            width: { md: `calc(100% - ${drawerWidth}px)` },
            ml: { md: `${drawerWidth}px` },
            backdropFilter: 'blur(8px)',
            borderBottom: 1,
            borderColor: 'divider',
            bgcolor: (t) => (t.palette.mode === 'dark' ? 'rgba(11,16,32,0.72)' : 'rgba(245,246,251,0.72)'),
          }}
        >
          <Toolbar sx={{ gap: 1 }}>
            {!isDesktop && (
              <IconButton edge="start" onClick={() => setMobileOpen(true)}>
                <MenuIcon />
              </IconButton>
            )}
            <Typography variant="subtitle1" sx={{ fontWeight: 700, flexGrow: 1 }}>
              {activeLabel}
            </Typography>
            <Tooltip title={mode === 'dark' ? 'Switch to light' : 'Switch to dark'}>
              <IconButton onClick={toggleTheme}>{mode === 'dark' ? <LightModeIcon /> : <DarkModeIcon />}</IconButton>
            </Tooltip>
          </Toolbar>
        </AppBar>

        <Box component="nav" sx={{ width: { md: drawerWidth }, flexShrink: { md: 0 } }}>
          <Drawer
            variant={isDesktop ? 'permanent' : 'temporary'}
            open={isDesktop ? true : mobileOpen}
            onClose={() => setMobileOpen(false)}
            ModalProps={{ keepMounted: true }}
            sx={{
              '& .MuiDrawer-paper': { width: drawerWidth, border: 0, boxSizing: 'border-box' },
            }}
          >
            {drawer}
          </Drawer>
        </Box>

        <Box component="main" sx={{ flexGrow: 1, width: { md: `calc(100% - ${drawerWidth}px)` } }}>
          <Toolbar />
          <Container maxWidth="xl" sx={{ py: 4 }}>
            <Page route={route} />
          </Container>
        </Box>
      </Box>
    </ThemeProvider>
  );
}

export default App;

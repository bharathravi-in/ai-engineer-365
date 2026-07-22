import { Box, Container, Divider, Drawer, List, ListItemButton, ListItemIcon, ListItemText, Toolbar, Typography } from '@mui/material';
import DashboardIcon from '@mui/icons-material/Dashboard';
import EventNoteIcon from '@mui/icons-material/EventNote';
import LibraryBooksIcon from '@mui/icons-material/LibraryBooks';
import NotesIcon from '@mui/icons-material/Notes';
import RocketLaunchIcon from '@mui/icons-material/RocketLaunch';
import DashboardPage from './pages/DashboardPage';
import PlannerPage from './pages/PlannerPage';
import ResourceLibraryPage from './pages/ResourceLibraryPage';
import NotesPage from './pages/NotesPage';
import ProjectsPage from './pages/ProjectsPage';

const drawerWidth = 280;
const sections = [
  { id: 'dashboard', label: 'Dashboard', icon: <DashboardIcon /> },
  { id: 'planner', label: 'Daily Planner', icon: <EventNoteIcon /> },
  { id: 'resources', label: 'Resources', icon: <LibraryBooksIcon /> },
  { id: 'notes', label: 'Notes', icon: <NotesIcon /> },
  { id: 'projects', label: 'Projects', icon: <RocketLaunchIcon /> },
];

function App() {
  return (
    <Box sx={{ display: 'flex' }}>
      <Drawer variant="permanent" sx={{ width: drawerWidth, flexShrink: 0, '& .MuiDrawer-paper': { width: drawerWidth, border: 0 } }}>
        <Toolbar sx={{ alignItems: 'flex-start', flexDirection: 'column', gap: 0.5, py: 3 }}>
          <Typography variant="h5">AI Engineer 365</Typography>
          <Typography variant="body2" color="text.secondary">Learning Management Dashboard</Typography>
        </Toolbar>
        <Divider />
        <List sx={{ px: 2 }}>
          {sections.map((section) => (
            <ListItemButton key={section.id} component="a" href={`#${section.id}`} sx={{ borderRadius: 3, mb: 1 }}>
              <ListItemIcon>{section.icon}</ListItemIcon>
              <ListItemText primary={section.label} />
            </ListItemButton>
          ))}
        </List>
      </Drawer>
      <Box component="main" sx={{ flexGrow: 1, minHeight: '100vh', ml: `${drawerWidth}px` }}>
        <Container maxWidth="xl" sx={{ py: 4 }}>
          <DashboardPage />
          <PlannerPage />
          <ResourceLibraryPage />
          <NotesPage />
          <ProjectsPage />
        </Container>
      </Box>
    </Box>
  );
}

export default App;

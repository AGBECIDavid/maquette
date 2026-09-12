import { Navigate, Route, Routes } from 'react-router-dom';
import { AppShell } from './ui/layout/AppShell';
import { DashboardPage } from './ui/pages/DashboardPage';
import { RoadblocksPage } from './ui/pages/RoadblocksPage';
import { RoadblockDetailPage } from './ui/pages/RoadblockDetailPage';
import { ModulesPage } from './ui/pages/ModulesPage';
import { ModuleDetailPage } from './ui/pages/ModuleDetailPage';
import { ProjectsPage } from './ui/pages/ProjectsPage';
import { ProjectDetailPage } from './ui/pages/ProjectDetailPage';
import { CalendarPage } from './ui/pages/CalendarPage';
import { StatsPage } from './ui/pages/StatsPage';
import { SettingsPage } from './ui/pages/SettingsPage';

export function App() {
  return (
    <AppShell>
      <Routes>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/roadblocks" element={<RoadblocksPage />} />
        <Route path="/roadblocks/:id" element={<RoadblockDetailPage />} />
        <Route path="/modules" element={<ModulesPage />} />
        <Route path="/modules/:id" element={<ModuleDetailPage />} />
        <Route path="/projects" element={<ProjectsPage />} />
        <Route path="/projects/:id" element={<ProjectDetailPage />} />
        <Route path="/calendrier" element={<CalendarPage />} />
        <Route path="/statistiques" element={<StatsPage />} />
        <Route path="/parametres" element={<SettingsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppShell>
  );
}

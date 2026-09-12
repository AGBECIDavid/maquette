import { useCallback, useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { useSession } from './store/SessionContext';
import { CurriculumProvider } from './store/CurriculumContext';
import { AppShell } from './ui/layout/AppShell';
import { SplashScreen, SPLASH_SESSION_KEY } from './ui/pages/SplashScreen';
import { WelcomePage } from './ui/pages/WelcomePage';
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

/** L'ouverture n'est jouée qu'une fois par session, pas à chaque navigation. */
function splashAlreadySeen(): boolean {
  try {
    return window.sessionStorage.getItem(SPLASH_SESSION_KEY) === '1';
  } catch {
    return false;
  }
}

export function App() {
  const { activeProfile } = useSession();
  const [splashDone, setSplashDone] = useState(splashAlreadySeen);

  const finishSplash = useCallback(() => {
    try {
      window.sessionStorage.setItem(SPLASH_SESSION_KEY, '1');
    } catch {
      /* stockage indisponible : l'animation se rejouera, sans plus */
    }
    setSplashDone(true);
  }, []);

  if (!splashDone) return <SplashScreen onDone={finishSplash} />;
  if (activeProfile === null) return <WelcomePage />;

  return (
    // `key` sur le profil : changer de profil remonte tout l'arbre de données
    // plutôt que de laisser un état résiduel s'afficher le temps d'un rendu.
    <CurriculumProvider key={activeProfile.id} profileId={activeProfile.id}>
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
    </CurriculumProvider>
  );
}

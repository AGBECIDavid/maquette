import { useCallback, useEffect, useState } from 'react';
import { Navigate, Route, Routes } from 'react-router-dom';
import { useSession } from './store/SessionContext';
import { CurriculumProvider } from './store/CurriculumContext';
import { AppShell } from './ui/layout/AppShell';
import { SplashScreen, SPLASH_SESSION_KEY } from './ui/pages/SplashScreen';
import { LandingPage } from './ui/pages/LandingPage';
import { SignUpPage } from './ui/pages/SignUpPage';
import { SignInPage } from './ui/pages/SignInPage';
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

/** Les trois temps de l'arrivée, avant l'application elle-même. */
type Entry = 'landing' | 'signup' | 'signin';

export function App() {
  const { activeProfile, profiles } = useSession();
  const [splashDone, setSplashDone] = useState(splashAlreadySeen);
  const [entry, setEntry] = useState<Entry>('landing');

  /*
   * À la déconnexion, on repart de l'écran utile plutôt que du dernier
   * visité : quelqu'un qui quitte son profil veut en reprendre un autre, pas
   * retrouver le formulaire d'inscription qu'il a rempli tout à l'heure.
   *
   * Dépendre du seul `activeProfile` est volontaire : naviguer entre accueil,
   * inscription et connexion ne doit pas réinitialiser ce choix.
   */
  useEffect(() => {
    if (activeProfile === null) {
      setEntry(profiles.length > 0 ? 'signin' : 'landing');
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeProfile]);

  const finishSplash = useCallback(() => {
    try {
      window.sessionStorage.setItem(SPLASH_SESSION_KEY, '1');
    } catch {
      /* stockage indisponible : l'animation se rejouera, sans plus */
    }
    setSplashDone(true);
  }, []);

  if (!splashDone) return <SplashScreen onDone={finishSplash} />;

  if (activeProfile === null) {
    switch (entry) {
      case 'signup':
        return <SignUpPage onBack={() => setEntry('landing')} onSignIn={() => setEntry('signin')} />;
      case 'signin':
        return <SignInPage onBack={() => setEntry('landing')} onSignUp={() => setEntry('signup')} />;
      case 'landing':
        return (
          <LandingPage
            hasProfiles={profiles.length > 0}
            onSignUp={() => setEntry('signup')}
            onSignIn={() => setEntry('signin')}
          />
        );
    }
  }

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

import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { HashRouter } from 'react-router-dom';
import { App } from './App';
import { SessionProvider } from './store/SessionContext';
import { installBackButton, registerServiceWorker } from './platform';
import './index.css';

registerServiceWorker();
void installBackButton();

const root = document.getElementById('root');
if (root === null) throw new Error('Élément #root introuvable');

createRoot(root).render(
  <StrictMode>
    {/* HashRouter : l'app se sert depuis n'importe quel dossier, sans
        configuration serveur pour les routes profondes. */}
    <HashRouter>
      <SessionProvider>
        <App />
      </SessionProvider>
    </HashRouter>
  </StrictMode>,
);

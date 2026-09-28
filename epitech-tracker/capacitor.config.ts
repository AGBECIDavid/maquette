import type { CapacitorConfig } from '@capacitor/cli';

/**
 * Application Android, construite à partir du même `dist/` que le site.
 *
 * L'identifiant s'appuie sur le domaine GitHub du projet, pas sur celui
 * d'Epitech : un identifiant d'application ne doit jamais emprunter un
 * domaine qu'on ne possède pas. Il ne pourra plus changer une fois l'APK
 * distribué — le changer, c'est publier une autre application, que les
 * téléphones installeront à côté de la première sans reprendre ses données.
 */
const config: CapacitorConfig = {
  appId: 'io.github.agbecidavid.epitechtracker',
  appName: 'Epitech Tracker',
  webDir: 'dist',

  android: {
    // Couleur affichée derrière la WebView pendant son chargement : sans
    // elle, un éclair blanc précède l'écran d'ouverture.
    backgroundColor: '#0B1220',
  },

  plugins: {
    SystemBars: {
      // Injecte les marges de l'encoche en variables CSS, y compris sur les
      // WebView anciennes où `env(safe-area-inset-*)` vaut zéro.
      insetsHandling: 'css',
      initialViewportFitValueHint: 'cover',
      // DARK = icônes CLAIRES sur fond sombre. La valeur par défaut suivrait
      // le thème du téléphone : en mode clair, elle afficherait des icônes
      // noires sur notre fond #0B1220, donc invisibles.
      style: 'DARK',
    },
  },
};

export default config;

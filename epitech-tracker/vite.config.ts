import { defineConfig } from 'vitest/config';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

export default defineConfig({
  /*
   * Chemins relatifs : le même build fonctionne à la racine d'un domaine
   * comme dans un sous-dossier (github.io/maquette/). Combiné au HashRouter,
   * il n'y a aucune règle de réécriture d'URL à configurer côté serveur —
   * n'importe quel hébergement statique suffit.
   */
  base: './',

  plugins: [react(), tailwindcss()],
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
});

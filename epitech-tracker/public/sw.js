/*
 * Service worker d'Epitech Tracker — ce qui rend l'application utilisable
 * hors ligne une fois installée.
 *
 * Deux règles, choisies pour qu'une mise à jour ne reste jamais bloquée :
 *
 *   - La page d'entrée passe par le RÉSEAU D'ABORD. Un nouveau déploiement
 *     est donc pris au lancement suivant ; hors ligne, on sert la dernière
 *     copie connue. Un « cache d'abord » ici figerait l'application sur sa
 *     première version, sans moyen pour l'utilisateur d'en sortir.
 *   - Les fichiers de `assets/` passent par le CACHE D'ABORD. Vite leur donne
 *     un nom qui change à chaque build : un fichier en cache ne peut pas être
 *     périmé, il est seulement ancien — et plus personne ne le demande.
 *
 * Les requêtes vers d'autres domaines (GitHub, signalements) ne sont jamais
 * interceptées.
 */

const CACHE = 'epitech-tracker-v1';
const INDEX = new URL('./', self.registration.scope).href;

/**
 * À l'installation, on met en cache la page et les fichiers qu'elle charge.
 * Sans cela, la première visite se fait avant que le service worker ne
 * contrôle la page : rien ne serait en cache, et l'application ne
 * démarrerait pas hors ligne avant une seconde visite.
 */
self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(CACHE);
      const response = await fetch(INDEX, { cache: 'no-cache' });
      if (!response.ok) return;
      const html = await response.clone().text();
      await cache.put(INDEX, response);
      const assets = [...html.matchAll(/(?:src|href)="(\.?\/?assets\/[^"]+)"/g)].map(
        (match) => new URL(match[1], INDEX).href,
      );
      await cache.addAll(assets);
    })(),
  );
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const keys = await caches.keys();
      await Promise.all(
        keys
          .filter((key) => key.startsWith('epitech-tracker-') && key !== CACHE)
          .map((key) => caches.delete(key)),
      );
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin) return;

  if (request.mode === 'navigate') {
    event.respondWith(
      (async () => {
        try {
          const response = await fetch(request);
          if (response.ok) {
            const cache = await caches.open(CACHE);
            await cache.put(INDEX, response.clone());
          }
          return response;
        } catch {
          return (await caches.match(INDEX)) ?? Response.error();
        }
      })(),
    );
    return;
  }

  if (url.pathname.includes('/assets/') || url.pathname.includes('/icons/')) {
    event.respondWith(
      (async () => {
        const cached = await caches.match(request);
        if (cached) return cached;
        const response = await fetch(request);
        if (response.ok) {
          const cache = await caches.open(CACHE);
          await cache.put(request, response.clone());
        }
        return response;
      })(),
    );
  }
});

/**
 * Différences entre le site et l'application Android.
 *
 * Trois choses marchent dans un navigateur et cassent dans la WebView d'un
 * APK. Elles sont traitées ici, et seulement ici :
 *
 *   1. ENREGISTRER UN FICHIER. Un lien `download` vers un blob ne fait rien
 *      dans une WebView Android. Or l'export JSON est le SEUL moyen de
 *      sauvegarder son cursus : le perdre silencieusement serait le pire
 *      défaut possible de l'application. Dans l'APK, le fichier est écrit
 *      puis confié au partage Android (Drive, mail, Fichiers…).
 *   2. OUVRIR UN LIEN EXTERNE. `target="_blank"` est ignoré par la WebView :
 *      le lien ne s'ouvrirait nulle part. On passe par le navigateur système.
 *   3. LE BOUTON RETOUR. Par défaut il fermerait l'application depuis
 *      n'importe quel écran. Il remonte l'historique, et ne quitte qu'une
 *      fois revenu au début.
 */

import { Capacitor } from '@capacitor/core';

export function isNative(): boolean {
  return Capacitor.isNativePlatform();
}

/** Enregistre un fichier texte : téléchargement sur le web, partage sur Android. */
export async function saveTextFile(content: string, filename: string): Promise<void> {
  if (!isNative()) {
    const blob = new Blob([content], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = filename;
    link.click();
    URL.revokeObjectURL(url);
    return;
  }

  // Import différé : ces modules n'ont rien à faire dans le bundle du site.
  const { Filesystem, Directory, Encoding } = await import('@capacitor/filesystem');
  const { Share } = await import('@capacitor/share');

  // Le cache suffit : le fichier ne sert qu'à être transmis au partage, et
  // Android le nettoie de lui-même. Aucune permission de stockage requise.
  const written = await Filesystem.writeFile({
    path: filename,
    data: content,
    directory: Directory.Cache,
    encoding: Encoding.UTF8,
  });
  await Share.share({ title: filename, files: [written.uri], dialogTitle: 'Enregistrer ou envoyer' });
}

/** Ouvre une adresse externe dans le navigateur, jamais dans l'application. */
export async function openExternal(url: string): Promise<void> {
  if (!isNative()) {
    window.open(url, '_blank', 'noopener,noreferrer');
    return;
  }
  const { Browser } = await import('@capacitor/browser');
  await Browser.open({ url });
}

/** Bouton retour Android : remonter l'historique, ne quitter qu'au début. */
export async function installBackButton(): Promise<void> {
  if (!isNative()) return;
  const { App } = await import('@capacitor/app');
  await App.addListener('backButton', ({ canGoBack }) => {
    if (canGoBack) window.history.back();
    else void App.exitApp();
  });
}

/**
 * Service worker : uniquement sur le site en production. Dans l'APK les
 * fichiers sont déjà sur le téléphone, et en développement il servirait des
 * versions périmées pendant qu'on modifie le code.
 */
export function registerServiceWorker(): void {
  if (isNative() || !import.meta.env.PROD || !('serviceWorker' in navigator)) return;
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js').catch((error: unknown) => {
      console.warn('Service worker non installé :', error);
    });
  });
}

/**
 * Points de contact du projet.
 *
 * Rassemblés ici pour qu'un changement d'adresse ne demande pas de fouiller
 * l'interface. Si tu préfères un formulaire (Google Forms, Tally…) aux
 * issues GitHub, remplace `FEEDBACK_URL` : c'est le seul endroit à toucher.
 */

export const REPO_URL = 'https://github.com/AGBECIDavid/maquette';

/** Où un bêta-testeur signale un problème. */
export const FEEDBACK_URL = `${REPO_URL}/issues/new`;

/**
 * Pré-remplit le signalement avec ce que le testeur ne pensera pas à donner :
 * version, navigateur, taille d'écran. Un bug sans ces trois lignes se cherche
 * à l'aveugle.
 */
export function feedbackLink(version: string, stage: string): string {
  const body = [
    '## Ce que j’ai fait',
    '',
    '',
    '## Ce que j’attendais',
    '',
    '',
    '## Ce qui s’est passé',
    '',
    '',
    '---',
    `- Version : ${version} (${stage})`,
    `- Navigateur : ${navigator.userAgent}`,
    `- Écran : ${window.screen.width}×${window.screen.height}`,
    '',
    "> Pense à joindre le fichier de diagnostic (Paramètres → Exporter un diagnostic)",
    '> si le problème touche tes données. Relis-le avant : il contient ton cursus.',
  ].join('\n');

  return `${FEEDBACK_URL}?title=${encodeURIComponent('[bêta] ')}&body=${encodeURIComponent(body)}`;
}

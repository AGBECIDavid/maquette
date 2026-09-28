import type { ReactNode } from 'react';
import { openExternal } from '../../platform';

/**
 * Lien vers l'extérieur de l'application.
 *
 * Dans l'APK, `target="_blank"` est ignoré par la WebView : le lien ne
 * s'ouvrirait nulle part. On intercepte le clic et on passe par le
 * navigateur du téléphone. Sur le site, le comportement reste celui d'un
 * lien ordinaire — clic du milieu et « ouvrir dans un onglet » compris.
 */
export function ExternalLink({
  href,
  className = '',
  children,
}: {
  href: string;
  className?: string;
  children: ReactNode;
}) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noreferrer noopener"
      className={className}
      onClick={(event) => {
        event.preventDefault();
        void openExternal(href);
      }}
    >
      {children}
    </a>
  );
}

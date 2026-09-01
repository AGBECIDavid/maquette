import "./globals.css";
import { Providers } from "./providers.jsx";

/* §4.1 — la mention de simulation figure jusque dans le titre de l'onglet.
   Le gabarit l'ajoute à chaque page, y compris à celles qui ne déclarent rien. */
export const metadata = {
  title: {
    default: "CartePro (simulation) — Ministère du Job et Bonheur",
    template: "%s — CartePro (simulation)"
  },
  description: "Démonstrateur du dispositif CartePro : simulation fonctionnelle, aucune valeur réelle ne circule.",
  applicationName: "CartePro"
};

export const viewport = { width: "device-width", initialScale: 1, themeColor: "#000091" };

export default function RootLayout({ children }) {
  return (
    <html lang="fr">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="anonymous" />
        <link rel="stylesheet"
              href="https://fonts.googleapis.com/css2?family=Public+Sans:wght@400;500;600;700&family=Spectral:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500;600&display=swap" />
      </head>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}

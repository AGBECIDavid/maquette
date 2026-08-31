import "./globals.css";
import { Providers } from "./providers.jsx";

export const metadata = {
  title: "CartePro — Ministère du Job et Bonheur",
  description: "Démonstrateur du dispositif CartePro : espaces salarié, partenaire et administration.",
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
              href="https://fonts.googleapis.com/css2?family=Public+Sans:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500;600&display=swap" />
      </head>
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}

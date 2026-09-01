/* Jeu d'icônes au trait, dessiné à la main sur une grille 24 — aucune
   dépendance, et la taille suit celle du texte (1em) sauf classe explicite. */

export const PATHS = {
  home:    "M3 10.2 12 3l9 7.2V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z",
  qr:      "M3 4a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1zM14 4a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1zM3 15a1 1 0 0 1 1-1h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1zM14 14h3v3h-3zM20 14h1M14 20h3M20 17v4",
  clock:   "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0M12 7v5l3 2",
  pin:     "M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0M15 10a3 3 0 1 1-6 0 3 3 0 0 1 6 0",
  store:   "M3 9V6a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v3M3 9l1.5 3h15L21 9M4.5 12v8a1 1 0 0 0 1 1h13a1 1 0 0 0 1-1v-8M9 21v-5h6v5",
  wallet:  "M3 7a2 2 0 0 1 2-2h13a1 1 0 0 1 1 1v2M3 7v11a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-3M21 9v6h-4a3 3 0 0 1 0-6z",
  users:   "M16 20v-1a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v1M13 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0M22 20v-1a4 4 0 0 0-3-3.9M16 3.1a4 4 0 0 1 0 7.8",
  shield:  "M12 22s8-3.5 8-10V5l-8-3-8 3v7c0 6.5 8 10 8 10m-3-10 2 2 4-4",
  check:   "m4 12 5.5 5.5L20 7",
  x:       "M18 6 6 18M6 6l12 12",
  alert:   "M12 9v5M12 17.5h.01M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0",
  info:    "M21 12a9 9 0 1 1-18 0 9 9 0 0 1 18 0M12 16v-5M12 8h.01",
  up:      "M7 17 17 7M9 7h8v8",
  down:    "M17 7 7 17M15 17H7V9",
  card:    "M2 7a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2zM2 10h20",
  search:  "M18 11a7 7 0 1 1-14 0 7 7 0 0 1 14 0m2 9-3.5-3.5",
  plus:    "M12 5v14M5 12h14",
  copy:    "M9 9a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2h-8a2 2 0 0 1-2-2zM5 15H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v1",
  dl:      "M12 3v12M7.5 10.5 12 15l4.5-4.5M4 20h16",
  refresh: "M3 12a9 9 0 0 1 15.3-6.4L21 8M21 3v5h-5M21 12a9 9 0 0 1-15.3 6.4L3 16M3 21v-5h5",
  chart:   "M4 20V10M10 20V4M16 20v-7M22 20H2",
  build:   "M4 4a1 1 0 0 1 1-1h14a1 1 0 0 1 1 1v17H4zM9 7h2M13 7h2M9 11h2M13 11h2M9 15h2M13 15h2",
  list:    "M8 6h13M8 12h13M8 18h13M3.5 6h.01M3.5 12h.01M3.5 18h.01",
  key:     "M12 15.5a4.5 4.5 0 1 1-9 0 4.5 4.5 0 0 1 9 0m-1.2-3.3 8-8M17 6l2 2M14.5 8.5l2 2",
  scan:    "M3 8V5a2 2 0 0 1 2-2h3M16 3h3a2 2 0 0 1 2 2v3M21 16v3a2 2 0 0 1-2 2h-3M8 21H5a2 2 0 0 1-2-2v-3M7 12h10",
  left:    "m14 6-6 6 6 6",
  right:   "m10 6 6 6-6 6",
  out:     "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4m7 14 5-5-5-5m5 5H9",
  ticket:  "M3 9V6a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v3a3 3 0 0 0 0 6v3a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-3a3 3 0 0 0 0-6M14 5v14",
  eye:     "M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7m13 0a3 3 0 1 1-6 0 3 3 0 0 1 6 0",
  offline: "m2 2 20 20M8.5 16.4a5 5 0 0 1 7 0M5 12.9a10 10 0 0 1 3-2M19.9 12.9a10 10 0 0 0-4.1-2.5M12 20h.01",
  lock:    "M4 12a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v7a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2zM8 10V7a4 4 0 0 1 8 0v3",
  mail:    "M2 7a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2zm0 .5 10 6.5 10-6.5",
  chat:    "M21 12a8 8 0 0 1-8 8H8l-5 3 1.2-4.2A8 8 0 0 1 13 4a8 8 0 0 1 8 8",
  phone:   "M7 2h10a1 1 0 0 1 1 1v18a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1V3a1 1 0 0 1 1-1m3 18h4",
  tablet:  "M5 3h14a1 1 0 0 1 1 1v16a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1m6 15h2",
  desktop: "M3 5a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1zM8 20h8M12 16v4",
  spark:   "M12 2 14.6 8.4 21 11l-6.4 2.6L12 20l-2.6-6.4L3 11l6.4-2.6z",
  arrow:   "M5 12h14m-6-7 7 7-7 7",
  user:    "M20 21v-1a5 5 0 0 0-5-5H9a5 5 0 0 0-5 5v1M16 7a4 4 0 1 1-8 0 4 4 0 0 1 8 0",
  bell:    "M18 9a6 6 0 1 0-12 0c0 5-2 6-2 6h16s-2-1-2-6M13.7 21a2 2 0 0 1-3.4 0"
};

export function Icon({ name, className, size, style }) {
  const d = PATHS[name];
  if (!d) return null;
  return (
    <svg viewBox="0 0 24 24" width={size || "1em"} height={size || "1em"}
         fill="none" stroke="currentColor" strokeWidth="1.8"
         strokeLinecap="round" strokeLinejoin="round"
         className={className} style={style} aria-hidden="true" focusable="false">
      <path d={d} />
    </svg>
  );
}

/* Formats français, empreintes, petits utilitaires sans dépendance. */

export const eur = (c, opts) => (c / 100).toLocaleString("fr-FR",
  Object.assign({ style: "currency", currency: "EUR" }, opts || {}));
export const eurShort = c => (c / 100).toLocaleString("fr-FR",
  { style: "currency", currency: "EUR", maximumFractionDigits: 0 });
export const nfr = n => Number(n).toLocaleString("fr-FR");

export const pad = n => String(n).padStart(2, "0");

const JOURS = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"];
export const MOIS = ["janv.", "févr.", "mars", "avr.", "mai", "juin",
                     "juil.", "août", "sept.", "oct.", "nov.", "déc."];

export function dateFR(ts, withTime) {
  const d = new Date(ts);
  const s = d.getDate() + " " + MOIS[d.getMonth()] + " " + d.getFullYear();
  return withTime ? s + " à " + pad(d.getHours()) + ":" + pad(d.getMinutes()) : s;
}
export function heureFR(ts) {
  const d = new Date(ts);
  return pad(d.getHours()) + ":" + pad(d.getMinutes());
}
export function jourRelatif(ts) {
  const d = new Date(ts), n = new Date();
  const j0 = new Date(n.getFullYear(), n.getMonth(), n.getDate()).getTime();
  const dj = Math.round((j0 - new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime()) / 864e5);
  if (dj === 0) return "Aujourd'hui";
  if (dj === 1) return "Hier";
  if (dj < 7) return JOURS[d.getDay()].charAt(0).toUpperCase() + JOURS[d.getDay()].slice(1);
  return dateFR(ts);
}
export function ilYA(ts) {
  const m = Math.round((Date.now() - ts) / 60000);
  if (m < 1) return "à l'instant";
  if (m < 60) return "il y a " + m + " min";
  const h = Math.round(m / 60);
  if (h < 24) return "il y a " + h + " h";
  return dateFR(ts);
}

export const uid = (n = 8) => Array.from({ length: n },
  () => "0123456789abcdef"[Math.floor(Math.random() * 16)]).join("");

export const initiales = name => String(name).split(" ")
  .map(w => w[0]).filter(Boolean).slice(0, 2).join("").toUpperCase();

/* Empreinte FNV-1a 32 bits. Elle chaîne les transactions entre elles (§3.2) :
   ce n'est pas de la cryptographie, c'est la démonstration du principe
   d'inaltérabilité. En production : SHA-256 et journal append-only. */
export function fnv1a(str) {
  let h = 0x811c9dc5;
  for (let i = 0; i < str.length; i++) {
    h ^= str.charCodeAt(i);
    h = (h + ((h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24))) >>> 0;
  }
  return h.toString(16).padStart(8, "0");
}

/* Saisie « 12,40 » ou « 12.40 » → 1240 centimes. Null si invalide. */
export function centimes(saisie) {
  const v = parseFloat(String(saisie).replace(/\s/g, "").replace(",", "."));
  if (!isFinite(v) || v <= 0) return null;
  return Math.round(v * 100);
}

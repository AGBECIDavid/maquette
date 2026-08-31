/* ============================================================================
   Modèle de données et jeu de démonstration.

   Le schéma reproduit celui d'une base relationnelle — employeurs, salariés,
   partenaires, transactions, rechargements, jetons, réclamations — pour que le
   passage à un vrai backend soit une transposition, pas une réécriture.
   ========================================================================= */

import { fnv1a } from "./format.js";

export const CATEGORIES = [
  { id: "restauration", label: "Restauration", ico: "store" },
  { id: "boulangerie",  label: "Boulangerie",  ico: "store" },
  { id: "alimentation", label: "Alimentation", ico: "store" },
  { id: "culture",      label: "Culture",      ico: "ticket" },
  { id: "sport",        label: "Sport",        ico: "chart" },
  { id: "bienetre",     label: "Bien-être",    ico: "users" },
  { id: "transport",    label: "Transport",    ico: "pin" }
];
export const catLabel = id => (CATEGORIES.find(c => c.id === id) || { label: id }).label;
export const catIco   = id => (CATEGORIES.find(c => c.id === id) || { ico: "store" }).ico;

export const REGIONS = ["Île-de-France", "Auvergne-Rhône-Alpes", "Provence-Alpes-Côte d'Azur",
  "Hauts-de-France", "Nouvelle-Aquitaine", "Occitanie", "Pays de la Loire", "Grand Est"];

export const STATUS = {
  active:    { label: "Actif",        pill: "pill--good" },
  pending:   { label: "En attente",   pill: "pill--warn" },
  suspended: { label: "Suspendu",     pill: "pill--crit" },
  closed:    { label: "Clôturé",      pill: "pill--mute" },
  rejected:  { label: "Refusé",       pill: "pill--mute" }
};

export const CLAIM_STATUS = {
  open:        { label: "Ouverte",     pill: "pill--warn" },
  in_progress: { label: "En instruction", pill: "pill--info" },
  resolved:    { label: "Résolue",     pill: "pill--good" },
  rejected:    { label: "Rejetée",     pill: "pill--mute" }
};

export const CLAIM_CATEGORIES = [
  { id: "operation", label: "Opération contestée" },
  { id: "solde",     label: "Solde incorrect" },
  { id: "acces",     label: "Accès ou carte bloquée" },
  { id: "autre",     label: "Autre demande" }
];

/* Générateur pseudo-aléatoire à graine : l'historique doit être identique à
   chaque réinitialisation, sinon les graphiques changent de forme entre deux
   présentations. */
function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

/* Enregistre une transaction et chaîne son empreinte à la précédente. Une fois
   écrite, une transaction n'est ni modifiée ni supprimée (§2.2, §3.2). */
export function commitTxn(db, employee, partner, amount, at, channel) {
  const prev = db.txns.length ? db.txns[db.txns.length - 1].hash : "0".repeat(8);
  const ref = "TRX-" + String(++db.counters.txn).padStart(6, "0");
  const t = {
    id: ref, ref, employeeId: employee.id, partnerId: partner.id,
    amount, at: at || Date.now(), channel: channel || "qr",
    status: "validated", prev, hash: ""
  };
  t.hash = fnv1a([prev, ref, t.employeeId, t.partnerId, t.amount, t.at].join("|"));
  employee.balance -= amount;
  db.txns.push(t);
  return t;
}

export function rechain(db) {
  let prev = "0".repeat(8);
  db.txns.forEach(t => {
    t.prev = prev;
    t.hash = fnv1a([prev, t.ref, t.employeeId, t.partnerId, t.amount, t.at].join("|"));
    prev = t.hash;
  });
}

export function verifyLedger(db) {
  let prev = "0".repeat(8);
  for (let i = 0; i < db.txns.length; i++) {
    const t = db.txns[i];
    const h = fnv1a([prev, t.ref, t.employeeId, t.partnerId, t.amount, t.at].join("|"));
    if (t.prev !== prev || t.hash !== h)
      return { ok: false, index: i, ref: t.ref, expected: h, found: t.hash };
    prev = t.hash;
  }
  return { ok: true, count: db.txns.length, head: prev };
}

export function seed() {
  const R = rng(20260202);
  const pick = arr => arr[Math.floor(R() * arr.length)];
  const between = (a, b) => a + Math.floor(R() * (b - a + 1));

  const employers = [
    { id: "EMP-VALLONIS", name: "Groupe Vallonis", siret: "812 445 902 00034",
      code: "VALLONIS-2026", headcount: 48, contact: "rh@vallonis.fr" },
    { id: "EMP-ARDENNE", name: "Ardenne Industries", siret: "509 118 774 00021",
      code: "ARDENNE-2026", headcount: 132, contact: "sirh@ardenne.fr" }
  ];

  const E = (id, name, email, employerId, since) =>
    ({ id, name, email, employerId, since, balance: 0, status: "active", password: "demo" });

  const employees = [
    E("SAL-0042", "Amina Berthier",  "a.berthier@vallonis.fr", "EMP-VALLONIS", "2026-01-12"),
    E("SAL-0043", "Youssef Kaddour", "y.kaddour@vallonis.fr",  "EMP-VALLONIS", "2026-01-12"),
    E("SAL-0044", "Claire Nguyen",   "c.nguyen@vallonis.fr",   "EMP-VALLONIS", "2026-02-03"),
    E("SAL-0101", "Marc Lestrade",   "m.lestrade@ardenne.fr",  "EMP-ARDENNE",  "2026-01-20"),
    E("SAL-0102", "Sophie Ravel",    "s.ravel@ardenne.fr",     "EMP-ARDENNE",  "2026-01-20"),
    E("SAL-0103", "Hugo Delcourt",   "h.delcourt@ardenne.fr",  "EMP-ARDENNE",  "2026-03-02")
  ];

  const admins = [
    { id: "AGT-001", name: "Thomas Vignal", email: "t.vignal@jeb.gouv.fr",
      role: "Conseiller numérique", password: "demo" },
    { id: "AGT-002", name: "Florine Pontaillac", email: "f.pontaillac@jeb.gouv.fr",
      role: "Conseillère juridique", password: "demo" }
  ];

  const P = (id, name, cat, addr, city, region, x, y, st, days) => ({
    id, name, category: cat, address: addr, city, region, x, y, status: st,
    siret: between(100, 899) + " " + between(100, 899) + " " + between(100, 899) + " 000" + between(10, 99),
    contact: name.toLowerCase().replace(/[^a-z]+/g, ".").replace(/^\.|\.$/g, "") + "@partenaire.fr",
    password: "demo",
    createdAt: Date.now() - days * 864e5,
    iban: "FR76 " + between(1000, 9999) + " " + between(1000, 9999) + " "
        + between(1000, 9999) + " " + between(1000, 9999)
  });

  const partners = [
    P("PRT-001", "Le Comptoir des Halles", "restauration", "12 rue des Halles",      "Paris",      "Île-de-France",              0.34, 0.30, "active", 96),
    P("PRT-002", "Boulangerie Sarrazin",   "boulangerie",  "4 place Victor Hugo",    "Paris",      "Île-de-France",              0.52, 0.44, "active", 94),
    P("PRT-003", "Librairie Ampère",       "culture",      "27 rue Ampère",          "Lyon",       "Auvergne-Rhône-Alpes",       0.68, 0.24, "active", 88),
    P("PRT-004", "Studio Forme",           "sport",        "9 avenue de la Gare",    "Lille",      "Hauts-de-France",            0.22, 0.62, "active", 81),
    P("PRT-005", "Le Panier Bio",          "alimentation", "55 cours Berriat",       "Grenoble",   "Auvergne-Rhône-Alpes",       0.78, 0.56, "active", 76),
    P("PRT-006", "Cinéma Le Rex",          "culture",      "3 boulevard Gambetta",   "Bordeaux",   "Nouvelle-Aquitaine",         0.44, 0.72, "active", 70),
    P("PRT-007", "Table de Marseille",     "restauration", "18 quai du Port",        "Marseille",  "Provence-Alpes-Côte d'Azur", 0.60, 0.80, "active", 64),
    P("PRT-008", "Vélo Cité",              "transport",    "2 rue Nationale",        "Nantes",     "Pays de la Loire",           0.14, 0.40, "active", 58),
    P("PRT-009", "Institut Bellevue",      "bienetre",     "31 rue Saint-Rome",      "Toulouse",   "Occitanie",                  0.86, 0.34, "active", 51),
    P("PRT-010", "Épicerie Kléber",        "alimentation", "76 avenue Kléber",       "Strasbourg", "Grand Est",                  0.30, 0.18, "active", 44),
    P("PRT-011", "Café des Facultés",      "restauration", "1 place de la Sorbonne", "Paris",      "Île-de-France",              0.48, 0.62, "suspended", 39),
    P("PRT-012", "Fournil de Lyon",        "boulangerie",  "14 rue de la Charité",   "Lyon",       "Auvergne-Rhône-Alpes",       0.72, 0.68, "active", 33),
    P("PRT-013", "Escapade Nautique",      "sport",        "8 quai des Chartrons",   "Bordeaux",   "Nouvelle-Aquitaine",         0.20, 0.30, "pending", 4),
    P("PRT-014", "Maison Perrin",          "boulangerie",  "40 rue du Marché",       "Lille",      "Hauts-de-France",            0.62, 0.14, "pending", 2)
  ];

  const db = {
    version: 1,
    employers, employees, partners, admins,
    txns: [], topups: [], tokens: [], audit: [], outbox: [], claims: [],
    session: null,
    degraded: false,
    counters: { txn: 0, topup: 0, claim: 0 }
  };

  const now = Date.now();
  const actifs = partners.filter(p => p.status === "active");

  for (let m = 6; m >= 1; m--) {
    const at = now - m * 30 * 864e5;
    employees.forEach(e => {
      const amount = e.employerId === "EMP-VALLONIS" ? 22000 : 18000;
      db.topups.push({
        id: "RCH-" + String(++db.counters.topup).padStart(5, "0"),
        employerId: e.employerId, employeeId: e.id, amount, at,
        kind: "dotation", label: "Dotation mensuelle", actor: e.employerId
      });
      e.balance += amount;
    });
  }

  for (let d = 88; d >= 0; d--) {
    const day = new Date(now - d * 864e5);
    const we = day.getDay() === 0 || day.getDay() === 6;
    const count = we ? between(0, 2) : between(1, 4);
    for (let k = 0; k < count; k++) {
      const e = pick(employees), p = pick(actifs);
      const amount = between(340, 4200);
      if (e.balance < amount) continue;
      const at = new Date(day.getFullYear(), day.getMonth(), day.getDate(),
                          between(8, 20), between(0, 59)).getTime();
      commitTxn(db, e, p, amount, at, "qr");
    }
  }
  db.txns.sort((a, b) => a.at - b.at);
  rechain(db);

  /* Deux réclamations déjà ouvertes : la relation entre l'administration et le
     salarié doit être visible dès l'ouverture du démonstrateur, des deux côtés. */
  const contestee = db.txns.filter(t => t.employeeId === "SAL-0043").slice(-1)[0];
  db.claims = [
    {
      id: "REC-" + String(++db.counters.claim).padStart(4, "0"),
      employeeId: "SAL-0043", category: "operation",
      txnRef: contestee ? contestee.ref : null,
      subject: "Montant débité deux fois chez Boulangerie Sarrazin",
      status: "open", createdAt: now - 2 * 864e5, updatedAt: now - 2 * 864e5,
      messages: [{ from: "employee", author: "Youssef Kaddour", at: now - 2 * 864e5,
        body: "Bonjour, le commerçant a scanné deux fois mon QR code lundi. "
            + "Je vois bien deux débits alors que je n'ai payé qu'une fois." }]
    },
    {
      id: "REC-" + String(++db.counters.claim).padStart(4, "0"),
      employeeId: "SAL-0102", category: "solde",
      txnRef: null,
      subject: "Dotation du mois non créditée",
      status: "in_progress", createdAt: now - 5 * 864e5, updatedAt: now - 1 * 864e5,
      messages: [
        { from: "employee", author: "Sophie Ravel", at: now - 5 * 864e5,
          body: "Mes collègues ont reçu leur dotation, pas moi. Pouvez-vous vérifier ?" },
        { from: "admin", author: "Thomas Vignal", at: now - 1 * 864e5,
          body: "Bonjour, votre dossier est bien pris en compte. Nous vérifions le "
              + "fichier de rechargement transmis par Ardenne Industries." }
      ]
    }
  ];

  return db;
}

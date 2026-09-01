/* ============================================================================
   Modèle de données et jeu de démonstration — Ticket Tout.

   Le schéma reproduit celui d'une base relationnelle — employeurs, salariés,
   partenaires, transactions, rechargements, jetons, réclamations — pour que le
   passage à un vrai backend soit une transposition, pas une réécriture.

   Les partenaires sont ceux que le ministre a désignés lui-même dans le
   cahier des charges annoté (v1.1) ; les autres sont donnés « en cours de
   signature », c'est-à-dire en attente de sa validation.
   ========================================================================= */

import { fnv1a } from "./format.js";

export const CATEGORIES = [
  { id: "loisirs",     label: "Loisirs & nature",       ico: "spark" },
  { id: "creation",    label: "Création & fête",        ico: "ticket" },
  { id: "gourmandise", label: "Gourmandise",            ico: "store" },
  { id: "mode",        label: "Mode & artisanat",       ico: "user" },
  { id: "bienetre",    label: "Bien-être",              ico: "users" },
  { id: "culture",     label: "Culture",                ico: "ticket" },
  { id: "sport",       label: "Sport",                  ico: "chart" }
];
export const catLabel = id => (CATEGORIES.find(c => c.id === id) || { label: id }).label;
export const catIco   = id => (CATEGORIES.find(c => c.id === id) || { ico: "store" }).ico;

export const REGIONS = ["Île-de-France", "Auvergne-Rhône-Alpes", "Provence-Alpes-Côte d'Azur",
  "Hauts-de-France", "Nouvelle-Aquitaine", "Occitanie", "Pays de la Loire", "Grand Est"];

export const STATUS = {
  active:    { label: "Actif",      pill: "pill--good" },
  pending:   { label: "En attente", pill: "pill--warn" },
  suspended: { label: "Suspendu",   pill: "pill--crit" },
  closed:    { label: "Clôturé",    pill: "pill--mute" },
  rejected:  { label: "Refusé",     pill: "pill--mute" }
};

export const CLAIM_STATUS = {
  open:        { label: "Ouverte",        pill: "pill--warn" },
  in_progress: { label: "En instruction", pill: "pill--info" },
  resolved:    { label: "Résolue",        pill: "pill--good" },
  rejected:    { label: "Rejetée",        pill: "pill--mute" }
};

export const CLAIM_CATEGORIES = [
  { id: "operation", label: "Opération contestée" },
  { id: "solde",     label: "Solde incorrect" },
  { id: "acces",     label: "Accès ou compte bloqué" },
  { id: "autre",     label: "Autre demande" }
];

/* Durée de validité d'un jeton de paiement. Le ministre a relevé la limite de
   5 à 30 minutes : « si le QR expire en 5 minutes et que le client est à la
   caisse du poney club, c'est un problème » (annotation §3.2). */
export const TOKEN_TTL = 30 * 60e3;

function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (s * 1664525 + 1013904223) >>> 0; return s / 4294967296; };
}

/* Écrit une transaction et chaîne son empreinte à la précédente. Une écriture
   n'est jamais modifiée ni supprimée : une annulation est une écriture de plus,
   de sens inverse, qui référence celle qu'elle compense. */
export function commitTxn(db, employee, partner, amount, at, channel, extra) {
  const prev = db.txns.length ? db.txns[db.txns.length - 1].hash : "0".repeat(8);
  const ref = "TRX-" + String(++db.counters.txn).padStart(6, "0");
  const t = Object.assign({
    id: ref, ref, employeeId: employee.id, partnerId: partner.id,
    amount, at: at || Date.now(), channel: channel || "qr",
    kind: "payment", status: "validated", reversedBy: null, reverses: null,
    prev, hash: ""
  }, extra || {});
  t.hash = fnv1a([prev, ref, t.kind, t.employeeId, t.partnerId, t.amount, t.at].join("|"));
  if (t.kind === "reversal") employee.balance += amount;
  else employee.balance -= amount;
  db.txns.push(t);
  return t;
}

export function rechain(db) {
  let prev = "0".repeat(8);
  db.txns.forEach(t => {
    t.prev = prev;
    t.hash = fnv1a([prev, t.ref, t.kind || "payment", t.employeeId, t.partnerId, t.amount, t.at].join("|"));
    prev = t.hash;
  });
}

export function verifyLedger(db) {
  let prev = "0".repeat(8);
  for (let i = 0; i < db.txns.length; i++) {
    const t = db.txns[i];
    const h = fnv1a([prev, t.ref, t.kind || "payment", t.employeeId, t.partnerId, t.amount, t.at].join("|"));
    if (t.prev !== prev || t.hash !== h)
      return { ok: false, index: i, ref: t.ref, expected: h, found: t.hash };
    prev = t.hash;
  }
  return { ok: true, count: db.txns.length, head: prev };
}

export function seed() {
  const R = rng(20260109);
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

  /* Le ministre signe lui-même les adhésions et met les partenaires en avant :
     son compte porte donc des pouvoirs que les autres agents n'ont pas. */
  const admins = [
    { id: "AGT-000", name: "Jean-Eudes Berlier", email: "je.berlier@job-et-bonheur.fr",
      role: "Ministre du Job et Bonheur", minister: true, password: "demo" },
    { id: "AGT-001", name: "Thomas Vignal", email: "t.vignal@job-et-bonheur.fr",
      role: "Conseiller numérique", password: "demo" },
    { id: "AGT-002", name: "Florine Pontaillac", email: "f.pontaillac@job-et-bonheur.fr",
      role: "Conseillère juridique", password: "demo" },
    { id: "AGT-003", name: "Benjamin Sellami", email: "b.sellami@job-et-bonheur.fr",
      role: "Conseiller communication", password: "demo" }
  ];

  const P = (o) => Object.assign({
    password: "demo", featured: false, ministerNote: "",
    siret: between(100, 899) + " " + between(100, 899) + " " + between(100, 899) + " 000" + between(10, 99),
    iban: "FR76 " + between(1000, 9999) + " " + between(1000, 9999) + " "
        + between(1000, 9999) + " " + between(1000, 9999)
  }, o);

  /* Les quatre partenaires du lancement, choisis par le ministre. */
  const partners = [
    P({ id: "PRT-001", name: "Poney Dream 78", category: "loisirs",
        address: "Route des Écuries", city: "Saint-Rémy-lès-Chevreuse", region: "Île-de-France",
        channel: "Sur place", contact: "contact@poneydream78.fr",
        x: 0.30, y: 0.28, status: "active", createdAt: Date.now() - 96 * 864e5,
        featured: true, ministerNote: "Parfait pour souder une équipe et renouer avec la nature.",
        basket: [3200, 6800] }),
    P({ id: "PRT-002", name: "KostumParty", category: "creation",
        address: "34 rue Oberkampf, Paris 11ᵉ", city: "Paris", region: "Île-de-France",
        channel: "Sur place", contact: "bonjour@kostumparty.fr",
        x: 0.52, y: 0.44, status: "active", createdAt: Date.now() - 92 * 864e5,
        featured: true, ministerNote: "La créativité est la clé du bonheur au travail.",
        basket: [2400, 9500] }),
    P({ id: "PRT-003", name: "Glaces Artisanales Corrèze", category: "gourmandise",
        address: "8 avenue de la Gare", city: "Brive-la-Gaillarde", region: "Nouvelle-Aquitaine",
        channel: "En ligne et retrait en boutique", contact: "commandes@glaces-correze.fr",
        x: 0.44, y: 0.70, status: "active", createdAt: Date.now() - 88 * 864e5,
        ministerNote: "", basket: [450, 1900] }),
    P({ id: "PRT-004", name: "Chapelier Fontaine", category: "mode",
        address: "12 rue Saint-Rome", city: "Toulouse", region: "Occitanie",
        channel: "Sur place", contact: "atelier@chapelier-fontaine.fr",
        x: 0.82, y: 0.62, status: "active", createdAt: Date.now() - 80 * 864e5,
        ministerNote: "", basket: [4500, 12500] })
  ];

  /* « Autres partenaires en cours de signature » : ils attendent la validation
     du ministre et n'apparaissent donc pas encore au catalogue. */
  const enCours = [
    ["Les Serres de Bagatelle", "loisirs",     "Allée de Longchamp",     "Paris",     "Île-de-France",              12],
    ["Atelier Céramique du Marais", "creation","9 rue de Turenne",       "Paris",     "Île-de-France",               9],
    ["Savonnerie de Grasse",   "bienetre",     "3 chemin des Aromes",    "Grasse",    "Provence-Alpes-Côte d'Azur",  7],
    ["Le Vinyle Retrouvé",     "culture",      "22 rue Esquermoise",     "Lille",     "Hauts-de-France",             5],
    ["Escalade Verticale",     "sport",        "40 quai Perrache",       "Lyon",      "Auvergne-Rhône-Alpes",        3],
    ["Miellerie des Cévennes", "gourmandise",  "6 place aux Herbes",     "Nîmes",     "Occitanie",                   2]
  ];
  enCours.forEach(([name, category, address, city, region, days], i) => {
    partners.push(P({
      id: "PRT-" + String(partners.length + 1).padStart(3, "0"),
      name, category, address, city, region, channel: "Sur place",
      contact: name.toLowerCase().replace(/[^a-z]+/g, ".").replace(/^\.|\.$/g, "") + "@partenaire.fr",
      x: 0.15 + (i % 3) * 0.3, y: 0.2 + Math.floor(i / 3) * 0.35,
      status: "pending", createdAt: Date.now() - days * 864e5, basket: [1500, 5000]
    }));
  });

  const db = {
    version: 2,
    employers, employees, partners, admins,
    txns: [], topups: [], tokens: [], audit: [], claims: [],
    session: null,
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

  /* Un historique aux montants plausibles : une séance de poney ne coûte pas
     le prix d'un cornet de glace. */
  for (let d = 88; d >= 0; d--) {
    const day = new Date(now - d * 864e5);
    const we = day.getDay() === 0 || day.getDay() === 6;
    const count = we ? between(1, 3) : between(0, 2);
    for (let k = 0; k < count; k++) {
      const e = pick(employees), p = pick(actifs);
      const amount = between(p.basket[0], p.basket[1]);
      if (e.balance < amount) continue;
      const at = new Date(day.getFullYear(), day.getMonth(), day.getDate(),
                          between(9, 19), between(0, 59)).getTime();
      commitTxn(db, e, p, amount, at, "qr");
    }
  }
  db.txns.sort((a, b) => a.at - b.at);
  rechain(db);

  const contestee = db.txns.filter(t => t.employeeId === "SAL-0043").slice(-1)[0];
  db.claims = [
    {
      id: "REC-" + String(++db.counters.claim).padStart(4, "0"),
      employeeId: "SAL-0043", category: "operation",
      txnRef: contestee ? contestee.ref : null,
      subject: "Montant débité deux fois chez KostumParty",
      status: "open", createdAt: now - 2 * 864e5, updatedAt: now - 2 * 864e5,
      messages: [{ from: "employee", author: "Youssef Kaddour", at: now - 2 * 864e5,
        body: "Bonjour, la boutique a scanné deux fois mon QR code samedi. Je vois deux "
            + "débits alors que je n'ai loué qu'un seul costume." }]
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
          body: "Bonjour, votre dossier est bien pris en compte. Nous vérifions le fichier "
              + "de rechargement transmis par Ardenne Industries." }
      ]
    }
  ];

  return db;
}

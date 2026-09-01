/* ============================================================================
   Magasin de données et API REST simulée.

   Aucune vue n'écrit dans les données : tout passe par API.call, qui parle en
   chemins REST et en codes HTTP. Remplacer le corps de `call` par un `fetch`
   suffit à brancher un vrai backend ; le reste de l'application ne bouge pas.
   ========================================================================= */

import { uid } from "./format.js";
import { seed, commitTxn, verifyLedger, catLabel, STATUS, REGIONS, TOKEN_TTL } from "./data.js";

const KEY = "tickettout.demo.v1";

/* ---- Magasin observable ---------------------------------------------------
   Un compteur de version sert d'instantané : React s'y abonne et redessine
   quand il change. Les objets du domaine restent des objets simples. */
export const store = {
  db: null,
  v: 0,
  listeners: new Set(),

  init() {
    if (this.db) return this.db;
    this.db = this.load() || seed();
    if (!this.db.claims) this.db.claims = [];
    return this.db;
  },
  load() {
    if (typeof localStorage === "undefined") return null;
    try {
      const raw = localStorage.getItem(KEY);
      const parsed = raw ? JSON.parse(raw) : null;
      return parsed && parsed.txns && parsed.partners ? parsed : null;
    } catch (e) { return null; }          // navigation privée, quota, données corrompues
  },
  save() {
    try { localStorage.setItem(KEY, JSON.stringify(this.db)); } catch (e) { /* sans effet */ }
    this.notify();
  },
  reset() { this.db = seed(); this.save(); },
  notify() { this.v++; this.listeners.forEach(fn => fn()); },
  subscribe(fn) { this.listeners.add(fn); return () => this.listeners.delete(fn); },
  snapshot() { return this.v; }
};

const db = () => store.init();
export const emp = id => db().employees.find(e => e.id === id);
export const prt = id => db().partners.find(p => p.id === id);
export const emr = id => db().employers.find(e => e.id === id);
export const agent = id => db().admins.find(a => a.id === id);
export const claim = id => db().claims.find(c => c.id === id);

/* ---- Événements applicatifs (solde temps réel, notifications) ------------- */
export const BUS = {
  h: {},
  on(evt, fn) { (this.h[evt] = this.h[evt] || []).push(fn); return () => { this.h[evt] = this.h[evt].filter(f => f !== fn); }; },
  emit(evt, data) { (this.h[evt] || []).slice().forEach(fn => fn(data)); }
};

/* ---- Représentations publiques -------------------------------------------- */
function publicTxn(t) {
  const p = prt(t.partnerId), e = emp(t.employeeId);
  return {
    ref: t.ref, at: new Date(t.at).toISOString(), amount: t.amount, currency: "EUR",
    status: t.status, channel: t.channel,
    kind: t.kind || "payment", reverses: t.reverses || null, reversedBy: t.reversedBy || null,
    reason: t.reason || null,
    partner: p ? { id: p.id, name: p.name, category: p.category, city: p.city } : null,
    employee: e ? { id: e.id, name: e.name } : null,
    integrity: { prev: t.prev, hash: t.hash }
  };
}
function publicPartner(p, full) {
  const base = { id: p.id, name: p.name, category: p.category, categoryLabel: catLabel(p.category),
                 city: p.city, region: p.region, address: p.address, status: p.status,
                 channel: p.channel || "Sur place", featured: !!p.featured,
                 ministerNote: p.ministerNote || "", x: p.x, y: p.y };
  if (!full) return base;
  const rows = db().txns.filter(t => t.partnerId === p.id);
  return Object.assign(base, {
    siret: p.siret, contact: p.contact, iban: p.iban,
    createdAt: new Date(p.createdAt).toISOString(),
    totals: { count: rows.length, amount: rows.reduce((s, t) => s + t.amount, 0) }
  });
}
function publicEmployee(e, full) {
  const base = { id: e.id, name: e.name, email: e.email, status: e.status,
                 employerId: e.employerId, employer: (emr(e.employerId) || {}).name,
                 balance: e.balance, since: e.since };
  if (!full) return base;
  const rows = db().txns.filter(t => t.employeeId === e.id);
  return Object.assign(base, {
    totals: { count: rows.length, amount: rows.reduce((s, t) => s + t.amount, 0) },
    credited: db().topups.filter(t => t.employeeId === e.id).reduce((s, t) => s + t.amount, 0),
    claims: db().claims.filter(c => c.employeeId === e.id).length
  });
}
function publicClaim(c, full) {
  const e = emp(c.employeeId);
  const base = { id: c.id, subject: c.subject, category: c.category, status: c.status,
                 txnRef: c.txnRef, createdAt: c.createdAt, updatedAt: c.updatedAt,
                 employee: e ? { id: e.id, name: e.name, employer: (emr(e.employerId) || {}).name } : null,
                 messageCount: c.messages.length,
                 lastMessage: c.messages[c.messages.length - 1] || null };
  return full ? Object.assign(base, { messages: c.messages, resolution: c.resolution || null }) : base;
}
function paginate(rows, q) {
  const size = Math.max(1, Math.min(100, Number(q.size) || 10));
  const pages = Math.max(1, Math.ceil(rows.length / size));
  const page = Math.min(pages, Math.max(1, Number(q.page) || 1));
  return { items: rows.slice((page - 1) * size, page * size), page, size, pages, total: rows.length };
}
function stats() {
  const d = db(), now = Date.now(), s30 = now - 30 * 864e5, s60 = now - 60 * 864e5;
  const sum = a => a.reduce((s, t) => s + t.amount, 0);
  const paiements = d.txns.filter(t => (t.kind || "payment") === "payment");
  const cur = paiements.filter(t => t.at >= s30);
  const prev = paiements.filter(t => t.at >= s60 && t.at < s30);
  const byRegion = {}, byCategory = {};
  paiements.forEach(t => {
    const p = prt(t.partnerId); if (!p) return;
    byRegion[p.region] = (byRegion[p.region] || 0) + t.amount;
    byCategory[p.category] = (byCategory[p.category] || 0) + t.amount;
  });
  return {
    volume: sum(paiements) - sum(d.txns.filter(t => t.kind === "reversal")),
    volume30: sum(cur), volume30prev: sum(prev),
    count: paiements.length, count30: cur.length,
    reversals: d.txns.filter(t => t.kind === "reversal").length,
    partnersActive: d.partners.filter(p => p.status === "active").length,
    partnersPending: d.partners.filter(p => p.status === "pending").length,
    partnersTotal: d.partners.length,
    employees: d.employees.length,
    employeesSuspended: d.employees.filter(e => e.status !== "active").length,
    claimsOpen: d.claims.filter(c => c.status === "open" || c.status === "in_progress").length,
    outstanding: d.employees.reduce((s, e) => s + e.balance, 0),
    average: paiements.length ? Math.round(sum(paiements) / paiements.length) : 0,
    byRegion, byCategory
  };
}

/* ---- Table de routage ----------------------------------------------------- */
const fail = (status, error, message) => {
  const e = new Error(message); e.status = status; e.body = { error, message }; throw e;
};

const ROUTES = [

  /* -- Authentification -------------------------------------------------- */
  { m: "POST", p: /^\/auth\/login$/, h: (_, b) => {
      const mail = String(b.email || "").trim().toLowerCase();
      const d = db();
      const e = d.employees.find(x => x.email.toLowerCase() === mail);
      if (e) {
        if (e.status === "closed") fail(403, "account_closed", "Ce compte a été clôturé.");
        d.session = { role: "employee", id: e.id };
        return { role: "employee", id: e.id, name: e.name };
      }
      const p = d.partners.find(x => (x.contact || "").toLowerCase() === mail);
      if (p) { d.session = { role: "partner", id: p.id }; return { role: "partner", id: p.id, name: p.name }; }
      const a = d.admins.find(x => x.email.toLowerCase() === mail);
      if (a) { d.session = { role: "admin", id: a.id }; return { role: "admin", id: a.id, name: a.name }; }
      fail(401, "unknown_account", "Aucun compte ne correspond à cette adresse.");
    } },

  { m: "POST", p: /^\/auth\/register$/, h: (_, b) => {
      const d = db();
      if (b.role === "employee") {
        const employer = d.employers.find(x => x.code.toLowerCase() === String(b.code || "").trim().toLowerCase());
        if (!employer) fail(400, "unknown_code", "Code employeur inconnu. Demandez-le à votre service RH.");
        if (d.employees.some(x => x.email.toLowerCase() === String(b.email).toLowerCase()))
          fail(409, "email_taken", "Un compte existe déjà avec cette adresse.");
        const e = {
          id: "SAL-" + String(9000 + d.employees.length).slice(-4),
          name: b.name, email: b.email, employerId: employer.id,
          since: new Date().toISOString().slice(0, 10),
          balance: 0, status: "active", password: b.password || "demo"
        };
        d.employees.push(e);
        d.audit.unshift({ at: Date.now(), actor: "inscription", target: e.id,
          action: "create", to: "active", note: "Rattaché à " + employer.name });
        d.session = { role: "employee", id: e.id };
        return { role: "employee", id: e.id, name: e.name, employer: employer.name };
      }
      if (b.role === "partner") {
        if (!b.name || !b.city) fail(400, "missing_fields", "Raison sociale et ville sont obligatoires.");
        const p = {
          id: "PRT-" + String(d.partners.length + 1).padStart(3, "0"),
          name: b.name, category: b.category || "restauration", address: b.address || "",
          city: b.city, region: b.region || REGIONS[0], siret: b.siret || "",
          contact: b.email, password: b.password || "demo", iban: b.iban || "",
          x: 0.2 + Math.random() * 0.6, y: 0.2 + Math.random() * 0.6,
          status: "pending", createdAt: Date.now()      // validation manuelle (§2.2)
        };
        d.partners.push(p);
        d.session = { role: "partner", id: p.id };
        return { role: "partner", id: p.id, name: p.name, status: "pending" };
      }
      fail(400, "invalid_role", "Rôle inconnu.");
    } },

  { m: "POST", p: /^\/auth\/logout$/, h: () => { db().session = null; return { ok: true }; } },

  { m: "POST", p: /^\/auth\/session$/, h: (_, b) => {
      // Bascule de démonstration : ouvre une session sur le compte type d'un rôle.
      const d = db();
      const map = { employee: () => d.employees[0].id, partner: () => d.partners[0].id, admin: () => d.admins[0].id };
      if (!map[b.role]) fail(400, "invalid_role", "Rôle inconnu.");
      d.session = { role: b.role, id: b.id || map[b.role]() };
      return d.session;
    } },

  /* -- Salariés ---------------------------------------------------------- */
  { m: "GET", p: /^\/employees$/, h: (_, __, q) => {
      let rows = db().employees.slice();
      if (q.query) {
        const s = q.query.toLowerCase();
        rows = rows.filter(e => (e.name + " " + e.email + " " + e.id).toLowerCase().includes(s));
      }
      if (q.status) rows = rows.filter(e => e.status === q.status);
      if (q.employerId) rows = rows.filter(e => e.employerId === q.employerId);
      return paginate(rows.map(e => publicEmployee(e)), q);
    } },

  { m: "GET", p: /^\/employees\/([\w-]+)$/, h: a =>
      publicEmployee(emp(a[1]) || fail(404, "not_found", "Salarié inconnu"), true) },

  { m: "PATCH", p: /^\/employees\/([\w-]+)$/, h: (a, b) => {
      const e = emp(a[1]) || fail(404, "not_found", "Salarié inconnu");
      if (!STATUS[b.status]) fail(400, "invalid_status", "Statut inconnu");
      const before = e.status;
      e.status = b.status;
      db().audit.unshift({ at: Date.now(), actor: "admin", target: e.id,
        action: "status", from: before, to: b.status, note: b.note || "" });
      BUS.emit("employee", { employee: e });
      return publicEmployee(e, true);
    } },

  { m: "GET", p: /^\/employees\/([\w-]+)\/transactions$/, h: (a, _, q) => {
      const e = emp(a[1]) || fail(404, "not_found", "Salarié inconnu");
      let rows = db().txns.filter(t => t.employeeId === e.id).slice().reverse();
      if (q.month) rows = rows.filter(t => new Date(t.at).toISOString().slice(0, 7) === q.month);
      return paginate(rows.map(publicTxn), q);
    } },

  { m: "GET", p: /^\/employees\/([\w-]+)\/topups$/, h: (a, _, q) => {
      const e = emp(a[1]) || fail(404, "not_found", "Salarié inconnu");
      const rows = db().topups.filter(t => t.employeeId === e.id).slice().sort((x, y) => y.at - x.at);
      return paginate(rows, q);
    } },

  /* -- Jetons et transactions -------------------------------------------- */
  { m: "POST", p: /^\/payment-tokens$/, h: (_, b) => {
      const d = db();
      const e = emp(b.employeeId) || fail(404, "not_found", "Salarié inconnu");
      if (e.status !== "active") fail(403, "account_inactive", "Compte salarié " + STATUS[e.status].label.toLowerCase());
      if (e.balance <= 0) fail(402, "empty_balance", "Solde épuisé");
      d.tokens = d.tokens.filter(t => t.expiresAt > Date.now() - 3600e3);
      // 30 minutes : le ministre a relevé la limite pour ne pas bloquer un
      // client à la caisse (annotation §3.2).
      const tok = { token: uid(16), employeeId: e.id, issuedAt: Date.now(),
                    expiresAt: Date.now() + TOKEN_TTL, usedAt: null };
      d.tokens.push(tok);
      return tok;
    } },

  { m: "GET", p: /^\/payment-tokens\/([\w-]+)$/, h: a => {
      const t = db().tokens.find(x => x.token === a[1]) || fail(404, "unknown_token", "Jeton inconnu");
      if (t.usedAt) fail(409, "token_used", "Jeton déjà utilisé");
      if (t.expiresAt < Date.now()) fail(410, "token_expired", "Jeton expiré");
      const e = emp(t.employeeId);
      return { token: t.token, employee: { id: e.id, name: e.name }, expiresAt: t.expiresAt };
    } },

  { m: "POST", p: /^\/transactions$/, h: (_, b) => {
      const d = db();
      const t = d.tokens.find(x => x.token === b.token) || fail(404, "unknown_token", "Jeton inconnu");
      if (t.usedAt) fail(409, "token_used", "Jeton déjà utilisé");
      if (t.expiresAt < Date.now()) fail(410, "token_expired", "Jeton expiré");
      const p = prt(b.partnerId) || fail(404, "not_found", "Partenaire inconnu");
      if (p.status !== "active") fail(403, "partner_inactive", "Compte partenaire non actif");
      const amount = Math.round(Number(b.amount));
      if (!(amount > 0)) fail(400, "invalid_amount", "Montant invalide");
      const e = emp(t.employeeId);
      if (e.status !== "active") fail(403, "account_inactive", "Compte salarié non actif");
      if (e.balance < amount) fail(402, "insufficient_funds", "Solde insuffisant");

      t.usedAt = Date.now();                                   // usage unique (§3.2)
      const txn = commitTxn(d, e, p, amount, Date.now(), b.channel || "qr");
      BUS.emit("txn", { txn, employee: e, partner: p });
      return publicTxn(txn);
    } },

  /* -- Partenaires -------------------------------------------------------- */
  { m: "GET", p: /^\/partners$/, h: (_, __, q) => {
      let rows = db().partners.filter(p => q.all ? true : p.status === "active");
      if (q.status) rows = rows.filter(p => p.status === q.status);
      if (q.category) rows = rows.filter(p => p.category === q.category);
      if (q.query) {
        const s = q.query.toLowerCase();
        rows = rows.filter(p => (p.name + " " + p.city + " " + catLabel(p.category)).toLowerCase().includes(s));
      }
      rows = rows.slice().sort((a, b) => a.name.localeCompare(b.name, "fr"));
      return paginate(rows.map(p => publicPartner(p)), q);
    } },

  { m: "GET", p: /^\/partners\/([\w-]+)$/, h: a =>
      publicPartner(prt(a[1]) || fail(404, "not_found", "Partenaire inconnu"), true) },

  { m: "PATCH", p: /^\/partners\/([\w-]+)$/, h: (a, b) => {
      const p = prt(a[1]) || fail(404, "not_found", "Partenaire inconnu");
      if (!STATUS[b.status]) fail(400, "invalid_status", "Statut inconnu");
      const before = p.status;
      p.status = b.status;
      db().audit.unshift({ at: Date.now(), actor: "admin", target: p.id,
        action: "status", from: before, to: b.status, note: b.note || "" });
      return publicPartner(p, true);
    } },

  { m: "GET", p: /^\/partners\/([\w-]+)\/transactions$/, h: (a, _, q) => {
      const p = prt(a[1]) || fail(404, "not_found", "Partenaire inconnu");
      let rows = db().txns.filter(t => t.partnerId === p.id).slice().reverse();
      if (q.since) rows = rows.filter(t => t.at >= Number(q.since));
      return paginate(rows.map(publicTxn), q);
    } },

  /* -- Mise en avant : le « Choix du Ministre » ---------------------------- */
  { m: "PATCH", p: /^\/partners\/([\w-]+)\/featured$/, h: (a, b) => {
      const p = prt(a[1]) || fail(404, "not_found", "Partenaire inconnu");
      if (p.status !== "active" && b.featured)
        fail(409, "partner_inactive", "Seul un partenaire actif peut être mis en avant.");
      p.featured = !!b.featured;
      p.ministerNote = b.featured ? String(b.note || "").slice(0, 160) : "";
      db().audit.unshift({ at: Date.now(), actor: b.author || "Ministre", target: p.id,
        action: "featured", to: p.featured ? "mis en avant" : "retiré", note: p.ministerNote });
      BUS.emit("featured", { partner: p });
      return publicPartner(p, true);
    } },

  /* -- Annulation d'une transaction ---------------------------------------
     Le ministre veut pouvoir annuler (annotation §2.2), et une écriture
     validée reste inaltérable. Les deux tiennent ensemble d'une seule façon :
     l'annulation est une écriture DE PLUS, de sens inverse, chaînée comme les
     autres et rattachée à celle qu'elle compense. Rien n'est réécrit. */
  { m: "POST", p: /^\/transactions\/([\w-]+)\/cancel$/, h: (a, b) => {
      const d = db();
      const t = d.txns.find(x => x.ref === a[1]) || fail(404, "not_found", "Transaction inconnue");
      if (t.kind === "reversal") fail(409, "already_reversal", "Une annulation ne s'annule pas.");
      if (t.reversedBy) fail(409, "already_reversed", "Cette transaction a déjà été annulée par " + t.reversedBy + ".");
      const e = emp(t.employeeId) || fail(404, "not_found", "Salarié inconnu");
      const p = prt(t.partnerId) || fail(404, "not_found", "Partenaire inconnu");
      const rev = commitTxn(d, e, p, t.amount, Date.now(), t.channel,
        { kind: "reversal", reverses: t.ref, reason: String(b.reason || "").slice(0, 200) });
      t.reversedBy = rev.ref;
      d.audit.unshift({ at: Date.now(), actor: b.author || "admin", target: t.ref,
        action: "cancel", to: rev.ref, note: b.reason || "" });
      BUS.emit("txn", { txn: rev, employee: e, partner: p });
      return publicTxn(rev);
    } },

  /* -- Rechargements et régularisations ----------------------------------- */
  { m: "POST", p: /^\/topups$/, h: (_, b) => {
      const d = db();
      const employer = b.employerId ? (emr(b.employerId) || fail(404, "not_found", "Employeur inconnu")) : null;
      const amount = Math.round(Number(b.amount));
      if (!(amount > 0)) fail(400, "invalid_amount", "Montant invalide");
      const ids = b.employeeIds && b.employeeIds.length
        ? b.employeeIds
        : d.employees.filter(e => employer && e.employerId === employer.id).map(e => e.id);
      if (!ids.length) fail(400, "no_recipient", "Aucun bénéficiaire sélectionné");
      const lines = ids.map(id => {
        const e = emp(id) || fail(404, "not_found", "Salarié inconnu : " + id);
        e.balance += amount;
        const t = { id: "RCH-" + String(++d.counters.topup).padStart(5, "0"),
                    employerId: e.employerId, employeeId: e.id, amount, at: Date.now(),
                    kind: b.kind || "dotation", label: b.label || "Rechargement",
                    actor: b.actor || (employer ? employer.id : "admin"), note: b.note || "" };
        d.topups.unshift(t);
        return t;
      });
      BUS.emit("topup", { lines });
      return { credited: lines.length, amount, total: amount * lines.length, lines };
    } },

  /* -- Réclamations : le lien direct entre le salarié et l'administration -- */
  { m: "GET", p: /^\/claims$/, h: (_, __, q) => {
      let rows = db().claims.slice().sort((a, b) => b.updatedAt - a.updatedAt);
      if (q.employeeId) rows = rows.filter(c => c.employeeId === q.employeeId);
      if (q.status) rows = rows.filter(c => c.status === q.status);
      if (q.open) rows = rows.filter(c => c.status === "open" || c.status === "in_progress");
      return paginate(rows.map(c => publicClaim(c)), q);
    } },

  { m: "GET", p: /^\/claims\/([\w-]+)$/, h: a =>
      publicClaim(claim(a[1]) || fail(404, "not_found", "Réclamation inconnue"), true) },

  { m: "POST", p: /^\/claims$/, h: (_, b) => {
      const d = db();
      const e = emp(b.employeeId) || fail(404, "not_found", "Salarié inconnu");
      if (!b.subject || !b.body) fail(400, "missing_fields", "Objet et description sont obligatoires");
      const c = {
        id: "REC-" + String(++d.counters.claim).padStart(4, "0"),
        employeeId: e.id, category: b.category || "autre", subject: b.subject,
        txnRef: b.txnRef || null, status: "open",
        createdAt: Date.now(), updatedAt: Date.now(),
        messages: [{ from: "employee", author: e.name, at: Date.now(), body: b.body }]
      };
      d.claims.unshift(c);
      BUS.emit("claim", { claim: c });
      return publicClaim(c, true);
    } },

  { m: "POST", p: /^\/claims\/([\w-]+)\/messages$/, h: (a, b) => {
      const c = claim(a[1]) || fail(404, "not_found", "Réclamation inconnue");
      if (!b.body) fail(400, "empty_message", "Message vide");
      if (c.status === "resolved" || c.status === "rejected")
        fail(409, "claim_closed", "Cette réclamation est clôturée.");
      c.messages.push({ from: b.from === "admin" ? "admin" : "employee",
                        author: b.author || "—", at: Date.now(), body: b.body });
      c.updatedAt = Date.now();
      if (b.from === "admin" && c.status === "open") c.status = "in_progress";
      BUS.emit("claim", { claim: c });
      return publicClaim(c, true);
    } },

  { m: "PATCH", p: /^\/claims\/([\w-]+)$/, h: (a, b) => {
      const d = db();
      const c = claim(a[1]) || fail(404, "not_found", "Réclamation inconnue");
      if (!CLAIM_ALLOWED.includes(b.status)) fail(400, "invalid_status", "Statut inconnu");
      c.status = b.status;
      c.updatedAt = Date.now();
      if (b.note) c.messages.push({ from: "admin", author: b.author || "Administration",
                                    at: Date.now(), body: b.note });
      // Une réclamation acceptée donne lieu à une régularisation créditée au
      // salarié : c'est le seul mouvement inverse possible, et il est tracé.
      if (b.status === "resolved" && Number(b.amount) > 0) {
        const e = emp(c.employeeId);
        const amount = Math.round(Number(b.amount));
        e.balance += amount;
        const t = { id: "RCH-" + String(++d.counters.topup).padStart(5, "0"),
                    employerId: e.employerId, employeeId: e.id, amount, at: Date.now(),
                    kind: "regularisation", label: "Régularisation " + c.id,
                    actor: b.author || "admin", note: b.note || "" };
        d.topups.unshift(t);
        c.resolution = { amount, at: Date.now(), by: b.author || "Administration", topupId: t.id };
      }
      d.audit.unshift({ at: Date.now(), actor: "admin", target: c.id,
        action: "claim", to: b.status, note: b.note || "" });
      BUS.emit("claim", { claim: c });
      return publicClaim(c, true);
    } },

  /* -- Pilotage ----------------------------------------------------------- */
  { m: "GET", p: /^\/admin\/stats$/, h: () => stats() },
  { m: "GET", p: /^\/ledger\/verify$/, h: () => verifyLedger(db()) },
  { m: "GET", p: /^\/employers$/, h: () => ({ items: db().employers }) }
];

const CLAIM_ALLOWED = ["open", "in_progress", "resolved", "rejected"];

/* ---- Documentation publiée dans la console -------------------------------- */
export const DOC = [
  ["POST",  "/auth/login",                    "Ouvre une session à partir d'une adresse électronique"],
  ["POST",  "/auth/register",                 "Inscription salarié (code employeur) ou partenaire (soumise à validation)"],
  ["POST",  "/auth/logout",                   "Ferme la session"],
  ["GET",   "/employees",                     "Liste des salariés (?query&status&employerId&page&size)"],
  ["GET",   "/employees/{id}",                "Fiche salarié"],
  ["PATCH", "/employees/{id}",                "Change le statut d'un compte salarié"],
  ["GET",   "/employees/{id}/transactions",   "Historique paginé (?page&size&month)"],
  ["GET",   "/employees/{id}/topups",         "Rechargements et régularisations du salarié"],
  ["POST",  "/payment-tokens",                "Émet un jeton de paiement, 5 min, usage unique"],
  ["GET",   "/payment-tokens/{token}",        "Résout un jeton présenté par un salarié"],
  ["POST",  "/transactions",                  "Valide un encaissement — écriture définitive"],
  ["GET",   "/partners",                      "Catalogue paginé (?query&category&status&page&size)"],
  ["GET",   "/partners/{id}",                 "Fiche partenaire"],
  ["PATCH", "/partners/{id}",                 "Change le statut — réservé à l'administration"],
  ["GET",   "/partners/{id}/transactions",    "Encaissements du partenaire (?since)"],
  ["POST",  "/transactions/{ref}/cancel",     "Annule une écriture par une écriture inverse chaînée"],
  ["POST",  "/topups",                        "Rechargement employeur ou régularisation"],
  ["GET",   "/claims",                        "Réclamations (?employeeId&status&open)"],
  ["GET",   "/claims/{id}",                   "Réclamation et fil de messages"],
  ["POST",  "/claims",                        "Ouvre une réclamation côté salarié"],
  ["POST",  "/claims/{id}/messages",          "Ajoute un message au fil"],
  ["PATCH", "/claims/{id}",                   "Instruit la réclamation, avec régularisation éventuelle"],
  ["GET",   "/admin/stats",                   "Indicateurs nationaux"],
  ["GET",   "/ledger/verify",                 "Vérifie la chaîne d'empreintes du registre"]
];

/* ---- Exécution ------------------------------------------------------------ */
const logs = [];
const logListeners = new Set();
const wait = ms => new Promise(r => setTimeout(r, ms));

function parseQuery(path) {
  const i = path.indexOf("?");
  if (i < 0) return { clean: path, q: {} };
  const q = {};
  new URLSearchParams(path.slice(i + 1)).forEach((v, k) => { q[k] = v; });
  return { clean: path.slice(0, i), q };
}

function finish(method, path, status, body, t0, bad) {
  const entry = { id: logs.length + 1, method, path, status, body,
                  ms: Math.round(performance.now() - t0), at: Date.now(), bad };
  logs.push(entry);
  if (logs.length > 240) logs.shift();
  logListeners.forEach(fn => fn(entry));
  return body;
}

async function call(method, path, body) {
  const t0 = performance.now();
  const full = "/api/v1" + path;
  const { clean, q } = parseQuery(path);
  const route = ROUTES.find(r => r.m === method && r.p.test(clean));
  if (!route) return finish(method, full, 404, { error: "no_route", message: "Endpoint inconnu" }, t0, true);

  await wait(60 + Math.random() * 120);
  try {
    const out = route.h(clean.match(route.p), body || {}, q);
    if (method !== "GET") store.save(); else store.notify();
    return finish(method, full, method === "POST" ? 201 : 200, out, t0, false);
  } catch (e) {
    finish(method, full, e.status || 500, e.body || { error: "server_error", message: e.message }, t0, true);
    throw e;
  }
}

export const API = {
  call,
  get: (p, q) => call("GET", p + (q ? "?" + new URLSearchParams(clean(q)) : "")),
  post: (p, b) => call("POST", p, b),
  patch: (p, b) => call("PATCH", p, b),
  logs,
  doc: DOC,
  onLog(fn) { logListeners.add(fn); return () => logListeners.delete(fn); },
  clear() { logs.length = 0; logListeners.forEach(fn => fn(null)); }
};

function clean(q) {
  const out = {};
  Object.keys(q).forEach(k => { if (q[k] !== undefined && q[k] !== null && q[k] !== "") out[k] = q[k]; });
  return out;
}

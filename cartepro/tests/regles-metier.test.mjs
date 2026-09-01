/* ============================================================================
   Les cinq règles métier non négociables (§3 du cahier des charges v2.0).

   Chaque test échoue si la règle est retirée du code — c'est leur seule raison
   d'être. Ils s'exécutent sur la couche API réelle, pas sur des doublures.

       node --test tests/
   ========================================================================= */

import test from "node:test";
import assert from "node:assert/strict";
import { API, store, emp } from "../lib/api.js";
import { verifyLedger, TOKEN_TTL } from "../lib/data.js";

const SALARIE = "SAL-0042";
const PARTENAIRE = "PRT-001";

function reinitialiser() {
  store.reset();
  return store.db;
}

async function jeton(employeeId = SALARIE) {
  const t = await API.post("/payment-tokens", { employeeId });
  return t.token;
}

/* -- R1 — Immuabilité ------------------------------------------------------ */

test("R1 · une transaction validée n'est ni modifiée ni supprimée", async () => {
  const db = reinitialiser();
  const token = await jeton();
  const txn = await API.post("/transactions", { token, partnerId: PARTENAIRE, amount: 1234 });

  const ecrite = db.txns.find(t => t.ref === txn.ref);
  const empreinte = ecrite.hash;
  const montant = ecrite.amount;
  const avant = db.txns.length;

  // Aucune route n'accepte de modifier une écriture.
  await assert.rejects(() => API.call("PATCH", "/transactions/" + txn.ref, { amount: 1 }));
  await assert.rejects(() => API.call("DELETE", "/transactions/" + txn.ref));

  assert.equal(db.txns.length, avant, "aucune écriture n'a disparu");
  assert.equal(ecrite.amount, montant, "le montant est inchangé");
  assert.equal(ecrite.hash, empreinte, "l'empreinte est inchangée");
  assert.equal(verifyLedger(db).ok, true, "la chaîne reste vérifiable");
});

test("R1 · annuler ajoute une écriture inverse, sans toucher l'originale", async () => {
  const db = reinitialiser();
  const token = await jeton();
  const txn = await API.post("/transactions", { token, partnerId: PARTENAIRE, amount: 2500 });

  const originale = db.txns.find(t => t.ref === txn.ref);
  const empreinte = originale.hash;
  const soldeApresPaiement = emp(SALARIE).balance;
  const avant = db.txns.length;

  const rev = await API.post("/transactions/" + txn.ref + "/cancel",
    { reason: "double encaissement constaté", author: "Agent test" });

  assert.equal(db.txns.length, avant + 1, "l'annulation est une écriture DE PLUS");
  assert.equal(rev.kind, "reversal");
  assert.equal(rev.reverses, txn.ref, "l'inverse référence l'écriture compensée");
  assert.equal(originale.amount, 2500, "le montant d'origine est intact");
  assert.equal(originale.hash, empreinte, "l'empreinte d'origine est intacte");
  assert.equal(emp(SALARIE).balance, soldeApresPaiement + 2500, "le bénéficiaire est recrédité");
  assert.equal(verifyLedger(db).ok, true, "la chaîne reste vérifiable après annulation");

  // Une annulation ne s'annule pas, et une écriture déjà annulée non plus.
  await assert.rejects(() => API.post("/transactions/" + rev.ref + "/cancel", { reason: "essai" }),
    e => e.status === 409);
  await assert.rejects(() => API.post("/transactions/" + txn.ref + "/cancel", { reason: "essai" }),
    e => e.status === 409);
});

/* -- R2 — Solde jamais négatif --------------------------------------------- */

test("R2 · un débit supérieur au solde est refusé, et le solde ne bouge pas", async () => {
  const db = reinitialiser();
  const solde = emp(SALARIE).balance;
  const token = await jeton();
  const avant = db.txns.length;

  await assert.rejects(
    () => API.post("/transactions", { token, partnerId: PARTENAIRE, amount: solde + 1 }),
    e => {
      assert.equal(e.status, 402, "le refus est un 402 Payment Required");
      assert.equal(e.body.error, "insufficient_funds");
      assert.match(e.body.message, /Solde insuffisant/, "le message explique le refus");
      assert.match(e.body.message, /simulation/i, "le message porte la mention de simulation");
      return true;
    });

  assert.equal(emp(SALARIE).balance, solde, "le solde est inchangé");
  assert.equal(db.txns.length, avant, "aucune écriture n'a été passée");
});

test("R2 · le solde ne peut pas devenir négatif à l'euro près", async () => {
  reinitialiser();
  const solde = emp(SALARIE).balance;
  const token = await jeton();
  await API.post("/transactions", { token, partnerId: PARTENAIRE, amount: solde });
  assert.equal(emp(SALARIE).balance, 0, "le solde tombe exactement à zéro");

  const token2 = await API.post("/payment-tokens", { employeeId: SALARIE })
    .then(t => t.token, e => { assert.equal(e.status, 402); return null; });
  assert.equal(token2, null, "un solde nul n'émet plus de jeton");
});

/* -- R3 — Idempotence ------------------------------------------------------ */

test("R3 · le rejeu d'un encaissement renvoie la même transaction, sans doubler", async () => {
  const db = reinitialiser();
  const token = await jeton();
  const solde = emp(SALARIE).balance;
  const cle = "poste-caisse-3:2026-09-01T10:15:00Z:0001";

  const premier = await API.post("/transactions",
    { token, partnerId: PARTENAIRE, amount: 1800, idempotencyKey: cle });
  const apresUn = db.txns.length;

  const second = await API.post("/transactions",
    { token, partnerId: PARTENAIRE, amount: 1800, idempotencyKey: cle });

  assert.equal(second.ref, premier.ref, "même identifiant de transaction");
  assert.equal(db.txns.length, apresUn, "aucune écriture supplémentaire");
  assert.equal(emp(SALARIE).balance, solde - 1800, "le bénéficiaire n'est débité qu'une fois");
});

test("R3 · sans clé d'idempotence, un jeton déjà consommé est refusé (pas doublé)", async () => {
  const db = reinitialiser();
  const token = await jeton();
  await API.post("/transactions", { token, partnerId: PARTENAIRE, amount: 900 });
  const apres = db.txns.length;

  await assert.rejects(
    () => API.post("/transactions", { token, partnerId: PARTENAIRE, amount: 900 }),
    e => e.status === 409 && e.body.error === "token_used");
  assert.equal(db.txns.length, apres, "aucune écriture supplémentaire");
});

/* -- R4 — Code de paiement ------------------------------------------------- */

test("R4 · le jeton vaut 5 minutes, un seul usage", async () => {
  const db = reinitialiser();
  assert.equal(TOKEN_TTL, 5 * 60e3, "la validité est de cinq minutes");

  const token = await jeton();
  const enregistre = db.tokens.find(t => t.token === token);
  assert.ok(enregistre.expiresAt - enregistre.issuedAt === TOKEN_TTL);

  await API.post("/transactions", { token, partnerId: PARTENAIRE, amount: 500 });
  assert.ok(enregistre.usedAt, "le jeton est marqué consommé");

  await assert.rejects(() => API.get("/payment-tokens/" + token), e => e.status === 409);
});

test("R4 · un jeton périmé est refusé", async () => {
  const db = reinitialiser();
  const token = await jeton();
  db.tokens.find(t => t.token === token).expiresAt = Date.now() - 1;

  await assert.rejects(
    () => API.post("/transactions", { token, partnerId: PARTENAIRE, amount: 500 }),
    e => e.status === 410 && e.body.error === "token_expired");
});

/* -- R5 — Concurrence ------------------------------------------------------ */

test("R5 · deux encaissements simultanés ne peuvent pas passer tous les deux", async () => {
  const db = reinitialiser();
  const salarie = emp(SALARIE);
  salarie.balance = 5000;                       // de quoi n'en honorer qu'un seul

  const a = await jeton();
  const b = await jeton();
  const avant = db.txns.length;

  const resultats = await Promise.allSettled([
    API.post("/transactions", { token: a, partnerId: PARTENAIRE, amount: 4000 }),
    API.post("/transactions", { token: b, partnerId: PARTENAIRE, amount: 4000 })
  ]);

  const passes = resultats.filter(r => r.status === "fulfilled");
  const refuses = resultats.filter(r => r.status === "rejected");

  assert.equal(passes.length, 1, "exactement un encaissement aboutit");
  assert.equal(refuses.length, 1, "l'autre est refusé");
  assert.equal(refuses[0].reason.status, 402, "et il est refusé pour solde insuffisant");
  assert.equal(db.txns.length, avant + 1, "une seule écriture est passée");
  assert.equal(salarie.balance, 1000, "le solde reflète un seul débit");
  assert.ok(salarie.balance >= 0, "le solde n'est jamais négatif");
});

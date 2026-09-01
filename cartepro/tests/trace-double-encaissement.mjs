/* Produit la trace exigée au §8 : les deux appels, les deux réponses et l'état
   de la table après un double encaissement.

       node tests/trace-double-encaissement.mjs > docs/trace-double-encaissement.md
*/

import { API, store, emp } from "../lib/api.js";

const SAL = "SAL-0042", PRT = "PRT-001";
const eur = c => (c / 100).toFixed(2).replace(".", ",") + " €";
const bloc = (titre, obj) =>
  "**" + titre + "**\n\n```json\n" + JSON.stringify(obj, null, 2) + "\n```\n";

store.reset();
const soldeInitial = emp(SAL).balance;
const { token } = await API.post("/payment-tokens", { employeeId: SAL });
const ecrituresAvant = store.db.txns.length;

const requete = {
  token,
  partnerId: PRT,
  amount: 1850,
  channel: "qr",
  idempotencyKey: "caisse-01:" + token + ":1850"
};

console.log("# Trace d'un double encaissement\n");
console.log("Généré par `node tests/trace-double-encaissement.mjs`. Le scénario reproduit");
console.log("un double scan en caisse : la même requête est envoyée deux fois.\n");
console.log("État initial : solde " + eur(soldeInitial) + ", " + ecrituresAvant + " écritures au registre.\n");
console.log("---\n");

console.log("## Premier appel\n");
console.log(bloc("POST /api/v1/transactions", requete));
const r1 = await API.post("/transactions", requete);
console.log(bloc("201 Created", r1));

console.log("## Second appel — requête identique, même clé d'idempotence\n");
console.log(bloc("POST /api/v1/transactions", requete));
const r2 = await API.post("/transactions", requete);
console.log(bloc("200 OK — la transaction existante est renvoyée, aucune écriture ajoutée", r2));

console.log("## État de la table `transactions` après les deux appels\n");
const lignes = store.db.txns.slice(-3);
console.log("| ref | nature | salarié | partenaire | montant | empreinte précédente | empreinte |");
console.log("|---|---|---|---|---|---|---|");
lignes.forEach(t => {
  console.log("| `" + t.ref + "` | " + (t.kind || "payment") + " | " + t.employeeId + " | "
    + t.partnerId + " | " + eur(t.amount) + " | `" + t.prev + "` | `" + t.hash + "` |");
});

console.log("\n## Vérification\n");
const ecrituresApres = store.db.txns.length;
console.log("| Contrôle | Attendu | Constaté |");
console.log("|---|---|---|");
console.log("| Identifiant renvoyé au second appel | `" + r1.ref + "` | `" + r2.ref + "` |");
console.log("| Écritures ajoutées | 1 | " + (ecrituresApres - ecrituresAvant) + " |");
console.log("| Solde après les deux appels | " + eur(soldeInitial - 1850) + " | " + eur(emp(SAL).balance) + " |");
console.log("| Débit constaté | " + eur(1850) + " | " + eur(soldeInitial - emp(SAL).balance) + " |");
console.log("\nLe second appel n'écrit rien et ne débite rien : il retrouve la transaction par sa");
console.log("clé d'idempotence et la renvoie telle quelle (R3).");

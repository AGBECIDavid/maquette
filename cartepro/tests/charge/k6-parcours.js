/* ============================================================================
   Test de charge du parcours nominal (§8, semaine 2).

   S'exécute en local, sans service tiers :
       k6 run tests/charge/k6-parcours.js

   Le démonstrateur n'ayant pas encore de backend, ce scénario vise l'instance
   Next servie localement : il mesure le temps de réponse des pages et de la
   sonde de vie. Une fois l'API réelle en place, remplacer les `http.get` de
   pages par les appels d'API commentés en bas de fichier — le scénario et les
   seuils restent valables.
   ========================================================================= */

import http from "k6/http";
import { check, sleep, group } from "k6";

const BASE = __ENV.BASE_URL || "http://localhost:3000";

export const options = {
  scenarios: {
    parcours_salarie: {
      executor: "ramping-vus",
      startVUs: 0,
      stages: [
        { duration: "30s", target: 20 },   // montée
        { duration: "1m",  target: 20 },   // palier
        { duration: "30s", target: 60 },   // pointe : pause déjeuner
        { duration: "1m",  target: 60 },
        { duration: "30s", target: 0 }
      ]
    }
  },
  thresholds: {
    // §5.4 : génération d'un code en moins de 2 secondes. La marge est prise
    // sur le 95ᵉ centile, pas sur la moyenne : c'est l'utilisateur le plus mal
    // servi qui compte.
    "http_req_duration{page:code}": ["p(95)<2000"],
    "http_req_duration": ["p(95)<1500"],
    "http_req_failed": ["rate<0.01"],
    "checks": ["rate>0.99"]
  }
};

export default function () {
  group("page publique", () => {
    const r = http.get(`${BASE}/`, { tags: { page: "accueil" } });
    check(r, { "accueil 200": x => x.status === 200 });
  });

  group("espace salarié", () => {
    const solde = http.get(`${BASE}/salarie/`, { tags: { page: "solde" } });
    check(solde, { "solde 200": x => x.status === 200 });

    const code = http.get(`${BASE}/salarie/payer/`, { tags: { page: "code" } });
    check(code, {
      "écran de code 200": x => x.status === 200,
      "écran de code sous 2 s (§5.4)": x => x.timings.duration < 2000
    });
  });

  group("catalogue", () => {
    const cat = http.get(`${BASE}/salarie/partenaires/`, { tags: { page: "catalogue" } });
    check(cat, { "catalogue 200": x => x.status === 200 });
  });

  group("sonde", () => {
    const h = http.get(`${BASE}/health`, { tags: { page: "health" } });
    check(h, {
      "health 200": x => x.status === 200,
      "health annonce la simulation": x => x.json("simulation") === true
    });
  });

  sleep(1 + Math.random() * 2);
}

/* Une fois l'API réelle branchée, le cœur du scénario devient :

   const session = http.post(`${BASE}/api/v1/auth/login`,
     JSON.stringify({ email, password }), { headers: { "Content-Type": "application/json" } });
   const jeton = http.post(`${BASE}/api/v1/payment-tokens`,
     JSON.stringify({ employeeId }), { tags: { page: "code" } });
   const txn = http.post(`${BASE}/api/v1/transactions`,
     JSON.stringify({ token, partnerId, amount, idempotencyKey }));

   Le seuil p(95) < 2000 sur le tag `code` reste la traduction directe du §5.4.
*/

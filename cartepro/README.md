# CartePro

Démonstrateur du dispositif décrit dans le **cahier des charges consolidé
JEB/DNI/2026-002 v2.0**. Application Next.js, sans backend : la couche API est
simulée côté navigateur, mais elle parle en chemins REST et en codes HTTP.

```bash
npm install
npm run dev            # http://localhost:3000
npm test               # les cinq règles métier (§3)
npm run build          # export statique dans out/
npm run trace          # régénère docs/trace-double-encaissement.md
npm run preview:build  # version monofichier : preview/dist/index.html
```

**Critère de recette (§5.2)** : ces commandes suffisent. Aucun compte tiers, aucun
service managé, aucune clé à demander. `curl localhost:3000/health` répond l'état et la
version.

## Livrables

| Livrable | Fichier | État |
|---|---|---|
| Spécification OpenAPI 3.0 | `public/openapi.yaml` | fait |
| Swagger UI sur l'instance | `/api-docs` | fait, avec repli si le CDN ne répond pas |
| Schéma de base de données | `docs/schema.sql` | schéma **cible** — voir réserve ci-dessous |
| `.env.example`, `/health` | `.env.example`, `app/health/route.js` | fait |
| Trois tests automatisés (R1, R2, R3) | `tests/regles-metier.test.mjs` | fait — 9 tests, R4 et R5 compris |
| Trace d'un double encaissement | `docs/trace-double-encaissement.md` | fait, généré par exécution |
| Note de concurrence | `docs/note-concurrence.md` | fait |
| Note de déploiement | `docs/note-deploiement.md` | fait |
| Fiche de registre RGPD | `docs/registre-rgpd.md` | projet, deux arbitrages à valider |
| Déclaration d'accessibilité | `docs/declaration-accessibilite.md` | projet — audit RGAA non réalisé |
| Projet de CGU | `docs/projet-cgu.md` | projet, trois points à trancher |
| Captures de la mention de simulation | `docs/captures-simulation/` | fait, une par emplacement |
| Test de charge | `tests/charge/k6-parcours.js` | fait |
| Vidéo de présentation | — | **non fait** |

### Réserves à porter au cabinet

- **Le schéma n'est pas généré depuis une base réelle**, puisqu'il n'y en a pas encore.
  `docs/schema.sql` est la source qui produira cette base ; le livrable « généré depuis
  la base » ne pourra être fourni qu'après la première migration.
- **La vidéo n'est pas produite.** Elle exige une capture de l'application réelle en
  fonctionnement, ce que ce dépôt ne fabrique pas. Le script minuté reste à écrire.
- **L'audit RGAA n'a pas eu lieu.** La déclaration dit « non conforme » plutôt que
  « partiellement conforme » : annoncer un taux sans l'avoir mesuré serait faux.

## Les cinq règles métier (§3)

Chacune est couverte par un test qui échoue si la règle disparaît du code.

| Règle | Ce qu'elle garantit | Où |
|---|---|---|
| R1 Immuabilité | Une écriture validée n'est ni modifiée ni supprimée ; une correction est une écriture inverse | `lib/api.js` · déclencheur SQL au schéma |
| R2 Solde jamais négatif | Un débit supérieur au solde est refusé, avec un message qui dit les deux montants | `lib/api.js` · `CHECK (solde >= 0)` au schéma |
| R3 Idempotence | Un double scan ne débite qu'une fois ; la même clé renvoie la même transaction | `lib/api.js` · unicité de la clé au schéma |
| R4 Code de paiement | Usage unique, cinq minutes, régénérable | `lib/data.js` (`TOKEN_TTL`) |
| R5 Concurrence | Deux encaissements simultanés ne peuvent pas passer tous les deux | verrou par bénéficiaire · `docs/note-concurrence.md` |

## Arbitrages appliqués (§7)

| Sujet | Décision retenue | Où le voir |
|---|---|---|
| Mention de simulation | Partout où un montant s'affiche, titre d'onglet et exports compris | `docs/captures-simulation/` |
| Validité du code | 5 minutes + bouton de régénération | `/salarie/payer` |
| Annulation | Écriture inverse, jamais de suppression | `/admin/registre` |
| Validation partenaire | Le ministre décide, la décision est tracée et motivée | `/admin/validations` |
| Sécurité transactionnelle | Cinq règles maintenues, testées | `npm test` |
| Endpoint solde | Maintenu, contrat figé | `GET /api/v1/employees/{id}/balance` |
| Connectivité limitée | File d'attente et message explicite, jamais d'échec silencieux | bouton « Réseau limité » |
| Nom affiché | **CartePro** partout | `grep -ri "ticket tout"` — aucune occurrence |
| Catégories | En base, servies par l'API | `GET /api/v1/categories` |
| Sélection du Ministre, badge officiel, ton positif | Retenus | `/admin/vitrine` |

## Parcours

```
/                     accueil public, Sélection du Ministre
/connexion            l'adresse détermine l'espace ouvert
/inscription          salarié (code employeur) ou partenaire (SIREN + objet social)
/salarie              budget · payer · historique · partenaires · mes demandes
/partenaire           tableau de bord · encaisser · transactions · catalogue · compte
/admin                bord · validations · Sélection du Ministre · salariés ·
                      réclamations · comptes · rechargements · registre · API
/api-docs             Swagger UI          /health   sonde de vie
```

La barre noire en bas de page pilote la démonstration : espace, appareil
(**smartphone / tablette / ordinateur**), réseau limité, console API, réinitialisation.

## Comptes de démonstration

| Rôle | Adresse |
|---|---|
| Ministre (administration) | `je.berlier@job-et-bonheur.fr` |
| Conseiller numérique | `t.vignal@job-et-bonheur.fr` |
| Salariée | `a.berthier@vallonis.fr` |
| Partenaire | `contact@poneydream78.fr` |

Le mot de passe n'est pas vérifié : seule l'adresse identifie le compte — c'est une
limite du démonstrateur, signalée dans la note de déploiement. Codes employeurs :
`VALLONIS-2026`, `ARDENNE-2026`.

## Organisation du code

```
lib/          domaine, sans React
  qr.js         encodeur QR (ISO/IEC 18004, mode octet, niveau M, versions 1-4)
  data.js       schéma, jeu de démonstration à graine fixe, TOKEN_TTL
  api.js        magasin observable + API REST simulée (routes, codes, verrou, journal)
  format.js     formats français, empreintes
  app.jsx       liaison React : session, navigation, notifications, aperçu appareil
components/   coquille, barre de pilotage, console, briques d'interface
screens/      Landing · Auth · Employee · Partner · Admin · ApiDocs
app/          routes Next + /health
tests/        règles métier, trace, charge
docs/         livrables juridiques, techniques et captures
```

**Aucun écran n'écrit dans les données** : tout passe par `API.call`. Brancher un vrai
backend revient à remplacer le corps de cette fonction par un `fetch`.

**L'adaptation aux écrans passe par des requêtes de conteneur** (`@container`) : la mise
en page réagit à la largeur du châssis, donc l'aperçu smartphone montre la vraie version
adaptative, pas une réduction d'échelle.

**Les montants sont des entiers, en centimes.** Aucun flottant n'entre dans une somme
d'argent, du seed jusqu'à l'export CSV.

## Versions précédentes

`archive/cartepro-v1.0/` conserve la version issue du cahier des charges v1.0. La
version v1.1 (nom de travail *Ticket Tout*, retenu puis écarté par l'arbitrage §7) reste
dans l'historique git, au commit « Add Ticket Tout, the minister's version of the brief ».

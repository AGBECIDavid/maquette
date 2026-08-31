# CartePro

Démonstrateur du dispositif décrit dans le cahier des charges **JEB/DNI/2026-002**
(Ministère du Job et Bonheur, Direction du Numérique et de l'Innovation).
Application Next.js, sans backend : la couche API est simulée côté navigateur.

```bash
npm install
npm run dev            # http://localhost:3000
npm run build          # export statique dans out/
npm run preview:build  # version monofichier : preview/dist/index.html
```

## Parcours

```
/                     écran d'ouverture animé, présentation du dispositif
/connexion            connexion (l'adresse détermine l'espace ouvert)
/inscription          salarié (code employeur) ou partenaire (soumis à validation)
/salarie              accueil · payer · historique · partenaires · mes demandes
/partenaire           tableau de bord · encaisser · transactions · catalogue · compte
/admin                bord · validations · salariés · réclamations · comptes ·
                      rechargements · registre · API
```

La barre noire en bas de page pilote la démonstration : changer d'espace, changer
d'appareil (**smartphone / tablette / ordinateur**), simuler une coupure réseau,
ouvrir la console API, réinitialiser les données.

## La relation administration ↔ salarié

C'était le maillon manquant : l'administration n'atteignait le salarié qu'à
travers son employeur. Elle dispose maintenant de deux prises directes.

**Les réclamations.** Le salarié ouvre une demande depuis son espace — librement,
ou depuis une opération de son historique, qui pré-remplit la référence contestée.
L'agent la retrouve dans sa file, répond dans le même fil, et clôture de trois
façons : sans mouvement, en rejetant avec un motif, ou **en régularisant** — le
montant est alors crédité immédiatement au solde et tracé comme régularisation,
distincte d'une dotation. Le salarié voit la réponse et le crédit dans son espace.

**La fiche salarié.** Solde, total crédité, total dépensé, opérations, crédits
reçus et réclamations sur un même écran ; suspension, réactivation, clôture du
compte et régularisation directe avec motif. Un compte suspendu ne peut plus
émettre de jeton — la règle est appliquée par l'API, pas par l'interface.

Une transaction validée reste inaltérable : la régularisation est le seul
mouvement inverse possible, et c'est une écriture de plus, jamais une correction
de l'ancienne.

## Ce qui répond au cahier des charges

| Exigence | Où la voir |
|---|---|
| Solde en temps réel après chaque transaction (§2.2) | Le partenaire valide, le solde du salarié change à l'instant : les trois espaces partagent un registre |
| QR de paiement (§2.1) | `/salarie/payer` — **réellement scannable** : encodeur ISO/IEC 18004 embarqué, sortie vérifiée par décodage |
| Numéro lisible sous le QR | Groupes de quatre + bouton **Copier**, pour dicter le jeton quand la caméra ne répond pas |
| Connectivité dégradée (§2.2) | *Mode dégradé* : jeton produit localement, encaissement mis en file, rejoué à la reconnexion |
| Jeton usage unique, 5 min (§3.2) | Compte à rebours ; rejeu → `409 token_used`, périmé → `410 token_expired` |
| Validation manuelle des adhésions (§2.2) | Inscription partenaire → `/admin/validations` |
| Transactions irréversibles (§2.2, §3.2) | `/admin/registre` : chaîne d'empreintes, vérification, falsification simulée |
| Catalogue paginé (§3.4) | Espaces salarié et partenaire, recherche et filtres côté « serveur » |
| API REST documentée, JSON (§3.1, §3.3) | `/admin/api` et console en bas de page |
| Point d'entrée SIRH (§3.3) | `GET /api/v1/employees/{id}/balance` |
| Rechargements employeurs (§2.1) | `/admin/recharges`, individuels ou par lot |
| Responsive (§3.1) | Aperçu smartphone / tablette / ordinateur dans la barre de pilotage |
| Authentification multi-rôles (§3.1) | Trois espaces disjoints, session conservée |

## Organisation du code

```
lib/      domaine, sans React
  qr.js       encodeur QR (ISO/IEC 18004, mode octet, niveau M, versions 1-4)
  data.js     schéma et jeu de démonstration à graine fixe
  api.js      magasin observable + API REST simulée (routes, codes HTTP, journal)
  format.js   formats français, empreintes
  icons.jsx   jeu d'icônes
  app.jsx     liaison React : session, navigation, notifications, aperçu appareil
components/  coquille, barre de pilotage, console, briques d'interface
screens/     Landing · Auth · Employee · Partner · Admin
app/         routes Next (enveloppes de quelques lignes autour des écrans)
preview/     point d'entrée du build monofichier
```

**Aucun écran n'écrit dans les données** : tout passe par `API.call`, qui parle en
chemins REST et en codes HTTP. Brancher un vrai backend revient à remplacer le
corps de cette fonction par un `fetch` ; les écrans ne changent pas.

**La navigation est abstraite** derrière `useNav` : l'application Next la branche
sur son routeur, le build monofichier sur le fragment d'URL. Un seul jeu d'écrans
sert les deux.

**L'adaptation aux écrans passe par des requêtes de conteneur** (`@container`) et
non par des requêtes de média : la mise en page réagit à la largeur du châssis,
donc l'aperçu smartphone montre la vraie version adaptative, pas une réduction
d'échelle.

**Les montants sont des entiers, en centimes.** Aucun flottant n'entre dans une
somme d'argent.

## Ce qui reste à faire pour la version réelle

- Backend et base relationnelle : le schéma de `lib/data.js` se transpose en tables.
- Authentification réelle : mots de passe, sessions serveur, HTTPS/HSTS. Ici
  l'adresse suffit à ouvrir une session, et le mot de passe n'est pas vérifié.
- L'empreinte de chaînage est un FNV-1a 32 bits : elle démontre le principe sans
  le garantir. En production, SHA-256 et journal append-only.
- Fond cartographique réel pour « Partenaires » (ici, un plan schématique).
- Reversement aux partenaires, exports comptables, RGPD.

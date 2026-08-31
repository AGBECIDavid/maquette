# CartePro — maquette dynamique

Démonstrateur fonctionnel du dispositif décrit dans le cahier des charges
**JEB/DNI/2026-002** (Ministère du Job et Bonheur, Direction du Numérique et de
l'Innovation). Un seul fichier, `index.html` : aucune dépendance, aucun build,
aucun accès réseau requis.

```bash
# ouvrir directement
xdg-open index.html
# ou servir, si votre navigateur bloque le stockage local sur file://
python3 -m http.server 8000
```

## Ce qui est démontrable, écran par écran

La barre noire en bas de page pilote la démonstration : elle change d'espace,
active le **mode dégradé**, ouvre la **console API** et réinitialise les données.

| Exigence du cahier des charges | Où la voir |
|---|---|
| Solde affiché en temps réel après chaque transaction (§2.2) | Le partenaire valide, le solde du salarié change à l'instant même — les deux espaces partagent le même registre |
| QR de paiement (§2.1) | Espace salarié → *Payer*. Le QR est **réellement scannable** : encodeur ISO/IEC 18004 écrit dans la page, vérifié au décodage |
| Fonctionnement en connectivité dégradée (§2.2) | Bouton *Mode dégradé* : le jeton est produit localement, l'encaissement part en file d'attente, la synchronisation le rejoue au retour du réseau |
| Jeton à usage unique, 5 minutes (§3.2) | Compte à rebours sur le QR ; un jeton rejoué renvoie `409 token_used`, un jeton périmé `410 token_expired` |
| Validation manuelle des adhésions (§2.2) | Espace partenaire → *Mon compte* → demande d'adhésion ; espace administration → *Validations* |
| Transactions irréversibles et inaltérables (§2.2, §3.2) | Administration → *Registre* : chaîne d'empreintes, vérification, et une falsification simulée qui montre la rupture détectée |
| Catalogue paginé (§3.4) | Espaces salarié et partenaire ; recherche, filtre par catégorie, pagination côté « serveur » |
| API REST documentée, JSON (§3.1, §3.3) | Administration → *API* et console en bas de page : chaque geste de l'interface y écrit sa requête |
| Point d'entrée SIRH employeur (§3.3) | `GET /api/v1/employees/{id}/balance` — testable depuis la page *API* |
| Rechargements employeurs (§2.1) | Administration → *Rechargements*, individuels ou par lot |
| Application responsive (§3.1) | Le même code sert le châssis mobile de l'espace salarié et les consoles bureau |
| Authentification multi-rôles (§3.1) | Écran d'accueil : trois espaces disjoints, session conservée |

## Comment c'est construit

```
index.html
├─ 1. Utilitaires (formats français, empreintes, icônes)
├─ 2. Encodeur QR — mode octet, niveau M, versions 1 à 4
├─ 3. Données : schéma relationnel sérialisé dans le stockage local
├─ 4. API REST simulée — table de routage, codes HTTP, journal
├─ 5. Briques d'interface : notifications, fenêtres, pagination, graphiques
├─ 6. Espace salarié      (châssis mobile)
├─ 7. Espace partenaire   (console bureau)
├─ 8. Espace administration
└─ 9. Coquille : session, rôles, console, amorçage
```

**Aucune vue n'écrit dans les données.** Tout passe par la couche 4, qui parle
en chemins REST et en codes HTTP. C'est ce qui rend le passage à un vrai
backend mécanique : on remplace le corps de `API.call` par un `fetch`, le reste
ne bouge pas. La table `API.doc` est la documentation des points d'entrée, et
elle est affichée dans l'interface plutôt que recopiée ailleurs.

**Les montants sont des entiers, en centimes.** Aucun flottant n'entre dans une
somme d'argent.

**Le QR est encodé sur place** plutôt qu'importé d'un CDN : le cahier des
charges exige qu'il fonctionne en connectivité dégradée, et une bibliothèque
distante contredirait cette exigence. L'encodeur a été vérifié en décodant le
rendu (OpenCV), à pleine résolution, à la taille d'affichage et flouté.

## Ce qui reste à faire pour la version réelle

- Backend et base relationnelle : le schéma des objets de la couche 3 est
  transposable tel quel en tables.
- Authentification (mots de passe, sessions serveur, HTTPS/HSTS) : la maquette
  simule les rôles sans les vérifier.
- L'empreinte de chaînage est un FNV-1a 32 bits — elle démontre le principe,
  elle ne le garantit pas. En production : SHA-256 et journal en append-only.
- Fond cartographique réel pour « Autour de moi » (ici, un plan schématique).
- Reversement aux partenaires, exports comptables, RGPD.

# Ticket Tout

Démonstrateur du dispositif décrit dans le cahier des charges **JEB/DNI/2026-002
version 1.1** — celle annotée à la main par le ministre Jean-Eudes Berlier.
Application Next.js, sans backend : la couche API est simulée côté navigateur.

```bash
npm install
npm run dev            # http://localhost:3000
npm run build          # export statique dans out/
npm run preview:build  # version monofichier : preview/dist/index.html
```

> La version 1.0 du dispositif (nom de travail **CartePro**) reste disponible
> intacte dans `../cartepro`. Les deux projets sont indépendants : ils ne
> partagent ni code, ni stockage local, ni données.

## Ce que la version 1.1 change, et pourquoi

Le ministre a repris le document de la Direction des Systèmes d'Information et
en a rayé une partie. Voici ce qui a été appliqué, annotation par annotation.

| Annotation du ministre | Traduction dans l'application |
|---|---|
| « CartePro était le nom de travail. Je l'appelle le Ticket Tout. » | Renommage complet, jusqu'au préfixe des jetons (`TT1\|…`) et à la clé de stockage |
| Les partenaires qu'il a choisis lui-même | Poney Dream 78, KostumParty, Glaces Artisanales Corrèze, Chapelier Fontaine au catalogue ; six autres « en cours de signature », donc en attente de validation |
| « Ajoutez une section Choix du Ministre » | `/admin/vitrine` : une bascule par partenaire et un mot signé, repris tel quel sur l'accueil salarié **et** sur la page publique |
| « Badge Partenaire Officiel du Ministère » | Sceau affiché sur la fiche partenaire, dans son espace, au catalogue et sur la page publique |
| « Bouton Featured, sans passer par votre équipe » | La mise en avant est une action d'interface, pas un déploiement : `PATCH /partners/{id}/featured` |
| « Le solde doit être affiché POSITIVEMENT » | « 345,23 € **à dépenser chez vos partenaires préférés !** » sur la carte |
| « Le QR ne doit pas expirer en 5 minutes » | Validité portée à **30 minutes** (`TOKEN_TTL`), usage unique conservé |
| « Le mode dégradé, c'est Thomas qui stresse » | Mode dégradé retiré : plus de file d'attente hors ligne, plus de bascule réseau |
| « L'interopérabilité SIRH ne sert à rien » | Point d'entrée `/employees/{id}/balance` retiré de l'API et de sa documentation |
| « Je dois pouvoir annuler avec mon compte admin » | Voir ci-dessous — c'est la seule demande qui entrait en conflit avec une autre |
| « J'active les partenaires moi-même, je suis l'admin » | Le compte par défaut de l'administration est celui du ministre |

### Annuler sans renoncer à l'inaltérabilité

Deux exigences se contredisent en apparence : les transactions doivent être
**irréversibles une fois validées** (§2.2, conservée), et le ministre veut
**pouvoir annuler**.

Elles ne se contredisent que si annuler veut dire *effacer*. Ici, annuler
ajoute une **écriture inverse** : une transaction de nature `reversal`, chaînée
comme les autres, qui référence celle qu'elle compense et recrédite le salarié.
L'écriture d'origine n'est pas touchée — elle porte simplement la référence de
son annulation. Le contrôle d'intégrité du registre reste vert après une
annulation, et c'est vérifiable en deux clics dans `/admin/registre`.

C'est la règle comptable ordinaire : on ne gomme pas une écriture, on en passe
une contraire.

## Parcours

```
/                     écran d'ouverture animé, présentation, Choix du Ministre
/connexion            l'adresse détermine l'espace ouvert
/inscription          salarié (code employeur) ou partenaire (soumis à validation)
/salarie              accueil · payer · historique · partenaires · mes demandes
/partenaire           tableau de bord · encaisser · transactions · catalogue · compte
/admin                bord · validations · Choix du Ministre · salariés ·
                      réclamations · comptes · rechargements · registre · API
```

La barre noire en bas de page pilote la démonstration : changer d'espace,
changer d'appareil (**smartphone / tablette / ordinateur**), ouvrir la console
API, réinitialiser les données.

## Comptes de démonstration

| Rôle | Adresse |
|---|---|
| Ministre (administration) | `je.berlier@job-et-bonheur.fr` |
| Conseiller numérique | `t.vignal@job-et-bonheur.fr` |
| Salariée | `a.berthier@vallonis.fr` |
| Partenaire | `contact@poneydream78.fr` |

Le mot de passe n'est pas vérifié : seule l'adresse identifie le compte.
Codes employeurs pour l'inscription salarié : `VALLONIS-2026`, `ARDENNE-2026`.

## Organisation du code

```
lib/      domaine, sans React
  qr.js       encodeur QR (ISO/IEC 18004, mode octet, niveau M, versions 1-4)
  data.js     schéma, jeu de démonstration à graine fixe, durée de validité du jeton
  api.js      magasin observable + API REST simulée (routes, codes HTTP, journal)
  format.js   formats français, empreintes
  icons.jsx   jeu d'icônes
  app.jsx     liaison React : session, navigation, notifications, aperçu appareil
components/  coquille, barre de pilotage, console, briques d'interface
screens/     Landing · Auth · Employee · Partner · Admin
app/         routes Next (enveloppes de quelques lignes autour des écrans)
preview/     point d'entrée du build monofichier
```

**Aucun écran n'écrit dans les données** : tout passe par `API.call`, qui parle
en chemins REST et en codes HTTP. Brancher un vrai backend revient à remplacer
le corps de cette fonction par un `fetch`.

**L'adaptation aux écrans passe par des requêtes de conteneur** (`@container`) :
la mise en page réagit à la largeur du châssis, donc l'aperçu smartphone montre
la vraie version adaptative, pas une réduction d'échelle.

**Les montants sont des entiers, en centimes.** Aucun flottant n'entre dans une
somme d'argent.

## Ce qui reste à faire pour la version réelle

- Backend et base relationnelle : le schéma de `lib/data.js` se transpose en tables.
- Authentification réelle : mots de passe, sessions serveur, HTTPS/HSTS.
- L'empreinte de chaînage est un FNV-1a 32 bits : elle démontre le principe sans
  le garantir. En production, SHA-256 et journal append-only.
- Le pouvoir d'annulation n'est aujourd'hui contrôlé que par le rôle
  « administration ». En production il faudrait le réserver à des agents
  habilités, et le journaliser hors de la portée de ceux qui l'exercent.
- Les partenaires « n'ont pas de système d'information compatible » : la reprise
  se fera donc par l'interface web, pas par intégration. Un mode caisse simplifié
  (tablette, scan, montant, valider) est le prolongement naturel.

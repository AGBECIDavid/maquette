# Epitech Academic Tracker

Suivi personnel du cursus Epitech : Roadblocks, modules, projets, crédits,
dates et progression.

```
ANNÉE → ROADBLOCK → MODULE → PROJET → CRÉDITS → VALIDATION
```

## Démarrer

```bash
cd epitech-tracker
npm install
npm run dev        # http://localhost:5173
```

```bash
npm test           # tests du domaine (calculs, validation, dates)
npm run typecheck  # TypeScript strict
npm run build      # vérification complète + bundle de production
```

À lancer avant chaque `git push` : `npm test && npm run build`.

## Trois choses à savoir avant de toucher au code

**Trois couches, une direction : données → logique → interface.**

```
   données                  logique                    interface
   ───────                  ───────                    ─────────

   localStorage  ─┐
   import JSON   ─┼──►  domain/  ──────────────►   ui/ (React)
   jeu d'exemple ─┘     règles, calculs,           pages, composants
                        agrégations, alertes
```

`src/domain/` est du TypeScript pur : ni React, ni accès au stockage, ni
lecture de l'horloge. La date du jour est **toujours un paramètre**, ce qui
rend les tests reproductibles et permettra plus tard de simuler une date.

**`src/domain/rules.ts` est le seul fichier qui décide.** Ce qui rapporte des
crédits, ce qui vaut validation, ce qui est en retard : tout est là. Si une
règle Epitech diffère de ce qui est implémenté, c'est ce fichier — et lui seul
— qu'il faut modifier. Les calculs ne sont dupliqués nulle part ailleurs.

**Une donnée absente s'affiche « — », jamais une valeur inventée.** Un champ
vide vaut `null`, et `null` n'est pas `0` : « aucun crédit obtenu » et
« crédits inconnus » ne se ressemblent pas à l'écran.

## Où se trouve quoi

```
src/
  domain/            TypeScript pur, testé — aucune dépendance à React
    types.ts         le modèle de données
    rules.ts         ← LES RÈGLES ACADÉMIQUES, le point de modification
    selectors.ts     agrégations : arbre calculé, compteurs du dashboard
    alerts.ts        alertes déduites de l'état
    priorities.ts    « à faire en priorité »
    calendar.ts      événements datés et grille mensuelle
    ordering.ts      rangs d'une fratrie : déplacer, renuméroter
    promotion.ts     passage TEK1 → TEK2, redoublement — jamais automatique
    stats.ts         séries prêtes à dessiner pour les graphiques
    projection.ts    « à ce rythme, validé le … » — extrapolation, pas prédiction
    search.ts        recherche globale et filtres
    dates.ts         arithmétique sur dates civiles ISO
  data/
    profiles.ts      profils locaux — PAS une authentification
    diagnostics.ts   rapport pour les retours de bêta
    schema.ts        schéma versionné, lecture/validation d'un document
    repository.ts    contrat de persistance
    localStorageRepository.ts
    mock.ts          ← JEU D'EXEMPLE, aucune valeur officielle
  store/
    SessionContext   quel profil est actif, et donc quel tiroir on ouvre
    CurriculumContext état des données du profil actif
  ui/                pages, composants, formulaires, libellés
    components/charts/ graphiques dessinés à la main, sans librairie
```

## Règles de calcul appliquées

Confirmées avec l'utilisateur :

1. Un module rapporte ses crédits **proportionnellement à ses projets
   validés** (6 crédits, 2 projets validés sur 3 → 4 crédits).
2. Le poids d'un projet est une **part égale** des crédits du module, sauf
   poids forcé sur le projet.
3. **Seul le statut « Validé » rapporte des crédits.** « Terminé » signifie
   rendu, en attente de correction : il ne rapporte rien.
4. Un **Roadblock est validé au seuil de crédits**, quels que soient les
   modules qui les ont apportés.
5. **Progression globale = crédits obtenus / crédits totaux requis.**

Deux cas-limites tranchés par les tests :

- Un module dont **tous** les projets sont validés rapporte **exactement** ses
  crédits : sans cela, un module de 7 crédits partagé en trois n'en
  rapporterait que 6,99. L'arrondi ne doit jamais coûter un crédit.
- Un module **sans aucune date** n'est pas « en cours » : deux bornes
  inconnues ne font pas une période, et une donnée absente ne doit pas se
  transformer en déduction.

## Hypothèses à confirmer

Ces règles ne viennent d'aucun document Epitech et sont marquées dans
`rules.ts` :

- **H1** — Un module est « validé » quand tous ses projets le sont ; « en
  cours » dès qu'un projet a bougé ou que sa période est ouverte. L'échec ne
  se déduit pas : il se force à la main.
- **H2** — Un Roadblock dont la date de fin est passée sans que le seuil soit
  atteint passe « non validé ». Si Epitech autorise un rattrapage au-delà de
  cette date, c'est cette règle qu'il faut retirer.

Tout statut déduit reste **surchargeable à la main** (`statusOverride`), pour
que l'outil ne se trompe jamais plus longtemps que son utilisateur.

## Données d'exemple

Au premier lancement, l'application charge un jeu de données mocké et affiche
un bandeau **« Données d'exemple »**. Les noms de modules sont plausibles, mais
**les crédits, les seuils et les dates sont inventés**.

Pour les remplacer : *Paramètres* → « Repartir de zéro », ou importer un JSON
exporté depuis cette même application. `settings.source` passe alors à `user`
et le bandeau disparaît.

## Ordre et années

Le rang d'un élément est porté par son champ `order`, jamais déduit de sa
position dans le tableau. Un déplacement renumérote toute la fratrie de 1 à N,
ce qui répare au passage les rangs dupliqués ou troués qu'un import ou une
suppression peut laisser.

Un module ne se réordonne que parmi les modules de son Roadblock, un projet
parmi ceux de son module. Le réordonnancement est désactivé tant qu'un filtre
est actif : déplacer d'un cran dans une liste filtrée sauterait par-dessus les
éléments masqués, ce qui donnerait un résultat différent de celui qu'on voit.

Les années se gèrent dans *Paramètres*. Supprimer une année emporte tout ce
qu'elle contient, et la confirmation annonce le décompte avant d'agir.

## Niveaux TEK et passage d'année

**Le niveau est porté par l'année, jamais par le profil.** La raison est le
redoublement : un étudiant qui refait TEK1 a deux années au même niveau, et
c'est exactement ce que le modèle doit pouvoir dire.

```
AcademicYear  2026-2027  · TEK1  ✅ validée
AcademicYear  2027-2028  · TEK1  ❌ non validée   ← redoublement
AcademicYear  2028-2029  · TEK2  🔄 année courante
```

Si le niveau était sur le profil, l'historique deviendrait faux le jour du
passage : les Roadblocks faits en TEK1 s'afficheraient comme du TEK2. Le
niveau demandé à l'inscription sert donc à **ouvrir la première année**, et
n'est pas stocké sur le profil — une seule source de vérité, pas deux qui
divergeront.

**Le passage n'est jamais automatique.** Un étudiant peut redoubler, partir en
césure, faire un stage long ou s'arrêter. Déduire « on est en septembre, donc
tu es en TEK2 » ferait prendre à l'application une décision qui ne lui
appartient pas — et la première fois qu'elle se trompe, l'étudiant cesse de
croire tous les autres chiffres. Quand la date de fin de l'année courante est
passée, le dashboard **propose** : passer au niveau suivant, redoubler, ou ne
rien faire.

Passer au niveau suivant ouvre une **année vierge** et la rend courante.
L'année quittée n'est ni modifiée ni supprimée.

## L'année courante et le cumul

`settings.currentYearId` désigne explicitement l'année affichée — déduite
d'une date, elle se tromperait sur une année qui déborde ou une césure.

Tout ce qui répond à « où j'en suis » est restreint à cette année
(`scopeToYear`) : dashboard, listes, calendrier, statistiques, alertes,
projection. Cumuler trois années dans un seul pourcentage empêcherait de voir
qu'on est en retard *maintenant*.

Deux exceptions délibérées, sur la vue complète :

- **la recherche**, pour retrouver un module de TEK1 depuis TEK2 ;
- **les pages de détail**, pour qu'un lien vers un ancien projet ne réponde
  pas « introuvable » ;
- **le Parcours** (page Statistiques), seul endroit où le cumul du cursus a
  du sens.

## Profils — ce que ce n'est pas

L'écran d'accueil demande un nom et propose de « créer un profil ». **Ce n'est
pas une authentification.** Il n'y a ni mot de passe, ni serveur, ni
vérification : un profil est un tiroir dans le `localStorage`, pour que deux
personnes sur la même machine ne mélangent pas leurs cursus.

L'application le dit à l'utilisateur, en toutes lettres, sur l'écran d'accueil.
Un mot de passe stocké dans un navigateur ne protège rien, et laisser croire
l'inverse à un bêta-testeur serait pire que de ne rien offrir.

Chaque profil a sa propre clé de stockage (`dataKeyFor`), et le fournisseur de
données est monté avec `key={profileId}` : changer de profil remonte tout
l'arbre plutôt que de laisser un état résiduel afficher, le temps d'un rendu,
le cursus de quelqu'un d'autre.

La vraie authentification viendra avec la mise en production. Elle remplacera
`SessionContext` et `ProfileStore` sans toucher aux écrans — c'est le même
découpage que `Repository`.

## Écran d'ouverture

L'animation de la marque suit trois règles, parce qu'une animation qu'on ne
peut pas éviter devient vite une corvée :

1. Elle se passe au clic, à la touche, ou par le bouton « Passer ».
2. Elle ne se joue qu'une fois par session, pas à chaque navigation.
3. `prefers-reduced-motion` la réduit à un affichage bref et fixe — le
   mouvement n'est pas une décoration négociable pour qui y est sensible.

Les pièces du logo entrent dans l'ordre où on les dessinerait à la main. Les
keyframes sont dans `index.css`, avec `transform-box: fill-box` : sans lui, un
`transform` sur un élément SVG prend pour origine le coin du canevas et non
celui de la forme.

## Mettre en ligne

Le build est un site statique à chemins relatifs (`base: './'`), et la
navigation passe par le *hash* : **aucune règle de réécriture d'URL n'est
nécessaire côté serveur**. N'importe quel hébergement statique convient, y
compris un sous-dossier.

### GitHub Pages (mis en place)

`.github/workflows/deploy-tracker.yml` construit et publie à chaque poussée
touchant `epitech-tracker/`. **Le déploiement est conditionné aux tests et à la
vérification des types** : un test rouge arrête la livraison plutôt que de
mettre en ligne un build cassé.

Une seule action manuelle, à faire une fois :

> Dépôt GitHub → **Settings** → **Pages** → *Build and deployment* →
> **Source : GitHub Actions**

L'adresse est ensuite `https://agbecidavid.github.io/maquette/`.

### Vercel — l'hébergement de la bêta

**https://epitech-tracker.vercel.app** — déployé depuis `main`, redéployé à
chaque poussée. Les autres branches reçoivent une URL de prévisualisation, ce
qui permet de faire essayer un correctif à une personne avant de l'envoyer à
tout le monde.

Configuration : `Root Directory` réglé sur `epitech-tracker`, tout le reste
vient de `vercel.json`. Aucune règle de réécriture n'est nécessaire — la
navigation passe par le *hash*, donc toutes les routes sont servies par
`index.html`.

**Vercel n'exécute pas la suite de tests** : son `buildCommand` est
`npm run build`, qui inclut `tsc --noEmit`. Une erreur de type bloque donc la
mise en ligne, mais un test rouge passerait. Pour la même barrière qu'en CI :
`"buildCommand": "npm test && npm run build"`.

### Ailleurs

`npm run build` produit `dist/`. Ce dossier se dépose tel quel sur Netlify,
Cloudflare Pages ou un simple serveur de fichiers.

### Si la mise en ligne échoue

`Failed to create deployment (status: 404)` sur le job `deploy` veut dire que
Pages n'est pas activé sur le dépôt — le build, lui, a réussi. Réglage :
*Settings → Pages → Source : GitHub Actions*, puis **Re-run failed jobs** sur
le run en échec. Inutile de repousser : l'artefact est déjà construit.

## Bêta

La version s'affiche dans *Paramètres* (`src/version.ts`, à garder en phase
avec `package.json`). Un bug rapporté sans version se cherche dans le mauvais
code.

*Exporter un diagnostic* produit un fichier contenant la version, le
navigateur, les compteurs, les incohérences détectées **et l'intégralité du
cursus**, notes personnelles comprises. L'interface l'annonce avant de générer
le fichier : c'est au testeur de décider ce qui sort de sa machine.

## Persistance

Les données vivent dans le `localStorage` du navigateur, derrière l'interface
`Repository`. Export et import JSON dans *Paramètres* — c'est aujourd'hui le
seul moyen de sauvegarder ou de changer de machine.

Chaque document porte un `schemaVersion`. Un document venu d'une version plus
récente, ou amputé, est **refusé** avec un message : il n'écrase jamais les
données en place.

## Graphiques

Aucune librairie de graphiques : trois visuels dessinés à la main en CSS et en
SVG, pour la même raison que `agoojiye-hmi` dessine ses jauges en Canvas —
une dépendance de moins à suivre, et un contrôle total du rendu.

Les règles appliquées :

- **Une seule teinte par série.** Les barres « crédits par Roadblock » sont
  toutes de la même couleur : la longueur porte déjà la grandeur, colorer
  chaque barre brûlerait le seul canal libre pour une information déjà lisible.
- **Les couleurs de statut sont celles des badges.** Un projet vert dans une
  liste est vert dans le graphique. Elles ne sont jamais seules : chaque
  segment porte son libellé, son icône et son compte.
- **Palette vérifiée, pas estimée.** Séparation daltonienne ΔE 22,4 (deutan) et
  13,2 (tritan), contraste ≥ 3:1 sur le fond sombre.
- **Un seul axe, jamais deux échelles.** La piste derrière chaque barre est le
  seuil requis : acquis et restant se lisent sans second axe.
- **Ce que la courbe ne montre pas, elle le dit.** Un projet validé sans date
  de fin ne peut pas être placé dans le temps : il est exclu de la courbe et
  son total est annoncé sous le titre, plutôt que d'inventer une date.

Le cumul de la courbe suit exactement la règle des crédits : dès qu'un module
est entièrement validé, il vaut ses crédits exacts. Sans cela, des parts égales
non entières feraient dériver la courbe du compteur du dashboard (74,01 au lieu
de 74) — un écart qu'on ne remarque qu'en regardant les deux pages côte à côte.

## Projection

`projection.ts` répond à « à ce rythme, quand ce Roadblock sera-t-il validé ? ».
C'est une **extrapolation du passé**, et l'interface le dit avant de donner la
moindre date.

Le rythme est mesuré sur les 90 derniers jours. Sans activité récente, on
retombe sur le rythme depuis la première validation — moins actuel, mais mesuré
plutôt qu'inventé. Le rythme retenu est toujours annoncé : deux rythmes donnent
deux dates, et on doit savoir laquelle on regarde.

Trois refus délibérés, parce qu'une fausse date est pire que pas de date :

- **Aucun crédit validé et daté** → pas de rythme, donc pas de date.
- **Seuil hors de portée** (les crédits restants du Roadblock ne couvrent pas
  ce qui manque) → on le dit, on ne date pas l'impossible.
- **Un seuil hors de portée n'entre pas dans le cumul** des Roadblocks
  suivants : il ne sera jamais franchi, l'y ajouter repousserait indéfiniment
  tout le reste.

Les Roadblocks sont **séquentiels et partagent un seul rythme** : les crédits
restants se cumulent dans l'ordre du cursus. Sans ce cumul, un Roadblock entier
de 24 crédits apparaissait sept jours après le précédent — chacun étant daté
comme si tout le temps disponible lui était consacré — et la dernière date
contredisait celle du cursus.

## Identité

La marque est redessinée en SVG dans `src/ui/components/Logo.tsx` : nette à
toutes les tailles, quelques centaines d'octets, lisible sur fond sombre comme
sur fond clair. Un PNG sur fond blanc ferait une tache sur l'interface.

Le tracé a été vérifié à 96, 48, 24 et 16 px avant d'être retenu : un logo qui
ne survit pas à la taille d'un favicon n'est pas un logo d'application.

## Ce qui n'est pas encore fait

- Historique de progression dans le temps (instantanés successifs)
- Import depuis l'intranet Epitech
- Retours des bêta-testeurs

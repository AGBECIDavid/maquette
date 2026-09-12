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
    stats.ts         séries prêtes à dessiner pour les graphiques
    search.ts        recherche globale et filtres
    dates.ts         arithmétique sur dates civiles ISO
  data/
    schema.ts        schéma versionné, lecture/validation d'un document
    repository.ts    contrat de persistance
    localStorageRepository.ts
    mock.ts          ← JEU D'EXEMPLE, aucune valeur officielle
  store/             état React, dérivations, import/export
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

## Ce qui n'est pas encore fait

- Historique de progression dans le temps (instantanés successifs)
- Projection : « à ce rythme, Roadblock 4 validé le … »
- Import depuis l'intranet Epitech

# Déclaration d'accessibilité

**Projet de déclaration** — Ministère du Job et Bonheur, Direction du Numérique et de
l'Innovation. Établie le 1ᵉʳ septembre 2026 pour l'application CartePro
(JEB/DNI/2026-002 v2.0).

## État de conformité

**Non conforme à ce stade** : l'audit RGAA 4.1 n'a pas encore été réalisé.

Cette formulation est volontaire. Le RGAA impose un audit sur un échantillon de pages
avant toute annonce de conformité, et annoncer « partiellement conforme » sans avoir
mesuré serait une déclaration fausse. Ce qui suit décrit ce qui a été **vérifié** et ce
qui reste à **auditer**.

## Ce qui a été mis en place et vérifié

| Critère | Ce qui est fait |
|---|---|
| Structure | Un seul `h1` par écran, titres hiérarchisés, listes et tableaux sémantiques (`th`, `thead`) |
| Langue | `lang="fr"` sur le document |
| Titre de page | Unique et explicite par écran, et portant la mention de simulation (§4.1) |
| Navigation au clavier | Tous les contrôles sont des `button`, `a`, `input` natifs ; aucun `div` cliquable |
| Focus visible | `:focus-visible` avec un contour de 2 px et un décalage de 2 px, jamais supprimé |
| Fermeture au clavier | Les fenêtres modales se ferment par `Échap` |
| Contrastes | Mesurés, pas estimés : texte courant `#12172b` sur `#ffffff` **17,8:1** ; texte secondaire `#6b7291` **4,7:1** ; texte atténué `#636980` **5,4:1** sur blanc et **4,7:1** sur le gris le plus foncé de l'interface ; bleu institutionnel `#1B3A6B` sur le lavis des boutons **10,0:1** ; mention de simulation `#7a5502` sur `#fdf7ea` **6,3:1**. Un défaut a été corrigé à cette occasion : le texte atténué était à 2,7:1 |
| Couleur seule | Les statuts associent toujours une pastille **et** un libellé écrit ; la mention de simulation est un texte, pas une teinte |
| Images | Les graphiques portent `role="img"` et un `aria-label` ; les décorations sont `aria-hidden` |
| Mouvement | `prefers-reduced-motion` neutralise animations et défilement automatique |
| Zoom et adaptation | Mise en page en requêtes de conteneur, texte en unités relatives, pas de blocage du zoom |
| Champs de formulaire | Chaque champ a un `label` associé, et une aide de saisie quand la contrainte n'est pas devinable (SIREN, objet social) |

## Ce qui reste à auditer

- Restitution réelle par lecteur d'écran (NVDA + Firefox, VoiceOver + Safari) : non
  testée. C'est le manque le plus important.
- Ordre de tabulation sur les écrans denses (registre, tableau de bord national).
- Alternatives aux graphiques : le tableau de données existe sur le volume
  hebdomadaire, il manque sur les répartitions géographique et par catégorie.
- Contraste des composants d'interface non textuels (bordures de champs, pastilles).
- Comportement à 200 % de zoom sur les tableaux larges.
- Messages d'erreur : ils sont affichés visuellement mais ne sont pas tous rattachés au
  champ concerné par `aria-describedby`.

## Contenus non accessibles

Le plan des partenaires est une figure schématique sans équivalent textuel complet.
La liste paginée qui l'accompagne donne la même information sous forme de texte : c'est
l'alternative retenue, à confirmer lors de l'audit.

## Établissement de cette déclaration

Déclaration établie à partir d'une vérification interne, sans audit externe. Elle devra
être reprise après l'audit RGAA 4.1 sur l'échantillon défini par la Direction.

## Voies de recours

Signalement d'un défaut d'accessibilité : Direction du Numérique et de l'Innovation,
t.vignal@job-et-bonheur.fr. À défaut de réponse satisfaisante sous deux mois : saisine
du Défenseur des droits.

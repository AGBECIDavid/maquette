# outils/refonte-front.sh

Reconstruit l'arborescence du front (dépôt `…-survivor-21`, dossier `front/`)
selon une règle unique : **une interface = un dossier, et dedans ses fichiers.**

## Ce qu'il efface, ce qu'il garde

| Effacé | Gardé |
|---|---|
| `src/app/` (les coquilles de routes) | `src/types/` — le domaine typé |
| `src/components/` (ébauches) | `src/lib/` — services et client |
| | `src/styles/` — la charte |
| | `src/mocks/` — les fixtures |
| | `src/app/favicon.ico` (remis en place) |

Avant d'effacer quoi que ce soit il exige trois choses, et refuse sinon :
être lancé depuis `front/`, un arbre propre, une branche poussée. Puis il crée
une branche `sauvegarde-avant-refonte-<date>` : rien n'est perdu.

## Convention encodée

- Le dossier porte l'écran ; `page.tsx` n'est qu'une enveloppe de trois lignes.
- Un dossier **sans** `page.tsx` n'est pas une route : `tableau-de-bord/` porte
  le tableau de bord, rendu par le `page.tsx` du parent.
- Les fichiers sont des composants nommés (`export function X() { return null }`),
  jamais des fichiers vides : sous `isolatedModules` un fichier vide n'est pas
  un module et casse `next build`.

## Vérifié

Rejoué sur deux répliques (dépôt git avec `origin`, fichiers de valeur, coquilles) :
garde-fous refusant les trois cas, substance intacte au SHA-1 près, coquilles
effacées, 31 routes et 147 composants générés, `next build` et `tsc --noEmit`
verts sur les deux.

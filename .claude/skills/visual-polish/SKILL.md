---
name: visual-polish
description: Passe de finition visuelle — hiérarchie, profondeur, lumière, élévation, dégradés, rythme d'espacement, typographie chiffrée. À charger dès qu'un écran ou un composant doit « faire pro » et pas seulement fonctionner : polish visuel, revue de rendu, réglage d'ombres, de contrastes ou d'espacements, aussi bien dans les maquettes HTML (project/*.dc.html) que dans l'IHM Qt/QML (agoojiye-hmi/qml). Triggers: rendu pro, polish visuel, ça fait amateur, premium look, design pass, elevation, depth, spacing, hierarchy, contrast.
---

# Rendu visuel pro

Un écran passe d'« amateur » à « pro » par une poignée de décisions
mesurables, pas par du goût. Les six ci-dessous, dans l'ordre : chacune
répare un défaut qui saute aux yeux avant la suivante.

## 1. Une seule source de lumière

Sur fond sombre, choisis une direction (ici : lumière du haut) et tiens-la
partout.

- Bord haut d'une surface surélevée = **liseré clair** (1 px, alpha 0.10-0.18).
- Bord bas = rien, ou une ombre portée très diffuse.
- Un creux (champ de saisie, piste de slider) inverse : sombre en haut.

Sur fond sombre, **un liseré lit mieux qu'une ombre portée** : l'ombre noire
sur du presque-noir n'existe pas. C'est exactement ce que fait
`agoojiye-hmi/qml/components/PanelCard.qml` avec son highlight horizontal
dégradé au bord supérieur — reprends ce composant plutôt que de réinventer
une carte.

## 2. Profondeur = 4 niveaux, pas plus

| Niveau | Rôle | HTML | QML |
|---|---|---|---|
| 0 | fond d'écran | `#01030a` + vignette | `Theme.bg` + `Vignette` |
| 1 | zone / piste | `rgba(13,26,46,.6)` | `Theme.trackBg` |
| 2 | carte | dégradé `.85 → .90` + bord 1 px | `PanelCard` |
| 3 | flottant (modale, popover, tooltip) | idem + halo | `PanelCard { elevated: true }` + `Glow` |

Deux cartes de même niveau posées l'une sur l'autre = confusion. Si tu as
besoin d'un 5ᵉ niveau, c'est la mise en page qu'il faut revoir.

## 3. Le rythme d'espacement

Échelle 4 px : `4, 8, 12, 16, 20, 24, 32, 40, 56, 72`. Rien entre.

Règle de proximité : **l'espace intérieur d'un groupe est toujours plus
petit que l'espace qui le sépare du groupe voisin.** Un label collé à sa
valeur (4-6 px) et 24 px avant la stat suivante — c'est ce qui fait qu'un
tableau de bord se lit d'un coup d'œil à 60 cm en conduisant.

## 4. Typographie

- **Trois tailles par écran** au maximum, plus une pour les chiffres géants.
- Échelle utilisée ici : `11 / 12 / 14 / 19 / 22 / 40`, graisses `400 / 500 / 700`.
- Toute valeur qui change en temps réel (vitesse, autonomie, heure, %) porte
  `font-variant-numeric: tabular-nums` en CSS, `font.features` ou une police
  à chasse fixe en QML. Sans ça les chiffres dansent à chaque rafraîchissement
  — le défaut le plus visible d'un cockpit.
- Les micro-labels en capitales prennent `letter-spacing: .08em`-`.1em`.
  Le corps de texte n'en prend jamais.

## 5. Couleur

- Le fond n'est jamais du noir pur : `#01030a` a une teinte, il accroche
  les reflets.
- **Une seule couleur d'accent par écran** (`Theme.blue`). Le vert, l'orange
  et le rouge sont réservés à l'état (OK / alerte / danger) — jamais
  décoratifs, sinon une vraie alerte ne se distingue plus.
- Les gris de texte descendent par paliers : `textPrimary` → `textSecondary`
  → `textMuted`. Trois niveaux, pas un dégradé continu d'opacités arbitraires.
- Contraste : ≥ 4.5:1 pour le texte courant, ≥ 3:1 pour les grands chiffres
  et les icônes porteuses de sens. Sur un écran embarqué en plein soleil,
  vise plus haut.

## 6. Ce qui fait « cher »

Dans l'ordre du rapport effet/effort :

1. **Vignette** — assombrissement des coins, garde l'œil au centre et masque
   les raccords d'images pleine largeur (`Vignette.qml`).
2. **Halo radial** derrière les éléments lumineux (`Glow.qml`), jamais plus
   de deux par écran.
3. **Bords à 1 px non uniformes** : un bord dont l'alpha varie du haut vers
   le bas imite une arête éclairée.
4. **Grain** très léger (2-4 % d'opacité) sur les grands aplats sombres :
   casse le banding des dégradés. En CSS, un SVG `feTurbulence` en
   `background-image` ; en QML, une texture PNG tuilée en `opacity: 0.03`.
5. **Transitions courtes** : 120-180 ms pour un état (hover, appui),
   220-320 ms pour une entrée d'élément, courbe `cubic-bezier(.2,.8,.2,1)`.
   Au-delà de 400 ms, l'interface paraît lente, pas fluide.

## Contrainte de cette cible

`agoojiye-hmi` tourne **sans GPU**, en rendu logiciel. Donc :

- pas de flou en temps réel, pas de shader ;
- les dégradés et les halos se peignent **une fois** dans un `Canvas`, et on
  anime l'`opacity` de l'élément, jamais le repaint (voir le commentaire de
  `Glow.qml` : repeindre un canvas 900 × 420 à chaque image coûtait 150
  redessins CPU sur l'écran de démarrage) ;
- une ombre portée coûte cher : préfère le liseré du point 1.

## Vérifier, ne pas supposer

```bash
cd agoojiye-hmi && ./test.sh --keep /tmp/captures   # capture les 38 panneaux
```

Puis regarde les PNG. Un défaut d'espacement ou de contraste se voit sur la
capture, jamais dans le diff.

## Checklist de relecture

- [ ] Un seul accent, les couleurs d'état réservées à l'état
- [ ] Espacements sur l'échelle 4 px, proximité respectée
- [ ] ≤ 3 tailles de texte, chiffres tabulaires sur tout ce qui bouge
- [ ] Élévation cohérente : lumière du haut, ≤ 4 niveaux
- [ ] Alignements : les bords gauches des blocs voisins coïncident au pixel
- [ ] Rien ne clignote ni ne se recalcule à chaque image
- [ ] Contraste vérifié sur le texte le plus clair du fond le plus clair

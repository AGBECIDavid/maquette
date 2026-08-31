---
name: glass-ui
description: Effet verre / glassmorphism — surfaces translucides floutées, liserés spéculaires, verre teinté, et l'équivalent sans GPU pour Qt/QML en rendu logiciel. À charger quand on demande un rendu verre, glass, givré, frosted, translucide, blur d'arrière-plan, panneau flottant qui laisse voir le fond, effet vision-pro / iOS. Couvre CSS backdrop-filter, les fallbacks, et le faux verre peint en dégradés pour agoojiye-hmi.
---

# Verre : la recette complète

Le flou seul ne fait pas du verre. Il faut **cinq couches**, dans cet ordre.
Enlève-en une et l'effet retombe en « rectangle semi-transparent ».

| # | Couche | Rôle |
|---|---|---|
| 1 | teinte de fond | donne une couleur au verre, sinon il prend celle du fond |
| 2 | flou + saturation | sépare du contenu derrière, la saturation compense le lavage du flou |
| 3 | liseré 1 px | l'arête du panneau ; c'est elle qui donne l'épaisseur |
| 4 | reflet interne haut | la lumière qui glisse sur la face supérieure |
| 5 | ombre portée diffuse | détache du fond, très large et très douce |

## CSS — verre sombre (palette de ce projet)

```css
.glass {
  background: linear-gradient(180deg,
    rgba(16, 24, 40, .72),
    rgba(9, 14, 24, .82));
  backdrop-filter: blur(18px) saturate(140%);
  -webkit-backdrop-filter: blur(18px) saturate(140%);
  border: 1px solid rgba(96, 140, 220, .18);
  border-radius: 18px;
  box-shadow:
    inset 0 1px 0 rgba(147, 197, 253, .16),   /* reflet haut */
    inset 0 -1px 0 rgba(0, 0, 0, .25),        /* arête basse */
    0 24px 48px -12px rgba(0, 0, 0, .55);     /* ombre diffuse */
}
```

Réglages qui comptent :

- **Flou 14-24 px.** En dessous, le fond reste lisible et l'œil lit un calque
  sale ; au-dessus, ça devient un aplat et on perd l'intérêt du verre.
- **Opacité de la teinte 0.65-0.85 sur fond sombre.** Plus bas, le texte
  posé dessus ne tient plus le contraste.
- **`saturate(140%)`** n'est pas cosmétique : le flou désature, la saturation
  rend au verre les couleurs du fond, et c'est ce qui le fait paraître épais.
- Le **reflet haut** (`inset 0 1px 0`) est la couche que tout le monde oublie.
  C'est elle qui fait « verre » plutôt que « calque ».

### Verre clair sur fond clair

```css
background: rgba(255, 255, 255, .55);
border: 1px solid rgba(255, 255, 255, .7);
box-shadow: inset 0 1px 0 rgba(255,255,255,.9), 0 12px 32px -8px rgba(15,23,42,.18);
```

### Fallback obligatoire

`backdrop-filter` n'existe pas partout, et il est désactivé sous certains
réglages d'accessibilité. Sans fallback, ton panneau devient illisible :

```css
@supports not (backdrop-filter: blur(1px)) {
  .glass { background: rgba(9, 14, 24, .94); }   /* opaque, pas translucide */
}
```

### Coût

`backdrop-filter` force la composition de tout ce qui est derrière, à chaque
image. Trois règles :

- pas plus de **2-3 surfaces en verre visibles simultanément** ;
- jamais de verre sur un élément qui bouge à chaque frame (le flou se
  recalcule) — anime plutôt son `opacity` ou son `transform` avec
  `will-change: transform` ;
- jamais de verre sur une liste scrollable longue : mets-le sur le conteneur
  fixe, pas sur les lignes.

## QML sans GPU — le faux verre

`agoojiye-hmi` tourne en **rendu logiciel** : pas de shader, donc ni
`MultiEffect`, ni `FastBlur`, ni `ShaderEffect`. Le vrai flou d'arrière-plan
est hors de portée, et c'est très bien : sur un fond de nuit, un verre
correctement teinté est visuellement indiscernable d'un verre flouté.

C'est déjà ce que fait `qml/components/PanelCard.qml` — utilise-le :

```qml
PanelCard {
    radius: 18
    elevated: true          // ajoute le reflet 1 px en haut
    // dégradé Theme.panelGradTop → panelGradBottom + bord 1 px : couches 1, 3, 4
}
```

Pour aller plus loin quand le panneau flotte au-dessus d'une image ou d'une
carte de navigation :

```qml
Item {
    // Couche 2 de substitution : au lieu de flouter le fond, on l'assombrit
    // localement. L'œil lit la même séparation.
    Rectangle {
        anchors.fill: card
        anchors.margins: -1
        radius: card.radius + 1
        color: Theme.alpha(Theme.bg, 0.55)
    }
    Glow {                       // halo doux, peint une fois au Canvas
        anchors.centerIn: card
        width: card.width * 1.4; height: card.height * 1.6
        glowColor: Theme.blue
        intensity: 0.12
    }
    PanelCard { id: card; elevated: true }
}
```

Si un vrai flou est indispensable (fond photographique complexe), la seule
voie sans GPU est de **pré-flouter l'image à la génération**, pas au runtime :
produis une variante floutée du PNG dans `assets/images/` et affiche-la sous
le panneau.

## Pièges

- **Texte sur verre** : ajoute toujours une teinte assez opaque *derrière le
  texte*, ou vérifie le contraste sur le fond le plus clair possible. Un
  panneau verre au-dessus d'une carte de jour passe de 8:1 à 2:1 sans
  prévenir.
- **Verre sur verre** : deux couches translucides empilées virent au gris
  laiteux. Une seule couche, posée sur un fond opaque.
- **Bords arrondis + flou** : le flou déborde des coins si `overflow` n'est
  pas coupé — `border-radius` sur l'élément qui porte le `backdrop-filter`,
  pas sur un parent.
- **Icônes** : sur verre, une icône a besoin d'un poids de trait supérieur
  d'un cran à ce qu'elle porte sur fond plein.

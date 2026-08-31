---
name: scroll-motion
description: Défilement et animations pilotées par le scroll — défilement infini (marquee/ticker), boucle sans fin d'une liste, parallaxe, scrollytelling avec épinglage sticky, scroll-snap, défilement inertiel, apparition au scroll. À charger quand on demande « le truc qui défile à l'infini », un bandeau qui défile en boucle, du texte qui glisse, un carrousel sans fin, un effet qui se déclenche au scroll, une animation liée au défilement — en CSS/JS comme en QML (ListView, PathView, Flickable).
---

# Défilement : le vocabulaire, puis les recettes

Les effets qu'on regroupe sous « ça défile à l'infini » sont en fait cinq
choses différentes. Nommer la bonne évite d'implémenter la mauvaise.

| Nom FR | Nom EN | Ce que c'est |
|---|---|---|
| **Bandeau défilant** / marquee | marquee, ticker | un ruban de contenu qui glisse en boucle, tout seul, sans que l'utilisateur scrolle |
| **Défilement infini** | infinite scroll | une liste qui charge la suite quand on arrive en bas |
| **Boucle sans fin** | endless / circular list | une liste qui revient au début quand on dépasse la fin |
| **Parallaxe** | parallax | des couches qui bougent à des vitesses différentes pendant le scroll |
| **Scrollytelling** | scroll-driven animation, pinning | un élément épinglé pendant que le scroll fait avancer une animation |

Le « truc qui défile à l'infini » d'un cockpit ou d'un site vitrine, c'est
presque toujours **le bandeau défilant** (§1) ou **le scrollytelling** (§4).

---

## 1. Bandeau défilant infini (CSS pur)

Le principe : dupliquer le contenu **exactement une fois**, translater de
`-50%`, boucler. La duplication est ce qui rend la couture invisible.

```html
<div class="marquee"><div class="marquee__track">
  <span class="item">…</span><span class="item">…</span>
  <!-- copie à l'identique du même groupe -->
  <span class="item">…</span><span class="item">…</span>
</div></div>
```

```css
.marquee { overflow: hidden; -webkit-mask-image:
  linear-gradient(90deg, transparent, #000 8%, #000 92%, transparent); }
.marquee__track {
  display: flex; gap: 32px; width: max-content;
  animation: marquee 28s linear infinite;
}
@keyframes marquee { to { transform: translateX(-50%); } }
.marquee:hover .marquee__track { animation-play-state: paused; }
@media (prefers-reduced-motion: reduce) {
  .marquee__track { animation: none; }
}
```

- Le **masque en dégradé** sur les bords est ce qui fait pro : sans lui le
  texte apparaît et disparaît net contre le bord.
- Anime `transform`, **jamais** `left` ni `margin` : seul `transform` reste
  sur le compositeur et tient 60 fps.
- Vitesse : vise 40-80 px/s. Plus vite devient illisible.
- Si le contenu est plus étroit que le conteneur, il faut le dupliquer 3 ou
  4 fois, pas 2 — sinon on voit un trou.

## 2. Défilement infini (chargement à la demande)

`IntersectionObserver` sur une sentinelle en bas de liste, jamais un
écouteur `scroll` :

```js
const io = new IntersectionObserver(([e]) => {
  if (e.isIntersecting && !loading) loadNextPage();
}, { rootMargin: '600px' });      // charge avant que l'utilisateur arrive
io.observe(sentinel);
```

Prévois toujours : un état de chargement, une fin de liste explicite, et un
garde-fou anti-double-chargement. Au-delà de ~200 éléments dans le DOM,
passe à de la **virtualisation** (ne rendre que la fenêtre visible).

## 3. Parallaxe et apparition, en CSS natif

Les animations pilotées par le scroll n'ont plus besoin de JS :

```css
.layer-bg {
  animation: drift linear both;
  animation-timeline: view();          /* progression = traversée du viewport */
  animation-range: entry 0% exit 100%;
}
@keyframes drift { to { transform: translateY(-18%); } }

.reveal {
  animation: fade-up linear both;
  animation-timeline: view();
  animation-range: entry 10% cover 35%;
}
```

Support inégal (Chromium ok, Safari/Firefox en retard) : c'est une
**amélioration progressive**, l'écran doit rester correct sans. Encadre par
`@supports (animation-timeline: view())` si l'état par défaut ne convient pas.

Pour un support large, GSAP `ScrollTrigger` reste la référence ; associe-le
à Lenis pour le défilement inertiel. Deux bibliothèques = ~40 ko : ne les
ajoute que si l'effet est central.

## 4. Épinglage / scrollytelling

```css
.chapter { height: 300vh; }                 /* la course de scroll */
.chapter__visual { position: sticky; top: 0; height: 100vh; }
```

Le conteneur haut fournit la distance de scroll, l'élément `sticky` reste à
l'écran pendant ce temps. Toute l'animation se rattache ensuite à la
progression (`animation-timeline: scroll()` ou ScrollTrigger).

Piège classique : `position: sticky` ne fonctionne pas si un ancêtre porte
`overflow: hidden` ou `overflow: auto`. C'est la cause n°1 d'un sticky qui
« ne marche pas ».

## 5. Carrousel à aimantation

```css
.rail { display: flex; gap: 16px; overflow-x: auto;
        scroll-snap-type: x mandatory; scrollbar-width: none; }
.rail > * { scroll-snap-align: center; flex: 0 0 min(78%, 420px); }
```

Zéro JS, gestuel natif, fonctionne au clavier. Préfère toujours ça à un
carrousel scripté.

---

## Côté QML (agoojiye-hmi, rendu logiciel)

Pas de CSS ici — mais les cinq effets ont un équivalent, et tous doivent
respecter la contrainte du projet : **animer une propriété, jamais repeindre**.

**Bandeau défilant** — deux copies et une boucle sur `x` :

```qml
Item {
    id: marquee
    clip: true
    Row {
        id: track
        spacing: 32
        Repeater { model: 2; delegate: TickerContent {} }
        NumberAnimation on x {
            from: 0; to: -(track.width + track.spacing) / 2
            duration: 28000; loops: Animation.Infinite; running: marquee.visible
        }
    }
}
```

`running: marquee.visible` n'est pas un détail : une animation qui tourne sur
un écran caché consomme du CPU sur une cible embarquée.

**Boucle sans fin** — c'est intégré, ne l'écris pas à la main :

```qml
PathView { pathItemCount: 5; ... }              // circulaire par nature
ListView { snapMode: ListView.SnapOneItem;
           orientation: ListView.Horizontal;
           highlightRangeMode: ListView.StrictlyEnforceRange }   // = scroll-snap
```

**Parallaxe** — lie la position d'une couche au `contentY` du `Flickable` :

```qml
Image { y: -flick.contentY * 0.35 }   // 0.35 = couche lointaine
```

**Apparition au scroll** — un `Behavior` sur `opacity` déclenché par un test
de visibilité ; jamais un timer qui interroge la position à chaque frame.

## À vérifier avant de livrer

- [ ] `prefers-reduced-motion` respecté (web) — une boucle infinie est le
      premier déclencheur de gêne vestibulaire
- [ ] Le bandeau se met en pause au survol / au focus, et reste lisible
- [ ] Rien n'anime `width`, `height`, `top` ou `left` : uniquement
      `transform` et `opacity`
- [ ] En QML : aucune animation active sur un écran non visible
- [ ] Pas de `sticky` sous un ancêtre `overflow: hidden`
- [ ] Au clavier, on peut atteindre et lire tout ce qui défile

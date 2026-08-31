# Skills du projet

Skills chargées automatiquement par Claude Code quand on travaille dans ce
dépôt. Chacune est calée sur les contraintes réelles du projet : maquettes
HTML dans `project/`, IHM Qt/QML **sans GPU** dans `agoojiye-hmi/`, rendu 3D
headless dans `tools/render/`.

| Skill | Pour quoi | Se déclenche sur |
|---|---|---|
| `visual-polish` | rendu pro : hiérarchie, profondeur, lumière, espacements, typo | « ça fait amateur », polish, passe de finition, contraste, élévation |
| `glass-ui` | surfaces verre / glassmorphism, et le faux verre sans GPU en QML | verre, glass, frosted, translucide, flou d'arrière-plan |
| `render-3d` | images du véhicule depuis le GLB, three.js headless, éclairage | rendu 3D, nouvel angle, tournette, .glb, WebGL |
| `scroll-motion` | bandeau défilant, défilement infini, parallaxe, scrollytelling, snap | « le truc qui défile », marquee, animation au scroll, carrousel |

Une skill s'invoque aussi à la main : `/visual-polish`, `/glass-ui`,
`/render-3d`, `/scroll-motion`.

Pour en modifier une : édite son `SKILL.md`. Le bloc YAML en tête définit son
nom et surtout sa `description` — c'est elle qui décide du déclenchement, donc
elle doit contenir les mots que l'on emploie vraiment en parlant du besoin.

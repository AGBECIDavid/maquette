---
name: render-3d
description: Rendu 3D — produire des images du véhicule (ou de tout modèle GLB/glTF) avec three.js en headless, sans GPU, en PNG détouré transparent ; réglage caméra, éclairage, matériaux, tone mapping ; et intégration des rendus dans l'IHM QML. À charger pour toute demande de rendu 3D, vue du véhicule sous un autre angle, image produit, tournette/turntable, modèle .glb, éclairage de scène, three.js, WebGL.
---

# Rendu 3D

Le pipeline existe déjà dans `tools/render/`. **Ne pars pas de zéro** : il
sert un GLB à un Chromium headless en WebGL logiciel (SwiftShader, aucun GPU)
et écrit un PNG à fond transparent par angle demandé.

## Produire une image

```bash
cd tools/render
npm install three playwright
cp ../../project/vehicle/*.glb model.glb
node shoot.js out            # écrit out/<nom>.png
```

Les prises de vue se déclarent dans `tools/render/shots.json` :

```json
[{"name":"hero-wide","w":1320,"h":500,"az":248,"el":9,"dist":0.80,"fov":26}]
```

| champ | sens | valeurs utiles |
|---|---|---|
| `az` | azimut ° | 180 = profil, 225 = 3/4 avant, 270 = face, 315 = 3/4 arrière |
| `el` | élévation ° | 5-12 = niveau du regard (flatteur), 25+ = vue plongeante technique |
| `dist` | distance × rayon d'encombrement | 0.7-0.9 serré, 1.2+ avec de l'air autour |
| `fov` | ouverture ° | **24-30**. Au-delà de 40, la perspective déforme et le véhicule paraît jouet |

Ajoute un objet au tableau, relance `node shoot.js out`, regarde le PNG.

## Grammaire de l'éclairage (dans `tools/render/index.html`)

Le rig est un **rim-light** de nuit, pas un studio blanc. Sur le fond
`#01030a` de l'IHM, c'est le liseré froid qui détache la silhouette — il pèse
plus lourd que la lumière principale, d'où `rim` à 3.4 contre `key` à 1.5.

- `toneMappingExposure = 0.52` — volontairement sous-exposé : le véhicule doit
  rester dans la palette nuit. Si tu le montes, il devient un objet blanc
  collé sur un fond noir.
- `scene.environmentIntensity = 0.30` — une `RoomEnvironment` donne au métal
  brossé et au verre des reflets crédibles ; à pleine intensité elle inonde
  la carrosserie.
- `ACESFilmicToneMapping` + `SRGBColorSpace` : ne change pas ce couple, c'est
  ce qui évite les hautes lumières qui « brûlent » en blanc pur.

Pour ajuster : bouge **d'abord** l'intensité du rim, ensuite l'exposition,
en dernier la key. Dans l'autre ordre tu tournes en rond.

## Dépannage

| Symptôme | Cause | Correction |
|---|---|---|
| Modèle noir / invisible | pas d'environnement, matériaux PBR sans IBL | vérifier que `scene.environment` est bien assigné |
| Tout est blanc, cramé | exposition trop haute | `toneMappingExposure` vers 0.5 |
| Bords en escalier | `setPixelRatio(1)` | rendre à 2× la taille voulue et réduire, ou activer `antialias` (déjà actif) |
| Véhicule coupé | `dist` trop faible | monter `dist`, pas le `fov` |
| `model load failed` | GLB absent ou chemin faux | le fichier doit s'appeler `model.glb` dans `tools/render/` |
| Rendu très lent | normal | SwiftShader est un rasteriseur CPU ; compte quelques secondes par image, le timeout de chargement est à 180 s |
| Chromium introuvable | chemin figé dans `shoot.js` | `executablePath` pointe sur `/opt/pw-browsers/…` ; l'adapter à l'environnement plutôt que de lancer `playwright install` |

## Intégrer un rendu dans l'IHM

Les PNG sont détourés (alpha réelle), donc composables sur n'importe quel
fond :

```qml
ImageAsset {
    source: "qrc:/assets/images/hero-wide.png"
    fillMode: Image.PreserveAspectFit
}
```

Fais toujours le rendu **à la taille d'affichage × 1**, pas plus : l'IHM
tourne en rendu logiciel et redimensionner une grande image à chaque frame
coûte du CPU. Pose un `Glow` derrière plutôt que d'ajouter de la lumière dans
la scène 3D — c'est réglable après coup et ça ne coûte pas un nouveau rendu.

## 3D temps réel : où c'est permis

- **Dans les maquettes HTML** (`project/*.dc.html`) : oui, three.js en UMD
  depuis un CDN autorisé, ou `<model-viewer>` pour une tournette interactive.
- **Dans `agoojiye-hmi`** : non. Pas de GPU sur la cible, tout est Canvas 2D
  et dégradés — c'est un choix assumé du projet (voir son README). Un besoin
  de 3D à l'écran se résout en **séquence d'images pré-rendues** : génère
  36 angles (`az` de 0 à 350 par pas de 10) et fais défiler les PNG.

```bash
# tournette 36 vues
python3 - <<'PY' > shots.json
import json
print(json.dumps([{"name":f"turn-{a:03d}","w":640,"h":360,"az":a,"el":8,
                   "dist":0.9,"fov":28} for a in range(0,360,10)]))
PY
node shoot.js out
```

Pèse le résultat avant de l'embarquer : 36 PNG en 640×360 ≈ quelques Mo, à
comparer au budget de l'image système.

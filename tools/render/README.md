# Rendu des visuels véhicule

Génère les images de la navette pour l'interface à partir du modèle 3D
(`project/vehicle/*.glb`), au lieu de découper une photo. Chaque écran
obtient l'angle de caméra dont il a besoin, en PNG détouré avec une vraie
transparence — donc composable sur n'importe quel fond.

## Utilisation

```bash
cd tools/render
npm install three playwright
cp ../../project/vehicle/*.glb model.glb
node shoot.js out
```

Les prises de vue se décrivent dans `shots.json` :

| champ  | rôle                                              |
|--------|---------------------------------------------------|
| `az`   | azimut en degrés — 225 = 3/4 avant, 270 = face, 180 = profil |
| `el`   | élévation en degrés                               |
| `dist` | distance, en multiple du rayon d'encombrement     |
| `fov`  | ouverture de la caméra                            |

Le rendu tourne dans le Chromium livré avec le conteneur, en WebGL logiciel
(SwiftShader) — aucun GPU requis. L'éclairage est volontairement sous-exposé
pour que le véhicule reste dans la palette nuit de l'interface.

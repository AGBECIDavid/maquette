# AGOOJIYE HMI

Interface embarquée de la navette électrique AGOOJIYE. Qt 6 / QML, sans
dépendance à un GPU : tout est dessiné en Canvas 2D et en dégradés, pour que le
rendu soit identique sur une cible embarquée en rendu logiciel.

## Démarrer

```bash
git clone git@github.com:AGBECIDavid/maquette.git
cd maquette/agoojiye-hmi
./run.sh
```

`run.sh` configure, construit, puis lance. S'il manque une dépendance, il la
nomme avec la commande qui l'installe. Sur Debian / Ubuntu / Kali :

```bash
sudo apt install build-essential cmake \
                 qt6-base-dev qt6-declarative-dev \
                 qml6-module-qtquick qml6-module-qtquick-controls \
                 qml6-module-qtquick-shapes qml6-module-qtquick-window
```

Si votre Qt vient de l'installeur officiel plutôt que du système :

```bash
CMAKE_PREFIX_PATH=$HOME/Qt/6.8.3/gcc_64 ./run.sh
```

## Vérifier que rien n'est cassé

```bash
./test.sh
```

Pas besoin d'écran : Qt tourne en mode *offscreen*, l'interface parcourt ses
38 panneaux, joue la séquence de démarrage, et le script échoue si Qt émet le
moindre avertissement QML ou si un panneau n'a pas pu s'afficher.

C'est ce qui attrape les vraies régressions : une dépendance circulaire ou une
propriété inconnue ne casse pas la compilation, mais fait s'effondrer une mise
en page en silence.

Pour regarder le résultat :

```bash
./test.sh --keep /tmp/captures
```

À lancer avant chaque `git push`.

## Où se trouve quoi

```
qml/
  Main.qml            coque : barre du haut, écrans, barre du bas
  AppState.qml        état d'interface — écran courant, sections, préférences
  VehicleData.qml     ← LE point de branchement du backend
  Theme.qml           couleurs, polices
  components/         briques réutilisées par tous les écrans
  screens/            un fichier par écran
assets/               polices, rendus 3D du véhicule
tools/render/         chaîne de rendu du modèle GLB vers les images
```

## Trois choses à savoir avant de toucher au code

**Aucune valeur métier n'est écrite dans un écran.** Tout vient de
`VehicleData.qml`. Un écran qui affiche `82 %` lit `VehicleData.batteryLevel` ;
il ne connaît pas la valeur. Voir [BACKEND.md](BACKEND.md) pour brancher le
backend — un seul fichier à modifier.

**La navigation passe par `AppState.go()`, et par lui seul.** Sept destinations
dans la barre du bas, décrites dans `navSections`. La séquence de démarrage
n'est pas un écran : elle n'a pas de clé de navigation, donc aucun bouton ne
peut la rejouer.

**Pas de shaders, pas d'effets graphiques.** `Glow`, `BatteryArc`, `Vignette`
sont dessinés à la main en Canvas. C'est délibéré : la cible embarquée n'a pas
forcément d'accélération matérielle, et un `ShaderEffect` y disparaîtrait sans
prévenir.

## Mode démo

`VehicleData.demoMode` fait osciller la vitesse et décroître la batterie pour
que la démo soit vivante sans backend. **À passer à `false` en production**,
sinon il écrasera les vraies valeurs.

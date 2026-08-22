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

Pas besoin d'écran : Qt tourne en mode *offscreen*. Le script échoue si un
avertissement QML apparaît, si un des 38 panneaux ne s'affiche pas, si l'état
véhicule viole une règle physique sur 30 s de simulation (frein de
stationnement en roulant, vitesse qui se téléporte, autonomie négative), ou si
une panne injectée ne remonte pas jusqu'au bandeau d'alerte.

Le relevé passe le simulateur en mode déterministe : sans cela les durées de
phase sont tirées au hasard, et le test réussirait ou échouerait selon le
tirage plutôt que selon l'état du code.

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

**Trois couches, une direction : source → état → interface.**
`VehicleSimulator.qml` produit, `VehicleData.qml` détient, les écrans lisent.
Aucune valeur métier n'est écrite dans un écran. Brancher le vrai véhicule, c'est
couper le simulateur et alimenter `VehicleData` — voir [BACKEND.md](BACKEND.md).

**Une donnée absente s'affiche `- -`, jamais une valeur inventée.**
`VehicleData.valid("speed")` et `reading()` portent cette notion, et un signal
manquant lève une alerte de lui-même.

**La navigation passe par `AppState.go()`, et par lui seul.** Sept destinations
dans la barre du bas, décrites dans `navSections`. La séquence de démarrage
n'est pas un écran : elle n'a pas de clé de navigation, donc aucun bouton ne
peut la rejouer.

**Pas de shaders, pas d'effets graphiques.** `Glow`, `BatteryArc`, `Vignette`
sont dessinés à la main en Canvas. C'est délibéré : la cible embarquée n'a pas
forcément d'accélération matérielle, et un `ShaderEffect` y disparaîtrait sans
prévenir.

## Mode démo

`VehicleSimulator.running` pilote la source simulée : un modèle physique
(accélération bornée, bilan d'énergie, thermique) qui fait vivre la maquette
sans véhicule. **À passer à `false` en production**, sinon il écrasera les
valeurs venues du bus.

## Outils de recette

```bash
HMI_TRACE=30 ./build/agoojiye-hmi       # état véhicule en CSV, 30 s
HMI_FAULT=tyre ./build/agoojiye-hmi     # injecte une panne (belt/tyre/battery/sensor/fault)
```

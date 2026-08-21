# Brancher le backend

L'interface ne contient **aucune valeur métier en dur**. Tout ce qui s'affiche
vient de `qml/VehicleData.qml`, un singleton QML qui sert de point de
branchement unique.

```
   backend (CAN / MQTT / socket / C++)
              │
              ▼
      qml/VehicleData.qml      ← le seul fichier à modifier
              │
   ┌──────────┼──────────┬─────────────┐
   ▼          ▼          ▼             ▼
 Accueil  Tableau de  Menu      les 9 autres écrans
            bord
```

`qml/AppState.qml` est séparé : il ne porte que l'état d'interface (écran
courant, bascules utilisateur). Le backend n'a pas à y toucher.

## Les trois façons de brancher

### 1. Depuis le C++ (recommandé)

Exposer un objet backend, puis lier les propriétés dans `VehicleData.qml` :

```cpp
// main.cpp
VehicleBackend backend;                       // QObject avec des Q_PROPERTY
engine.rootContext()->setContextProperty("Backend", &backend);
```

```qml
// VehicleData.qml — remplacer la valeur simulée par un binding
property real speed: Backend.speed
property int  batteryLevel: Backend.batteryLevel
```

Les `Q_PROPERTY` doivent déclarer un `NOTIFY` pour que l'interface se
rafraîchisse automatiquement.

### 2. Par écriture depuis un contrôleur

Aucune modification de `VehicleData.qml` : un contrôleur assigne directement.

```qml
VehicleData.speed = 32
VehicleData.batteryLevel = 74
```

### 3. Depuis une source QML (WebSocket, série…)

```qml
property real speed: telemetry.lastFrame.speed
```

## Avant la mise en production

Passer `demoMode` à `false` dans `VehicleData.qml`. Il pilote un timer qui fait
osciller la vitesse et décroître la batterie, uniquement pour que la démo soit
vivante sans backend. Une fois branché, il doit être coupé, sinon il écrasera
les vraies valeurs.

## Ce que contient VehicleData

| Groupe | Propriétés |
|---|---|
| Identité | `vehicleName`, `vehicleModel`, `vin`, `softwareVersion`, `uiVersion`, `storageUsed` |
| Propulsion | `speed`, `batteryLevel`, `consumption`, `rangeFullCharge`, `charging`, `driveGear`, `systemReady` |
| Compteurs | `odometer`, `serviceDueIn`, `serviceDueDate`, `faultPresent` |
| Environnement | `outsideTemp`, `speedLimit`, `cruiseSpeed`, `headlightsAuto` |
| Témoins | `seatbeltWarning`, `parkingBrake`, `tyrePressureWarning`, `driveMode` |
| Connectivité | `network`, `wifiConnected`, `bluetoothConnected` |
| Navigation | `navigationActive`, `nextManeuverDistance`, `nextManeuverStreet`, `followingStreet`, `routeProgress`, `arrivalTime`, `distanceRemaining`, `timeRemaining`, `trafficCondition` |
| Média | `mediaPlaying`, `trackTitle`, `trackArtist`, `trackAlbum`, `volume` |
| Téléphone | `contactCount`, `recentCallCount`, `missedCallCount` |
| Démarrage | `startupChecks` |

Deux valeurs sont dérivées et n'ont pas à être alimentées :
`batteryFraction` (= `batteryLevel / 100`) et `range`
(= `batteryFraction × rangeFullCharge`).

## Points encore en dur

Ces listes restent dans leurs écrans, faute de modèle backend défini. À
remonter dans `VehicleData` quand leur format sera arrêté :

- la playlist et la file d'attente (`MediaScreen`, `MediaNowScreen`)
- le journal d'appels (`PhoneScreen`)
- l'historique d'entretien et l'état des composants (`EntretienScreen`)
- les étapes d'itinéraire (`NavigationScreen`)
- les noms de rue, hérités des maquettes d'origine (parisiens) — à remplacer
  par le contexte de déploiement réel

## Navigation

Trois niveaux, décrits en tête de `qml/AppState.qml` :

```
  démarrage  ─────►  accueil (tableau de bord)  ◄────►  applications
   une fois           écran de référence            barre du bas
```

La barre du bas porte **sept destinations**, définies au même endroit dans
`navSections` :

| Bouton | Écran | Écrans secondaires rattachés |
|---|---|---|
| Accueil | `dash` | |
| Navigation | `nav` | |
| Véhicule | `veh` | `entretien` |
| Conduite | `conduite` | |
| ADAS | `adas` | |
| Média | `media` | `mediaNow` |
| Paramètres | `parametres` | |

Un écran secondaire garde le bouton de sa section allumé : l'utilisateur voit
toujours où il se trouve, et y revient d'un seul appui. Ajouter une destination,
c'est ajouter une ligne à `navSections` — la barre s'ajuste seule.

Le menu (`menu`) n'occupe aucun des sept boutons : c'est un tiroir, ouvert par
l'icône en haut à droite, qui donne accès à ce qui n'a pas sa place dans la
barre (téléphone, entretien, à propos). Le même bouton le referme.

`AppState.go()` est le seul point d'entrée ; `AppState.back()` ramène à l'écran
précédent. **La séquence de démarrage n'est pas un écran** : elle n'a pas de clé
de navigation, donc aucun bouton ne peut y ramener — l'animation ne se rejoue
jamais sur un changement de page.

## Séquence de démarrage

`qml/screens/BootScreen.qml` se joue une fois au lancement, puis passe la main au
tableau de bord — l'écran principal.

Toute la chronologie tient dans le bloc `SequentialAnimation` nommé `timeline`,
en fin de fichier : marque, approche du véhicule pendant les contrôles système,
« Système prêt », annonce vocale, fondu croisé. Régler le rythme se fait là et
nulle part ailleurs.

Les contrôles affichés viennent de `VehicleData.startupChecks` — l'écran ne sait
pas ce qu'il vérifie, il sait seulement l'afficher :

```qml
property var startupChecks: [
    { label: "Batterie", ok: true },
    ...
]
```

Un `ok: false` s'affiche en rouge sans qu'une ligne d'interface change. Le
minuteur `checkLoop` de `BootScreen` ne fait que dérouler la liste : dès que le
backend fournira de vrais diagnostics, c'est lui qui pilotera `checkIndex` et ce
minuteur disparaîtra.

La main se rend en deux temps — `handoff()` révèle le tableau de bord, puis
`finished()` retire la couche de démarrage une fois son fondu terminé. Les deux
se croisent, d'où l'enchaînement plutôt que la coupure.

## L'assistant vocal

Il passe par `VoiceAnnouncer` (C++), et **toute la chaîne est optionnelle** :
sans rien, le projet compile et tourne pareil, la bulle et son onde restent
affichées, seule la voix manque.

Trois couches doivent être en place pour entendre quelque chose, et c'est
presque toujours celle du milieu qui manque :

```
  module Qt Speech   →   plugin de sortie Qt   →   speech-dispatcher + espeak-ng
   (fait compiler)       (fait le pont)             (produit le son)
   qt6-speech-dev        qt6-speech-speechd-plugin  speech-dispatcher
```

Trouver le module **ne suffit pas à faire du son**. C'est le piège : CMake
annonce `Qt TextToSpeech trouvé`, l'application se lance, et reste muette en
signalant `No text-to-speech plug-ins were found` — il manque le plugin.

C'est pourquoi `VoiceAnnouncer` a deux chemins, essayés dans cet ordre :

1. **Qt TextToSpeech**, quand le module et son plugin sont là. Chemin propre :
   débit, volume, et l'état « parle » remonté par le moteur.
2. **`spd-say`**, le client en ligne de commande de speech-dispatcher, lancé en
   `QProcess`. Il rattrape le cas courant du plugin manquant. Règle simple :
   **si `spd-say -l fr "test"` parle dans un terminal, l'assistant parlera.**

Sur Debian/Kali/Ubuntu, tout activer :

```bash
sudo apt install speech-dispatcher speech-dispatcher-espeak-ng espeak-ng \
                 qt6-speech-dev qt6-speech-speechd-plugin
```

Les deux derniers ne concernent que le Qt système. Avec un Qt installé par
l'installeur officiel (`~/Qt/`), les versions ne correspondent pas : le module
et son plugin s'ajoutent par le Maintenance Tool (*Additional Libraries → Qt
Speech*) — ou on s'en passe, le repli `spd-say` suffit.

La voix française d'espeak-ng est très robotique ;
`sudo apt install speech-dispatcher-pico` donne un rendu nettement plus naturel
et sera choisi automatiquement, la sélection se faisant sur la langue.

La phrase prononcée suit le nom du véhicule : elle se change via
`VehicleData.vehicleName`, pas dans l'écran.

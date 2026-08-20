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

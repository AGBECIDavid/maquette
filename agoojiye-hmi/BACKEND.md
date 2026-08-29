# Brancher le backend

L'interface ne contient **aucune valeur métier en dur**. Trois couches, et une
seule direction :

```
   source                        état                     interface
   ──────                        ────                     ─────────

   VehicleSimulator.qml  ─┐
   CAN / ECU / capteurs  ─┼──►   VehicleData.qml   ──►    12 écrans
   GPS / API / socket    ─┘      (ne produit rien,        38 panneaux
                                  détient tout)           alertes, témoins
```

**`VehicleData.qml` ne calcule ni ne simule rien** : il détient l'état. Une
source écrit dedans, l'interface le lit. Aujourd'hui la source est
`VehicleSimulator.qml` ; demain c'est le lien véhicule, et pas une ligne
d'écran ne change.

`qml/AppState.qml` est à part : il ne porte que l'état d'interface (écran
courant, section ouverte, préférences d'usage). Le backend n'a pas à y toucher.

## Remplacer le simulateur par le véhicule

Une seule ligne suffit à rendre la main :

```qml
// qml/VehicleSimulator.qml
property bool running: false
```

Puis alimentez `VehicleData` depuis votre source, de l'une des trois façons
décrites plus bas. Aucun écran, aucun composant, aucune alerte ne bouge.

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

## Ce que simule VehicleSimulator

Pas des chiffres au hasard : un modèle. Une valeur qui saute trahit la maquette
immédiatement, et un tableau de bord se juge d'abord à la crédibilité de ses
variations.

| Grandeur | Comment elle est produite |
|---|---|
| Vitesse | accélération bornée à 1,1 m/s² au départ, 1,8 m/s² au freinage — jamais de téléportation |
| Puissance | roulement + aérodynamique + inertie, divisée par le rendement de chaîne |
| Récupération | au lever de pied et au freinage, à 55 % de rendement |
| Consommation | moyenne glissante réelle sur ~5 km, pas une constante |
| Autonomie | énergie restante ÷ consommation constatée — rouler vite la fait baisser plus vite |
| Batterie | bilan d'énergie ; sous 8 % la navette passe en charge au lieu de reboucler |
| Températures | montée sous charge, retombée au repos, avec inertie |
| Rapport / frein | `P` + frein serré à l'arrêt, `D` + frein desserré en roulant |

Le scénario joué est celui d'une navette en service : départ d'arrêt, vitesse de
croisière, ralentissement, arrêt, redépart.

**Le pas d'intégration est le temps réellement écoulé**, pas la cadence visée du
minuteur. Un minuteur Qt n'est pas ponctuel : sous charge, en rendu logiciel ou
après un ramasse-miettes, il arrive en retard. Supposer 100 ms fixes ferait
avancer le modèle moins vite que le monde, et la navette simulée dériverait du
réel — d'autant plus que la cible embarquée est modeste. Le pas est plafonné à
350 ms pour qu'une longue interruption ne se rattrape pas d'un bond.

**Mode déterministe.** `VehicleSimulator.deterministic` fixe les durées de phase
au lieu de les tirer au hasard. Le hasard rend la démo vivante mais un test
instable : selon le tirage, 30 s de relevé peuvent ne contenir aucun freinage.
`HMI_TRACE` l'active automatiquement — une mesure doit être répétable.

## Chaîne haute tension

Cinq organes contrôlés au démarrage, **avant tout le reste**. Sur un véhicule
électrique ils conditionnent la mise sous tension : tant qu'ils n'ont pas
répondu, rien ne sert de vérifier le GPS.

| Organe | `id` | Bloquant |
|---|---|---|
| NON-Contact Châssis — Circuit HT | `isolation` | **oui** |
| Batterie de traction | `pack` | non |
| BMS | `bms` | non |
| OBC | `obc` | non |
| Moteur | `motor` | non |

Chaque entrée porte `fault`, qui vaut **0 (conforme)** ou **1 (en défaut)** —
la convention des bits de défaut d'un bus véhicule. C'est ce que la source
écrit, via `VehicleData.setHvFault(id, faulty)`.

**Le défaut d'isolement est le seul qui bloque.** Un circuit haute tension en
contact avec la caisse met le châssis sous tension, donc les passagers : ce
n'est pas un voyant à ignorer, c'est un refus de démarrage. Les quatre autres
affichent l'écran rouge avec un bouton « Continuer malgré tout ».

Le verrou vit dans `AppState.dismissHvDiagnostic()`, pas dans l'écran : ainsi
aucun autre appelant ne peut le contourner.

### Régler les cinq valeurs

Une ligne dans `qml/VehicleSimulator.qml`, un chiffre par organe, dans l'ordre
du tableau ci-dessus :

```qml
property string hvTestPattern: "00000"
```

| Motif | Effet |
|---|---|
| `00000` | tout est sain, démarrage normal |
| `01000` | batterie de traction en défaut → écran rouge, contournable |
| `10000` | défaut d'isolement → écran rouge, **démarrage refusé** |
| `11111` | toute la chaîne au tapis |

Modifier puis `./run.sh`. Pour changer de cas sans recompiler :

```bash
HMI_HV=10000 ./build/agoojiye-hmi
```

Un motif trop court ou mal tapé vaut conforme sur les positions manquantes :
une erreur de frappe peut faire manquer une panne, jamais en inventer une.

### Ce qui se passe au démarrage

La séquence joue deux étapes — `CONTRÔLE HAUTE TENSION`, puis
`SYSTÈMES DE BORD`. Si la première échoue, la séquence **s'arrête là** : pas
d'approche du véhicule, pas de « bienvenue ». Une navette dont l'isolement est
douteux n'accueille personne, elle refuse de démarrer.

La chronologie tient dans trois animations en fin de `BootScreen.qml` :
`bootIntro`, puis `bootRest` ou `abortSequence` selon l'issue. L'aiguillage
tient dans `stageComplete()`.

Un défaut haute tension remonte aussi dans `activeAlerts`, en tête et au niveau
`CRITICAL`.

## Qualité des signaux

Un bus véhicule perd des trames. Sans cette notion, l'interface affiche la
dernière valeur connue comme si elle était fraîche — le mensonge le plus
dangereux qu'un tableau de bord puisse faire.

```qml
VehicleData.setQuality("speed", "MISSING")   // depuis la source
VehicleData.valid("speed")                   // depuis un écran
VehicleData.reading("speed", valeur, 1)      // "50.0" ou "- -"
```

Trois états : `OK` (fraîche), `STALE` (dernière connue), `MISSING` (rien à
afficher). Un signal `MISSING` fait afficher `- -` et lève automatiquement une
alerte : le conducteur sait que la valeur manque, il ne la devine pas.

## Alertes

`VehicleData.activeAlerts` est **dérivée de l'état**, jamais posée à la main :
une alerte qui survit à sa cause est pire que pas d'alerte du tout.

| Niveau | Comportement |
|---|---|
| `CRITICAL` | rouge, pulsation lente, **non masquable** tant que la cause dure |
| `WARNING` | ambre, fixe, masquable |
| `INFO` | bleu, discret, masquable |

Le bandeau (`components/AlertBanner.qml`) prend sa place dans la colonne au lieu
de se poser par-dessus : recouvrir une commande à l'instant où le conducteur la
cherche est pire que décaler l'écran de quelques dizaines de pixels.

Règles couvertes : frein de stationnement en roulant, ceinture, défaut système,
batterie faible puis critique, pression des pneus, dépassement de la limite,
ouvrant non fermé, signal indisponible.

## Outils de recette

```bash
HMI_TRACE=30 ./build/agoojiye-hmi          # 30 s d'état véhicule en CSV
HMI_FAULT=tyre ./build/agoojiye-hmi        # injecte une panne au démarrage
HMI_HV=10000 ./build/agoojiye-hmi          # force un défaut de la chaîne HT
```

Pannes disponibles : `belt`, `tyre`, `battery`, `sensor`, `fault`.

« Frein serré en roulant » ne figure pas dans la liste : le modèle l'interdit
désormais par construction, et c'est précisément le correctif.

`./test.sh` s'appuie sur les deux : il vérifie qu'aucune règle physique n'est
violée sur 30 s, et que chaque panne injectée remonte bien jusqu'au bandeau.

## Avant la mise en production

Passer `VehicleSimulator.running` à `false`. Tant qu'il tourne, il écrase les
valeurs venues du véhicule.

## Ce que contient VehicleData

| Groupe | Propriétés à alimenter |
|---|---|
| Identité | `vehicleName`, `vehicleModel`, `vin`, `softwareVersion`, `uiVersion`, `storageUsed`, `commissioningDate` |
| Propulsion | `speed`, `batteryLevel`, `consumption`, `batteryCapacity`, `rangeFullCharge`, `charging`, `chargeStatus`, `chargeCycles`, `power`, `regenPower`, `driveGear`, `systemReady` |
| Chaîne HT | `hvChain` (via `setHvFault()`) |
| Ouvrants | `openings` |
| Pneus | `tyreFrontLeft`, `tyreFrontRight`, `tyreRearLeft`, `tyreRearRight`, `tyreRecommended` |
| Températures | `motorTemp`, `batteryTemp`, `cabinTemp`, `outsideTemp` |
| Usure | `brakePadFront`, `brakePadRear`, `brakeFluid`, `washerFluid`, `lastInspection`, `serviceHistory` |
| Compteurs | `odometer`, `serviceDueIn`, `serviceDueDate`, `faultPresent` |
| Réglementaire | `speedLimit`, `cruiseSpeed`, `headlightsAuto` |
| Témoins | `seatbeltFastened`, `parkingBrake`, `driveMode` |
| Connectivité | `network`, `wifiConnected`, `bluetoothConnected` |
| Navigation | `navigationActive`, `nextManeuverDistance`, `nextManeuverStreet`, `nextManeuverIcon`, `followingStreet`, `routeProgress`, `arrivalTime`, `distanceRemaining`, `timeRemaining`, `trafficCondition` |
| Média | `mediaPlaying`, `trackTitle`, `trackArtist`, `trackAlbum` |
| Téléphone | `contactCount`, `recentCallCount`, `missedCallCount` |
| Démarrage | `startupChecks` |
| Qualité | `signalState` (via `setQuality()`) |

**Ne pas alimenter les valeurs dérivées** — elles se calculent seules, et les
écrire à la main est précisément ce qui produisait des écrans qui se
contredisaient :

| Dérivée | Règle |
|---|---|
| `batteryFraction` | `batteryLevel / 100` |
| `range` | énergie restante ÷ consommation constatée |
| `moving` | `speed > 0,5` |
| `seatbeltWarning` | en roulant **et** ceinture non bouclée |
| `tyrePressureWarning` | écart > 0,3 bar à la consigne sur une roue |
| `hvFaults`, `hvFaultPresent`, `hvBlocking` | déduits des bits `fault` de la chaîne |
| `activeAlerts`, `topAlert`, `hasCriticalAlert` | dérivées de l'état complet |

Le volume média appartient à l'interface, pas au véhicule : il vit dans
`AppState.mediaVolume`.

## Points encore en dur

Ces listes restent dans leurs écrans, faute de modèle backend défini. À
remonter dans `VehicleData` quand leur format sera arrêté :

- la playlist, la file d'attente et les stations radio (`MediaScreen`,
  `MediaNowScreen`)
- le journal d'appels et le contact affiché (`PhoneScreen`)
- les étapes d'itinéraire et les libellés de la carte (`NavigationScreen`)
- les appareils Bluetooth appairés (`MediaScreen`)
- les noms de rue, hérités des maquettes d'origine (parisiens) — à remplacer
  par le contexte de déploiement réel

L'historique d'entretien, l'usure des plaquettes et l'état des composants sont
remontés dans `VehicleData` depuis la reprise : ils figuraient en dur dans deux
écrans à la fois, avec des valeurs qui avaient déjà divergé.

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

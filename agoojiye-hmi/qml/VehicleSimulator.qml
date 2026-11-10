pragma Singleton
import QtQuick

// =============================================================================
//  SOURCE DE DONNÉES SIMULÉE
// =============================================================================
//
//   VehicleSimulator  ──►  VehicleData  ──►  interface
//   (cette source)         (l'état)          (les écrans)
//
//  Ce fichier occupe exactement la place que prendra le lien véhicule réel
//  (CAN, ECU, capteurs, API). Il écrit dans les mêmes propriétés de
//  `VehicleData` ; le jour où la vraie source arrive, on coupe celle-ci
//  (`running: false`) et aucun écran ne change.
//
//  Il ne s'agit pas de faire bouger des chiffres au hasard. Une valeur qui
//  saute trahit la maquette immédiatement — un tableau de bord se juge d'abord
//  à la crédibilité de ses variations. Le modèle ci-dessous respecte donc :
//
//   · une accélération bornée — la vitesse ne se téléporte jamais ;
//   · un bilan d'énergie — rouler vite coûte plus cher, et l'autonomie suit ;
//   · une thermique — les températures montent sous charge, retombent au repos ;
//   · une cohérence d'états — frein de stationnement et rapport engagé
//     s'accordent, ce qui interdit les situations physiquement impossibles.
//
//  Le scénario joué est celui d'une navette en service : elle quitte un arrêt,
//  rejoint sa vitesse de croisière, ralentit, s'arrête, repart.
// =============================================================================

QtObject {
    id: sim

    // Le simulateur tourne dans la construction de démonstration, jamais dans
    // celle de production (-DAGOOJIYE_PRODUCTION=ON) : `agoojiyeDemo` est posé
    // par main.cpp selon la compilation. Ce n'est donc plus une ligne à penser
    // à modifier avant d'embarquer.
    //
    // Tant qu'il tourne, la barre du haut affiche « DÉMO » : des valeurs
    // simulées ne doivent jamais passer pour celles du véhicule.
    property bool running: agoojiyeDemo

    // Cadence visée. 100 ms suffit pour que l'œil lise un mouvement continu,
    // sans réveiller le processeur inutilement sur cible embarquée.
    readonly property int stepMs: 100

    // Le pas d'intégration est le temps *réellement* écoulé, pas la cadence
    // visée. Un minuteur Qt n'est pas ponctuel : sous charge, en rendu logiciel
    // ou après un ramasse-miettes, il arrive en retard. Supposer 100 ms fixes
    // ferait avancer le modèle moins vite que le monde — le véhicule simulé
    // dériverait du réel, d'autant plus que la cible est modeste.
    property real lastTickMs: 0

    // Plafond du pas : après une longue interruption on ne rattrape pas d'un
    // bond, ce qui téléporterait la navette. On repart de la cadence normale.
    readonly property real maxStepSeconds: 0.35

    // Accélération du temps simulé, pour la recette : à 8, un trajet de
    // 4 minutes se joue en 30 s. Toujours 1 en démonstration.
    property real timeScale: 1

    // ---- déterminisme pour la recette -------------------------------------
    // Les durées de phase sont tirées au hasard, ce qui rend la démo vivante
    // mais un test instable : selon le tirage, 30 s de relevé peuvent ne jamais
    // contenir de freinage. En mode déterministe le cycle est fixe et court,
    // donc une mesure voit toujours les trois phases.
    property bool deterministic: false

    // ---- paramètres physiques de la navette ------------------------------
    readonly property real maxAccel: 1.1        // m/s²  — départ en charge
    readonly property real maxBrake: 1.8        // m/s²  — freinage confortable
    readonly property real mass: 1450           // kg
    readonly property real rollingCoef: 0.014   // résistance au roulement
    readonly property real dragArea: 2.6        // m² × Cx, carrosserie ouverte
    readonly property real driveEfficiency: 0.86
    readonly property real regenEfficiency: 0.55
    readonly property real auxLoad: 0.8         // kW — éclairage, écran, pompes

    // ---- phases du service ------------------------------------------------
    // "arret" à quai → "roulage" jusqu'au prochain arrêt → "arret"…
    property string phase: "arret"
    property real phaseTimer: 2.0               // s restantes dans la phase
    property real targetSpeed: 0                // km/h visés

    // Énergie consommée depuis le dernier calcul de moyenne, et distance
    // correspondante : la consommation affichée est une vraie moyenne glissante.
    property real windowEnergy: 0.35            // kWh
    property real windowDistance: 3.0           // km

    // Accumulateurs fins. `VehicleData` expose des entiers, lisibles à l'écran ;
    // arrondir à chaque pas de 100 ms figerait les valeurs, car la variation
    // d'un pas est très inférieure à l'unité affichée.
    property real _battPct: 82
    property real _motorTemp: 42
    property real _battTemp: 27
    property real _odoFraction: 0

    // ---- contrôle de la chaîne haute tension ------------------------------
    // Un chiffre par organe, dans l'ordre de `VehicleData.hvChain` :
    //
    //     isolement châssis · batterie de traction · BMS · OBC · moteur
    //
    //     0 = conforme        1 = en défaut
    //
    // Modifier cette ligne puis relancer `./run.sh` rejoue n'importe quel
    // scénario de panne. Exemples :
    //
    //     "00000"   tout est sain, démarrage normal
    //     "01000"   batterie de traction en défaut → écran rouge, contournable
    //     "10000"   défaut d'isolement → écran rouge, démarrage refusé
    //     "11111"   toute la chaîne au tapis
    //
    // `HMI_HV=01000 ./build/agoojiye-hmi` surcharge cette valeur au lancement,
    // pour passer d'un cas à l'autre en démonstration sans recompiler.
    property string hvTestPattern: "00000"

    // Applique un motif à la chaîne. Tout caractère autre que « 1 » vaut
    // conforme : un motif trop court ou mal tapé ne doit jamais inventer une
    // panne, seulement en manquer une.
    function applyHvPattern(pattern) {
        if (pattern === undefined || pattern === null)
            return
        for (var i = 0; i < VehicleData.hvChain.length; i++)
            VehicleData.setHvFault(VehicleData.hvChain[i].id,
                                   pattern.charAt(i) === "1")
    }

    Component.onCompleted: applyHvPattern(hvTestPattern)

    // ---- injection de pannes ----------------------------------------------
    // Une chaîne d'alerte qu'on ne sait pas déclencher est une chaîne d'alerte
    // qu'on ne sait pas tester. Ces scénarios servent à la démonstration et à
    // la recette : ils reproduisent des conditions réelles, chacune remontant
    // jusqu'au bandeau d'alerte.
    //
    // « frein serré en roulant » ne figure pas ici : le modèle l'interdit
    // désormais par construction, et c'est précisément le correctif.
    property string faultMode: ""

    function injectFault(kind) {
        faultMode = kind
        if (kind === "gps") {
            // Perte en roulant : le signal tient 8 s, disparaît 45 s, revient.
            // Assez pour voir la position passer d'« estimée » à « perdue ».
            _gpsOutage.start()
        } else if (kind === "gps-froid") {
            // Démarrage à froid : 20 s avant le premier point, comme un
            // récepteur qui n'a pas encore son almanach.
            gpsAvailable = false
            _gpsColdStart.start()
        } else if (kind === "belt") {
            VehicleData.seatbeltFastened = false
        } else if (kind === "tyre") {
            VehicleData.tyreRearLeft = 1.8          // crevaison lente
        } else if (kind === "battery") {
            _battPct = 9
            VehicleData.batteryLevel = 9
        } else if (kind === "sensor") {
            VehicleData.setQuality("speed", "MISSING")
        } else if (kind === "fault") {
            VehicleData.faultPresent = true
        }
    }

    function clearFaults() {
        faultMode = ""
        gpsAvailable = true
        _gpsOutage.stop()
        _gpsColdStart.stop()
        VehicleData.seatbeltFastened = true
        VehicleData.tyreRearLeft = 2.6
        VehicleData.faultPresent = false
        VehicleData.setQuality("speed", "OK")
    }

    function dropSignal(name) { VehicleData.setQuality(name, "MISSING") }
    function restoreSignal(name) { VehicleData.setQuality(name, "OK") }

    function nextPhase() {
        if (phase === "arret") {
            phase = "roulage"
            // Une navette urbaine ne roule pas toujours à la même allure.
            targetSpeed = deterministic ? 40 : 28 + Math.random() * 22
            phaseTimer = deterministic ? 12 : 14 + Math.random() * 16
        } else if (phase === "roulage") {
            phase = "ralentissement"
            targetSpeed = 0
            phaseTimer = 30                              // borne de sécurité
        } else {
            phase = "arret"
            targetSpeed = 0
            phaseTimer = deterministic ? 3 : 4 + Math.random() * 5
        }
    }

    // ---- trajet sur la carte ----------------------------------------------
    // Le chemin vient de Navigation, posé par Main.qml : l'itinéraire pendant
    // un guidage, une boucle de service dans la zone sinon. Points
    // [latitude, longitude, distance depuis le départ en m]. Un nouveau chemin
    // part toujours de là où est la navette : on le reprend à zéro.
    property var path: []
    property int pathVersion: 0
    // Distance où reprend la boucle quand on arrive au bout ; -1 : pas de
    // boucle, on s'arrête au bout (fin d'un guidage).
    property real pathLoopFrom: 0
    // Vitesse conseillée par la navigation (virages, ronds-points, arrivée).
    property real advisedSpeed: 50
    readonly property bool routeMode: pathLoopFrom < 0 && path.length > 1
    property real _along: 0
    property int _seg: 0
    property bool gpsAvailable: true

    // Le chemin, sa version et son point de boucle changent ensemble, mais
    // leurs liaisons se mettent à jour une à une : on attend qu'elles aient
    // toutes abouti avant de lire `routeMode`.
    onPathVersionChanged: Qt.callLater(_newPath)
    function _newPath() {
        _along = 0
        _seg = 0
        if (routeMode) {
            // Départ d'un guidage : on roule jusqu'à destination, sans les
            // arrêts de la boucle de service.
            phase = "roulage"
            targetSpeed = 45
            phaseTimer = 1e9
        } else if (phase === "arret" && phaseTimer > 1e6) {
            // Fin d'un guidage : la navette repart sur sa boucle.
            phaseTimer = 3
        }
    }

    function _pointAt(d) {
        var p = sim.path
        var n = p.length
        if (n === 0)
            return null
        if (d <= p[0][2])
            return { lat: p[0][0], lon: p[0][1] }
        if (d >= p[n - 1][2])
            return { lat: p[n - 1][0], lon: p[n - 1][1] }
        var i = sim._seg
        if (i >= n - 1 || p[i][2] > d)
            i = 0
        while (i < n - 2 && p[i + 1][2] < d)
            i++
        var len = p[i + 1][2] - p[i][2]
        var t = len > 1e-6 ? (d - p[i][2]) / len : 0
        return { lat: p[i][0] + (p[i + 1][0] - p[i][0]) * t,
                 lon: p[i][1] + (p[i + 1][1] - p[i][1]) * t, seg: i }
    }

    function _bearing(a, b) {
        var k = Math.cos(a.lat * Math.PI / 180)
        var deg = Math.atan2((b.lon - a.lon) * k, b.lat - a.lat) * 180 / Math.PI
        return deg < 0 ? deg + 360 : deg
    }

    function _advanceOnPath(meters) {
        var p = sim.path
        if (p.length < 2)
            return
        var length = p[p.length - 1][2]
        var d = sim._along + meters
        if (d >= length)
            d = sim.pathLoopFrom >= 0 ? sim.pathLoopFrom + (d - length) : length
        sim._along = d
        var here = _pointAt(d)
        if (here.seg !== undefined)
            sim._seg = here.seg
        // Le cap se mesure sur 8 m autour de la position : un nœud de dessin
        // ne fait pas sursauter la flèche.
        var back = _pointAt(Math.max(0, d - 4)), ahead = _pointAt(Math.min(length, d + 4))
        if (back.lat !== ahead.lat || back.lon !== ahead.lon)
            VehicleData.heading = Math.round(_bearing(back, ahead) * 10) / 10
        VehicleData.gpsFix = sim.gpsAvailable
        if (sim.gpsAvailable) {
            VehicleData.latitude = here.lat
            VehicleData.longitude = here.lon
        }
    }

    // Les durées de panne suivent le temps simulé : accéléré pour la recette,
    // le scénario garde ses proportions.
    property Timer _gpsOutage: Timer {
        interval: 8000 / sim.timeScale
        onTriggered: { sim.gpsAvailable = false; sim._gpsBack.start() }
    }
    property Timer _gpsBack: Timer {
        interval: 45000 / sim.timeScale
        onTriggered: sim.gpsAvailable = true
    }
    property Timer _gpsColdStart: Timer {
        interval: 20000 / sim.timeScale
        onTriggered: sim.gpsAvailable = true
    }

    // Un clignotant gauche ou droit se coupe de lui-même une fois le virage
    // passé — le comodo revient au neutre quand le volant se redresse. Sans
    // volant à simuler, on le coupe après 20 s. Les feux de détresse, eux,
    // restent jusqu'à ce qu'on les éteigne.
    property Connections _turnWatch: Connections {
        target: VehicleData
        function onTurnSignalChanged() {
            if (VehicleData.turnSignal === "left" || VehicleData.turnSignal === "right")
                sim._turnCancel.restart()
            else
                sim._turnCancel.stop()
        }
    }
    property Timer _turnCancel: Timer {
        interval: 20000
        onTriggered: if (sim.running) VehicleData.turnSignal = "off"
    }

    // Le lave-glace est une impulsion : la pompe gicle quelques secondes, les
    // balais passent, puis tout revient comme avant.
    property Connections _washWatch: Connections {
        target: VehicleData
        function onWashingChanged() { if (VehicleData.washing) sim._washTimer.restart() }
    }
    property Timer _washTimer: Timer {
        interval: 3000
        onTriggered: VehicleData.washing = false
    }

    property Timer _tick: Timer {
        interval: sim.stepMs
        running: sim.running
        repeat: true

        onTriggered: {
            // Temps réellement écoulé depuis le tick précédent, borné.
            var now = Date.now()
            var dt = (sim.lastTickMs > 0
                ? Math.min(sim.maxStepSeconds, (now - sim.lastTickMs) / 1000.0)
                : sim.stepMs / 1000.0) * sim.timeScale
            sim.lastTickMs = now
            if (dt <= 0)
                return

            var v = VehicleData.speed / 3.6                   // m/s
            // La consigne de la phase, plafonnée par ce que la route permet :
            // on ralentit avant un rond-point, on s'arrête à destination.
            var target = Math.min(sim.targetSpeed, sim.advisedSpeed) / 3.6

            // ---- 1. vitesse : approche bornée de la consigne --------------
            var accel = 0
            if (target > v + 0.05)
                accel = Math.min(sim.maxAccel, (target - v) / dt)
            else if (target < v - 0.05)
                accel = -Math.min(sim.maxBrake, (v - target) / dt)

            v = Math.max(0, v + accel * dt)
            VehicleData.speed = Math.round(v * 3.6 * 10) / 10

            // ---- 2. puissance : traction, roulement, aéro, auxiliaires ----
            var fRoll = v > 0.1 ? sim.rollingCoef * sim.mass * 9.81 : 0
            var fDrag = 0.5 * 1.2 * sim.dragArea * v * v
            var fAccel = sim.mass * accel
            var mech = (fRoll + fDrag + fAccel) * v / 1000.0   // kW à la roue

            var draw
            if (mech >= 0) {
                draw = mech / sim.driveEfficiency + sim.auxLoad
                VehicleData.regenPower = 0
            } else {
                // Au lever de pied et au freinage, l'énergie revient.
                var recovered = -mech * sim.regenEfficiency
                VehicleData.regenPower = Math.round(recovered * 10) / 10
                draw = sim.auxLoad - recovered
            }
            VehicleData.power = Math.round(draw * 10) / 10

            // ---- 3. énergie et autonomie ---------------------------------
            var dEnergy = draw * dt / 3600.0               // kWh
            var dDist = v * dt / 1000.0                    // km

            sim.windowEnergy = Math.max(0, sim.windowEnergy + dEnergy)
            sim.windowDistance += dDist

            // Moyenne glissante sur une fenêtre glissante d'environ 5 km : la
            // consommation affichée bouge, mais lentement, comme sur un vrai
            // ordinateur de bord.
            if (sim.windowDistance > 5) {
                var drop = 0.02
                sim.windowEnergy *= (1 - drop)
                sim.windowDistance *= (1 - drop)
            }
            if (sim.windowDistance > 0.2) {
                var cons = sim.windowEnergy / sim.windowDistance * 100
                VehicleData.consumption =
                    Math.round(Math.max(4, Math.min(30, cons)) * 10) / 10
            }

            // Niveau de batterie, en pourcentage de la capacité utile.
            var pct = sim._battPct - dEnergy / VehicleData.batteryCapacity * 100
            if (sim.faultMode === "battery") {
                // Scénario de recette : on gèle le niveau pour que l'alerte
                // reste observable au lieu d'être effacée par la recharge.
                pct = sim._battPct
            } else if (pct <= 8) {
                // Fin de service : la navette rentre au chargeur plutôt que de
                // repasser magiquement à 82 %.
                VehicleData.charging = true
                VehicleData.chargeStatus = "En charge — 7,4 kW"
                pct = sim._battPct + 7.4 * dt / 3600.0
                             / VehicleData.batteryCapacity * 100 * 60
            } else if (VehicleData.charging && pct >= 80) {
                VehicleData.charging = false
                VehicleData.chargeStatus = "Non branché"
            } else if (VehicleData.charging) {
                pct = sim._battPct + 7.4 * dt / 3600.0
                             / VehicleData.batteryCapacity * 100 * 60
            }
            sim._battPct = Math.max(0, Math.min(100, pct))
            VehicleData.batteryLevel = Math.round(sim._battPct)

            // ---- 3 bis. position sur la carte ------------------------------
            sim._advanceOnPath(v * dt)

            // ---- 4. compteur kilométrique --------------------------------
            sim._odoFraction += dDist
            if (sim._odoFraction >= 1) {
                VehicleData.odometer += Math.floor(sim._odoFraction)
                VehicleData.serviceDueIn = Math.max(
                    0, VehicleData.serviceDueIn - Math.floor(sim._odoFraction))
                sim._odoFraction -= Math.floor(sim._odoFraction)
            }

            // ---- 5. thermique --------------------------------------------
            // Le moteur suit la charge avec de l'inertie ; la batterie chauffe
            // plus lentement et se refroidit de même.
            var motorTarget = 35 + Math.min(55, Math.abs(draw) * 3.2)
            sim._motorTemp += (motorTarget - sim._motorTemp) * Math.min(1, 0.04 * dt)
            VehicleData.motorTemp = Math.round(sim._motorTemp)

            var battTarget = VehicleData.outsideTemp + 4 + Math.min(18, Math.abs(draw) * 0.9)
            sim._battTemp += (battTarget - sim._battTemp) * Math.min(1, 0.02 * dt)
            VehicleData.batteryTemp = Math.round(sim._battTemp)

            // ---- 6. états cohérents ---------------------------------------
            // Le frein de stationnement n'est serré qu'à l'arrêt complet, et le
            // rapport suit le mouvement. Ces deux règles suffisent à interdire
            // « 50 km/h, frein serré » — une situation qu'aucun véhicule réel
            // ne peut produire et qu'aucune maquette ne devrait afficher.
            if (VehicleData.speed < 0.5 && sim.phase === "arret") {
                VehicleData.driveGear = "P"
                VehicleData.parkingBrake = true
            } else {
                VehicleData.driveGear = "D"
                VehicleData.parkingBrake = false
            }

            // Le régulateur affiche la consigne réellement suivie.
            if (sim.phase === "roulage")
                VehicleData.cruiseSpeed = Math.round(sim.targetSpeed)

            // ---- 7. avancement du scénario --------------------------------
            // En guidage, arrivée = arrêt, jusqu'au prochain chemin.
            if (sim.routeMode && sim.phase === "roulage" && sim.advisedSpeed < 1 && VehicleData.speed < 0.5) {
                sim.phase = "arret"
                sim.targetSpeed = 0
                sim.phaseTimer = 1e9
            }
            sim.phaseTimer -= dt
            if (sim.phase === "ralentissement" && VehicleData.speed < 0.5)
                sim.nextPhase()
            else if (sim.phaseTimer <= 0)
                sim.nextPhase()
        }
    }
}

pragma Singleton
import QtQuick

// =============================================================================
//  ÉTAT VÉHICULE — POINT DE BRANCHEMENT BACKEND
// =============================================================================
//
//   source              état             interface
//   ──────              ────             ─────────
//   VehicleSimulator ─┐
//   CAN / ECU / API  ─┼──►  VehicleData  ──►  écrans, widgets, alertes
//   capteurs, GPS    ─┘
//
//  Ce fichier ne produit aucune donnée : il les *détient*. Une source écrit
//  dedans, l'interface les lit. Aujourd'hui la source est
//  `VehicleSimulator.qml` ; demain ce sera le lien véhicule, et pas une ligne
//  d'écran ne changera.
// =============================================================================
//
//  Toutes les valeurs métier affichées par l'interface vivent ici, et nulle
//  part ailleurs. Les écrans ne contiennent aucune donnée en dur : ils lisent
//  `VehicleData.xxx`.
//
//  Quand le backend existera, il y a trois façons de le brancher, sans toucher
//  à un seul écran :
//
//   1. Depuis le C++ — exposer un objet et lier les propriétés :
//          engine.rootContext()->setContextProperty("Backend", &backend);
//      puis, ici :  property real speed: Backend.speed
//
//   2. Depuis QML — remplacer la valeur littérale par un binding sur la source
//      réelle (socket, MQTT, CAN…).
//
//   3. Par écriture — un contrôleur peut simplement assigner les propriétés
//      (`VehicleData.speed = 32`) ; l'interface se met à jour toute seule.
//
//  La simulation vit dans `VehicleSimulator.qml`. La couper (`running: false`)
//  fige l'état sur les valeurs ci-dessous sans rien casser.
// =============================================================================

QtObject {
    id: root

    // ---- Identité véhicule ---------------------------------------------
    property string vehicleName: "AGOOJIYE"
    property string vehicleModel: "Navette électrique"
    property string vin: "VR3A1ZK87P1234567"
    property string softwareVersion: "1.0.0"
    property string uiVersion: "1.0.0"
    property string storageUsed: "28.4 GB / 64 GB"

    // ---- Propulsion / énergie -------------------------------------------
    property real speed: 0                  // km/h — vitesse instantanée
    property int batteryLevel: 82           // %
    property real consumption: 11.4         // kWh/100 km — moyenne glissante
    property real batteryCapacity: 13.7     // kWh utiles
    property int rangeFullCharge: 120       // km annoncés à pleine charge
    property bool charging: false
    property string driveGear: "P"          // P / R / N / D
    property bool systemReady: true

    readonly property real batteryFraction: batteryLevel / 100

    // L'autonomie se calcule sur l'énergie restante et la consommation
    // constatée, pas sur un pourcentage multiplié par une constante : rouler
    // plus vite doit la faire baisser plus vite, sinon le chiffre ment.
    readonly property int range: consumption > 0.1
        ? Math.round(batteryFraction * batteryCapacity / consumption * 100)
        : 0

    // ---- Démarrage --------------------------------------------------------
    // Contrôles joués par la séquence de démarrage, dans cet ordre. L'écran ne
    // fait que les afficher : quand le backend existera, il remplacera `ok` par
    // le résultat réel du diagnostic, et un `false` s'affichera en rouge sans
    // qu'une ligne d'interface change.
    property var startupChecks: [
        { label: "Batterie", ok: true },
        { label: "Connexion véhicule", ok: true },
        { label: "Frein de stationnement", ok: true },
        { label: "Portes", ok: true },
        { label: "Capteurs", ok: true },
        { label: "ADAS", ok: true },
        { label: "GPS", ok: true },
        { label: "Réseau", ok: true },
        { label: "Système multimédia", ok: true }
    ]

    // ---- Chaîne haute tension ----------------------------------------------
    // Verrou de sécurité contrôlé au démarrage, avant tout le reste. Sur un
    // véhicule électrique, ces cinq organes conditionnent la mise sous tension :
    // tant qu'ils ne répondent pas tous, le véhicule ne doit pas rouler.
    //
    // `fault` vaut 0 (conforme) ou 1 (en défaut) — c'est la convention des bits
    // de défaut d'un bus véhicule, et c'est ce que la source écrit ici.
    //
    // `blocking` distingue ce qui interdit de rouler de ce qui se signale. Le
    // défaut d'isolement en fait partie : un circuit haute tension en contact
    // avec la caisse met le châssis sous tension, donc les passagers. Ce n'est
    // pas un voyant à ignorer, c'est un refus de démarrage.
    property var hvChain: [
        { id: "isolation", label: "NON-Contact Châssis — Circuit HT",
          detail: "Isolement entre le circuit haute tension et la caisse",
          icon: "ph-lightning", fault: 0, blocking: true },
        { id: "pack", label: "Batterie de traction",
          detail: "Pack, contacteurs de puissance et précharge",
          icon: "ph-car-battery", fault: 0, blocking: false },
        { id: "bms", label: "BMS",
          detail: "Gestion des cellules, équilibrage et température",
          icon: "ph-chart-bar", fault: 0, blocking: false },
        { id: "obc", label: "OBC",
          detail: "Chargeur embarqué et liaison au réseau",
          icon: "ph-battery-charging", fault: 0, blocking: false },
        { id: "motor", label: "Moteur",
          detail: "Onduleur, machine de traction et capteur de position",
          icon: "ph-gauge", fault: 0, blocking: false }
    ]

    readonly property var hvFaults: hvChain.filter(function (e) { return e.fault === 1 })
    readonly property bool hvFaultPresent: hvFaults.length > 0

    // Vrai dès qu'un défaut interdit de rouler. C'est la seule condition qui
    // rend l'écran de diagnostic incontournable.
    readonly property bool hvBlocking:
        hvFaults.some(function (e) { return e.blocking })

    // Positionne le bit de défaut d'un organe. Réassignation obligatoire :
    // muter le tableau en place ne notifie personne.
    function setHvFault(id, faulty) {
        var next = []
        for (var i = 0; i < hvChain.length; i++) {
            var e = hvChain[i]
            next.push({ id: e.id, label: e.label, detail: e.detail, icon: e.icon,
                        fault: e.id === id ? (faulty ? 1 : 0) : e.fault,
                        blocking: e.blocking })
        }
        hvChain = next
    }

    // ---- Ouvrants et accès -------------------------------------------------
    // Une navette à flancs ouverts : pas de coffre ni de quatre portières, mais
    // des accès passagers latéraux, un capot, une trappe de charge et un
    // compartiment batterie.
    property var openings: [
        { label: "Porte conducteur", icon: "ph-car-profile", open: false },
        { label: "Accès passagers G", icon: "ph-arrows-out-line-horizontal", open: true },
        { label: "Accès passagers D", icon: "ph-arrows-out-line-horizontal", open: true },
        { label: "Capot", icon: "ph-car-simple", open: false },
        { label: "Trappe de charge", icon: "ph-lightning", open: false },
        { label: "Compartiment batterie", icon: "ph-car-battery", open: false }
    ]

    // ---- Pneus -------------------------------------------------------------
    property real tyreFrontLeft: 2.5        // bar
    property real tyreFrontRight: 2.5
    property real tyreRearLeft: 2.6
    property real tyreRearRight: 2.6
    property real tyreRecommended: 2.5

    // ---- Températures ------------------------------------------------------
    property int motorTemp: 90              // °C
    property int batteryTemp: 28
    property int cabinTemp: 22

    // ---- Énergie détaillée -------------------------------------------------
    property real power: 12.5               // kW appelés à l'instant
    property real regenPower: 3.2           // kW récupérés
    property string chargeStatus: "Non branché"
    property int chargeCycles: 214
    property string commissioningDate: "12 MARS 2026"

    // ---- Usure / entretien détaillé ----------------------------------------
    // Ces relevés étaient écrits en dur dans deux écrans à la fois, avec des
    // valeurs qui avaient déjà divergé. Une seule source les réconcilie.
    property int brakePadFront: 92          // % restants
    property int brakePadRear: 88
    property string brakeFluid: "OK"
    property string washerFluid: "OK"
    property string lastInspection: "Aujourd'hui 08:42"
    property var serviceHistory: [
        { date: "15/03/2026", label: "Contrôle général" },
        { date: "12/01/2026", label: "Pneus" },
        { date: "20/09/2025", label: "Révision" }
    ]

    // ---- Compteurs / entretien ------------------------------------------
    property int odometer: 12458            // km
    property int serviceDueIn: 12000        // km avant la prochaine révision
    property string serviceDueDate: "15 SEPT. 2026"
    property bool faultPresent: false

    // ---- Environnement / réglementaire ----------------------------------
    property int outsideTemp: 23            // °C
    property int speedLimit: 50             // km/h — limite en vigueur
    property int cruiseSpeed: 50            // km/h — consigne du régulateur
    property bool headlightsAuto: true

    // ---- Témoins ---------------------------------------------------------
    // Ces états décrivent une réalité physique et doivent rester cohérents
    // entre eux : un véhicule ne roule pas frein de stationnement serré.
    // C'est la source qui les tient à jour, ce ne sont pas des constantes.
    property bool seatbeltFastened: true
    property bool parkingBrake: true
    property string driveMode: "ECO"        // ECO / NORMAL / SPORT / COMFORT

    readonly property bool moving: speed > 0.5

    // Ceinture : l'alerte n'a de sens qu'en roulant.
    readonly property bool seatbeltWarning: moving && !seatbeltFastened

    // Pression : déduite des quatre relevés, jamais posée à la main. Un écart
    // de plus de 0,3 bar à la consigne déclenche le témoin — c'est ce que
    // l'écran Véhicule affiche déjà, les deux ne peuvent plus se contredire.
    readonly property bool tyrePressureWarning:
        Math.abs(tyreFrontLeft - tyreRecommended) > 0.3
        || Math.abs(tyreFrontRight - tyreRecommended) > 0.3
        || Math.abs(tyreRearLeft - tyreRecommended) > 0.3
        || Math.abs(tyreRearRight - tyreRecommended) > 0.3

    // ---- Connectivité -----------------------------------------------------
    property string network: "4G"
    property bool wifiConnected: true
    property bool bluetoothConnected: true

    // ---- Navigation -------------------------------------------------------
    property bool navigationActive: true
    property real nextManeuverDistance: 1.2         // km
    property string nextManeuverStreet: "Avenue des Champs-Élysées"
    property string nextManeuverIcon: "ph-arrow-bend-up-right"
    property string followingStreet: "Boulevard Périphérique"
    property real routeProgress: 0.42               // 0..1
    property string arrivalTime: "16:04"
    property real distanceRemaining: 4.2            // km
    property string timeRemaining: "10 min"
    property string trafficCondition: "Fluide"

    // ---- Média ------------------------------------------------------------
    property bool mediaPlaying: true
    property string trackTitle: "Midnight Drive"
    property string trackArtist: "Eclipse"
    property string trackAlbum: "Neon Horizon"

    // ---- Téléphone --------------------------------------------------------
    property int contactCount: 245
    property int recentCallCount: 8
    property int missedCallCount: 2

    // ---- Qualité des signaux ----------------------------------------------
    // Un bus véhicule réel perd des trames, en livre de périmées, ou marque une
    // valeur invalide. Sans cette notion, l'interface affiche la dernière
    // valeur connue comme si elle était fraîche — c'est le mensonge le plus
    // dangereux qu'un tableau de bord puisse faire.
    //
    // "OK"      donnée fraîche et fiable
    // "STALE"   dernière valeur connue, plus rafraîchie
    // "MISSING" capteur absent ou en panne — ne rien inventer
    property var signalState: ({})

    function quality(name) {
        return signalState[name] !== undefined ? signalState[name] : "OK"
    }
    function valid(name) { return quality(name) === "OK" }

    // Met un signal dans un état donné. C'est ce que la source appelle quand
    // une trame manque ; l'interface n'a qu'à lire.
    function setQuality(name, state) {
        var next = signalState
        next[name] = state
        signalState = next          // réassignation : sinon aucune notification
    }

    // Rend une lecture prête à afficher : la valeur, ou un tiret cadratin quand
    // le signal n'est pas exploitable. Aucun écran ne doit formater ça lui-même.
    // Le double tiret est le repère classique des combinés d'instruments pour
    // « pas de valeur ». Un tiret cadratin unique, agrandi à la taille d'un
    // compteur, se lit comme une barre pleine — donc comme un écran en panne.
    readonly property string noValue: "- -"

    function reading(name, value, digits) {
        if (quality(name) === "MISSING")
            return noValue
        return digits !== undefined ? Number(value).toFixed(digits) : String(value)
    }

    // ---- Alertes ------------------------------------------------------------
    // Dérivées de l'état, jamais posées à la main : une alerte qui existe
    // pendant que la condition a disparu est pire que pas d'alerte du tout.
    //
    // level : "CRITICAL" impose une action immédiate — elle interrompt.
    //         "WARNING"  demande une attention — elle s'affiche sans bloquer.
    //         "INFO"     signale, puis s'efface.
    readonly property var activeAlerts: {
        var out = []

        if (moving && parkingBrake)
            out.push({ id: "brake", level: "CRITICAL", icon: "ph-brake-warning",
                       label: "Frein de stationnement serré",
                       detail: "Desserrez le frein avant de rouler." })

        if (seatbeltWarning)
            out.push({ id: "belt", level: "CRITICAL", icon: "ph-seatbelt",
                       label: "Ceinture non bouclée",
                       detail: "Bouclez la ceinture conducteur." })

        // La chaîne haute tension passe avant tout le reste : c'est le seul
        // défaut qui met physiquement les passagers en danger.
        for (var h = 0; h < hvFaults.length; h++) {
            out.push({ id: "hv-" + hvFaults[h].id, level: "CRITICAL",
                       icon: hvFaults[h].icon,
                       label: "Haute tension : " + hvFaults[h].label,
                       detail: hvFaults[h].detail })
        }

        if (faultPresent)
            out.push({ id: "fault", level: "CRITICAL", icon: "ph-brake-warning",
                       label: "Défaut système détecté",
                       detail: "Consultez l'écran Entretien." })

        if (batteryLevel <= 10)
            out.push({ id: "batt", level: "CRITICAL", icon: "ph-battery-high",
                       label: "Batterie critique — " + batteryLevel + " %",
                       detail: "Autonomie restante " + range + " km." })
        else if (batteryLevel <= 20)
            out.push({ id: "batt", level: "WARNING", icon: "ph-battery-high",
                       label: "Batterie faible — " + batteryLevel + " %",
                       detail: "Autonomie restante " + range + " km." })

        if (tyrePressureWarning)
            out.push({ id: "tyre", level: "WARNING", icon: "ph-tire",
                       label: "Pression des pneus",
                       detail: "Un pneu s'écarte de la consigne." })

        if (moving && speed > speedLimit + 5)
            out.push({ id: "limit", level: "WARNING", icon: "ph-gauge",
                       label: "Limite dépassée — " + speedLimit + " km/h",
                       detail: "Vitesse actuelle " + Math.round(speed) + " km/h." })

        // Un capteur muet se dit, il ne se cache pas.
        var names = Object.keys(signalState)
        for (var i = 0; i < names.length; i++) {
            if (signalState[names[i]] === "MISSING")
                out.push({ id: "sig-" + names[i], level: "WARNING", icon: "ph-crosshair-simple",
                           label: "Signal indisponible : " + names[i],
                           detail: "La valeur affichée n'est pas fiable." })
        }

        if (moving && openings.some(function (o) { return o.open && o.label.indexOf("Accès") !== 0 }))
            out.push({ id: "door", level: "WARNING", icon: "ph-car-profile",
                       label: "Ouvrant non fermé",
                       detail: "Vérifiez les ouvrants avant de rouler." })

        return out
    }

    readonly property var topAlert: activeAlerts.length > 0 ? activeAlerts[0] : null
    readonly property bool hasCriticalAlert:
        activeAlerts.some(function (a) { return a.level === "CRITICAL" })
}

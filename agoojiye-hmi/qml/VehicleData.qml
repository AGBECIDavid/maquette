pragma Singleton
import QtQuick

// =============================================================================
//  POINT DE BRANCHEMENT BACKEND
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
//  `demoMode` fait varier quelques valeurs pour que la démo soit vivante sans
//  backend. Le passer à false fige tout sur les valeurs ci-dessous.
// =============================================================================

QtObject {
    id: root

    // Anime légèrement les valeurs simulées. À couper dès que le backend pilote.
    property bool demoMode: true

    // ---- Identité véhicule ---------------------------------------------
    property string vehicleName: "AGOOJIYE"
    property string vehicleModel: "Navette électrique"
    property string vin: "VR3A1ZK87P1234567"
    property string softwareVersion: "1.0.0"
    property string uiVersion: "1.0.0"
    property string storageUsed: "28.4 GB / 64 GB"

    // ---- Propulsion / énergie -------------------------------------------
    property real speed: 25                 // km/h — vitesse instantanée
    property int batteryLevel: 82           // %
    property real consumption: 11.4         // kWh/100 km
    property int rangeFullCharge: 120       // km d'autonomie à pleine charge
    property bool charging: false
    property string driveGear: "D"          // P / R / N / D
    property bool systemReady: true

    readonly property real batteryFraction: batteryLevel / 100
    readonly property int range: Math.round(batteryFraction * rangeFullCharge)

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

    // ---- Compteurs / entretien ------------------------------------------
    property int odometer: 12458            // km
    property int serviceDueIn: 12000        // km avant la prochaine révision
    property string serviceDueDate: "15 SEPT. 2026"
    property bool faultPresent: false

    // ---- Environnement / réglementaire ----------------------------------
    property int outsideTemp: 23            // °C
    property int speedLimit: 30             // km/h — limite en vigueur
    property int cruiseSpeed: 25            // km/h — consigne du régulateur
    property bool headlightsAuto: true

    // ---- Témoins ---------------------------------------------------------
    property bool seatbeltWarning: true
    property bool parkingBrake: true
    property bool tyrePressureWarning: true
    property string driveMode: "ECO"        // ECO / NORMAL / SPORT / COMFORT

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
    property string trackTitle: "Better Tomorrow"
    property string trackArtist: "Kendrick Lamar"
    property string trackAlbum: "Mr. Morale & The Big Steppers"
    property int volume: 18

    // ---- Téléphone --------------------------------------------------------
    property int contactCount: 245
    property int recentCallCount: 8
    property int missedCallCount: 2

    // ---- Simulation -------------------------------------------------------
    // Fait respirer la vitesse et décroître la batterie, uniquement pour la
    // démo. Sans effet dès que `demoMode` est false.
    property Timer _sim: Timer {
        interval: 1800
        running: root.demoMode
        repeat: true
        property int tick: 0
        onTriggered: {
            tick++
            // Vitesse : oscillation douce autour de la vitesse de croisière.
            root.speed = Math.max(0, Math.round(
                root.cruiseSpeed + Math.sin(tick / 3) * 4))
            // Batterie : un point toutes les ~30 s, et on reboucle.
            if (tick % 16 === 0)
                root.batteryLevel = root.batteryLevel > 15
                                    ? root.batteryLevel - 1 : 82
        }
    }
}

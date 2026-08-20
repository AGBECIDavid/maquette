pragma Singleton
import QtQuick
import AgoojiyeHMI

// État de l'interface : quel écran est ouvert, quelles options l'utilisateur a
// basculées. Rien de métier ici — les valeurs du véhicule vivent dans
// VehicleData, qui est le point de branchement du backend.
QtObject {
    id: root

    // ---- navigation entre écrans ---------------------------------------
    property string screen: "accueil"
    property string time: Qt.formatTime(new Date(), "HH:mm")

    // ---- préférences pilotées depuis l'interface ------------------------
    property bool spatial: true
    property bool autoTime: true
    property string regen: "Moyenne"
    property string dir: "Standard"
    property string trac: "Standard"
    property var adas: ({ acc: true, lka: true, ldw: true, fcw: true, aeb: true, bsd: true })

    property Timer _clock: Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.time = Qt.formatTime(new Date(), "HH:mm")
    }

    // ---- actions --------------------------------------------------------
    function go(screenKey) { screen = screenKey }
    function togglePlay() { VehicleData.mediaPlaying = !VehicleData.mediaPlaying }
    function toggleSpatial() { spatial = !spatial }
    function toggleAutoTime() { autoTime = !autoTime }
    function toggleAdas(key) {
        var a = adas
        a[key] = !a[key]
        adas = a
    }
    // Le mode de conduite est un état du véhicule, pas de l'écran : il est
    // poussé vers VehicleData pour que le backend le voie.
    function setDriveMode(key) { VehicleData.driveMode = key.toUpperCase() }
    function setRegen(v) { regen = v }
    function setDir(v) { dir = v }
    function setTrac(v) { trac = v }

    // ---- dérivé ------------------------------------------------------
    readonly property bool showNavBar: screen !== "dash"

    readonly property var navItems: {
        var s = screen
        var accentByScreen = { veh: Theme.green, adas: Theme.green, conduite: Theme.green, mediaNow: Theme.purple }
        var acc = accentByScreen[s] || Theme.blue
        var activeKeyMap = {
            accueil: "dash", dash: "dash", veh: "veh", nav: "nav", media: "media", mediaNow: "media",
            menu: "menu", phone: "menu", adas: "menu", conduite: "menu", entretien: "menu", parametres: "menu"
        }
        var activeKey = activeKeyMap[s]
        var defs = [
            { key: "dash", label: s === "accueil" ? "Accueil" : "Dashboard", icon: s === "accueil" ? "ph-house-simple" : "ph-gauge" },
            { key: "veh", label: "Véhicule", icon: "ph-car-simple" },
            { key: "nav", label: "Navigation", icon: "ph-navigation-arrow" },
            { key: "media", label: "Média", icon: "ph-music-notes" },
            { key: "menu", label: "Menu", icon: "ph-squares-four" }
        ]
        var out = []
        for (var i = 0; i < defs.length; i++) {
            var n = defs[i]
            var a = n.key === activeKey
            out.push({ key: n.key, label: n.label, icon: n.icon, active: a, accent: a ? acc : Theme.textMuted })
        }
        return out
    }
}

pragma Singleton
import QtQuick
import AgoojiyeHMI

// État de l'interface : quel écran est ouvert, quelles options l'utilisateur a
// basculées. Rien de métier ici — les valeurs du véhicule vivent dans
// VehicleData, qui est le point de branchement du backend.
QtObject {
    id: root

    // ---- navigation entre écrans ---------------------------------------
    // Trois niveaux, et un seul sens de circulation :
    //
    //   1. démarrage        — une couche jouée une fois, à la mise en route du
    //                         véhicule. Ce n'est délibérément pas un écran :
    //                         elle n'a pas de clé de navigation, donc aucun
    //                         bouton de l'interface ne peut y ramener.
    //   2. accueil  "dash"  — le tableau de bord, écran de référence.
    //   3. applications     — les autres écrans, tous atteignables depuis la
    //                         barre du bas sans repasser par l'accueil.
    property string screen: "dash"
    property string time: Qt.formatTime(new Date(), "HH:mm")

    // ---- séquence de démarrage -------------------------------------------
    // `booting` masque la coque (barres + écrans) ; `bootPlaying` maintient la
    // couche d'animation montée. Les deux se lèvent séparément pour que le
    // tableau de bord monte pendant que la séquence s'efface.
    property bool booting: true
    property bool bootPlaying: true

    // Écran quitté juste avant l'actuel, pour le retour des sous-écrans
    // (lecteur média, téléphone, entretien…).
    property string previousScreen: "dash"

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
    // Seul point d'entrée de la navigation, et il ne connaît que des écrans :
    // la séquence de démarrage lui est inaccessible par construction.
    function go(screenKey) {
        if (screenKey === screen)
            return
        previousScreen = screen
        screen = screenKey
    }

    // Retour depuis un sous-écran vers celui d'où l'on vient.
    function back() { go(previousScreen) }

    // La séquence rend la main : la coque se révèle…
    function bootReveal() { booting = false }
    // …puis la couche d'animation se retire une fois son fondu terminé.
    function bootDone() { bootPlaying = false }
    // Raccourci (bouton « Passer », captures de développement).
    function skipBoot() { booting = false; bootPlaying = false }
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
    // Seule la séquence de démarrage prend l'écran entier. Partout ailleurs la
    // barre du haut et la barre du bas restent en place : le conducteur ne perd
    // jamais ses repères, et une destination est toujours à un seul appui.
    readonly property bool showNavBar: !booting
    readonly property bool showStatusBar: !booting

    // Les sept destinations de la barre du bas. Chacune est une section : les
    // écrans secondaires qu'elle contient gardent son bouton allumé, pour que
    // l'utilisateur sache toujours où il se trouve.
    readonly property var navSections: [
        { key: "dash", label: "Accueil", icon: "ph-house-simple", screens: ["dash"] },
        { key: "nav", label: "Navigation", icon: "ph-navigation-arrow", screens: ["nav"] },
        { key: "veh", label: "Véhicule", icon: "ph-car-simple", screens: ["veh", "entretien"] },
        { key: "conduite", label: "Conduite", icon: "ph-steering-wheel", screens: ["conduite"] },
        { key: "adas", label: "ADAS", icon: "ph-shield-check", screens: ["adas"] },
        { key: "media", label: "Média", icon: "ph-music-notes", screens: ["media", "mediaNow"] },
        { key: "parametres", label: "Paramètres", icon: "ph-gear-six", screens: ["parametres"] }
    ]

    // Section à laquelle appartient l'écran courant, "" pour le menu.
    readonly property string activeSection: {
        for (var i = 0; i < navSections.length; i++)
            if (navSections[i].screens.indexOf(screen) !== -1)
                return navSections[i].key
        return ""
    }

    // Le menu (toutes les applications) n'occupe pas un des sept boutons : il
    // s'ouvre depuis la barre du haut, comme un tiroir.
    readonly property bool menuOpen: screen === "menu"

    readonly property var navItems: {
        var accentByScreen = { veh: Theme.green, adas: Theme.green, conduite: Theme.green, mediaNow: Theme.purple }
        var acc = accentByScreen[screen] || Theme.blue
        var active = activeSection
        var out = []
        for (var i = 0; i < navSections.length; i++) {
            var n = navSections[i]
            var a = n.key === active
            out.push({ key: n.key, label: n.label, icon: n.icon, active: a, accent: a ? acc : Theme.textMuted })
        }
        return out
    }
}

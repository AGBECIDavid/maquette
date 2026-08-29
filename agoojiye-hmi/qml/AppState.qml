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

    // Couche de diagnostic haute tension. Posée par la séquence de démarrage
    // quand la chaîne HT refuse la mise en route, retirée seulement par une
    // action explicite du conducteur — et jamais tant qu'un défaut interdit de
    // rouler.
    property bool hvDiagnosticOpen: false

    // Écran quitté juste avant l'actuel, pour le retour des sous-écrans
    // (lecteur média, téléphone, entretien…).
    property string previousScreen: "dash"

    // ---- sections des barres latérales -----------------------------------
    // Un index par écran, gardé en mémoire : partir ailleurs et revenir retombe
    // sur la section qu'on avait ouverte, pas sur la première.
    property var sections: ({ veh: 0, conduite: 0, adas: 0, media: 0, mediaNow: 0, parametres: 0 })

    // ---- préférences pilotées depuis l'interface ------------------------
    // Réglages d'usage, pas des mesures du véhicule : ils appartiennent à
    // l'interface et non à VehicleData.
    property bool spatial: true
    property bool autoTime: true
    property string regen: "Moyenne"
    property string dir: "Standard"
    property string trac: "Standard"
    property var adas: ({ acc: true, lka: true, ldw: true, fcw: true, aeb: true, bsd: true })

    // affichage
    property real brightness: 0.72
    property bool autoBrightness: true
    property string uiTheme: "Sombre"
    property bool nightMode: false
    property string textSize: "Normal"
    property string screenTimeout: "Jamais"

    // son
    property real mediaVolume: 0.62
    property real ringVolume: 0.45
    property string balance: "Centré"
    property bool alertSounds: true
    property bool reverseBeep: true
    property bool voiceGuidance: true

    // véhicule
    property bool autoLock: true
    property bool welcomeLighting: true
    property bool foldingMirrors: false
    property string pressureUnit: "bar"

    // conduite / ADAS (panneaux détaillés)
    property string brakeFeel: "Standard"
    property string suspension: "Confort"
    property bool onePedal: true
    property bool hillHold: true
    property int accGap: 2
    property bool parkSensors: true
    property bool rearCamera: true
    property bool autoPark: false
    property bool driverAlert: true
    property int driverAlertLevel: 1

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

    // Section ouverte dans la barre latérale d'un écran.
    function section(screenKey) {
        return sections[screenKey] !== undefined ? sections[screenKey] : 0
    }
    function selectSection(screenKey, index) {
        var next = sections
        next[screenKey] = index
        // Réassignation obligatoire : muter l'objet en place ne déclenche
        // aucune notification, donc rien ne se rafraîchirait.
        sections = next
    }

    // La séquence rend la main : la coque se révèle…
    function bootReveal() { booting = false }
    // …puis la couche d'animation se retire une fois son fondu terminé.
    function bootDone() { bootPlaying = false }
    // Raccourci (bouton « Passer », captures de développement).
    function skipBoot() { booting = false; bootPlaying = false }

    // La chaîne haute tension a refusé : la coque reste masquée derrière le
    // diagnostic, et le démarrage ne s'achève pas.
    function openHvDiagnostic() {
        bootPlaying = false
        hvDiagnosticOpen = true
    }

    // Sortie du diagnostic. Un défaut bloquant ne se contourne pas : la
    // vérification est ici, pas dans l'écran, pour qu'aucun autre appelant ne
    // puisse la sauter.
    function dismissHvDiagnostic() {
        if (VehicleData.hvBlocking)
            return
        hvDiagnosticOpen = false
        booting = false
    }
    function togglePlay() { VehicleData.mediaPlaying = !VehicleData.mediaPlaying }
    function toggleSpatial() { spatial = !spatial }
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

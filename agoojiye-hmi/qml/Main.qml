import QtQuick
import QtQuick.Window
import AgoojiyeHMI

Window {
    id: appWindow
    visible: true
    width: 1600
    height: 900
    color: "#01030a"
    title: "AGOOJIYE HMI"

    Rectangle {
        id: frame
        anchors.fill: parent
        radius: 30
        color: "#02040a"
        border.width: 1
        border.color: Theme.frameBorder
        clip: true

        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.frameBgTop }
            GradientStop { position: 0.55; color: Theme.frameBgMid }
            GradientStop { position: 1.0; color: Theme.frameBgBottom }
        }

        // Les deux barres se déploient au lieu d'apparaître d'un coup : la
        // sortie de la séquence de démarrage devient un enchaînement et non une
        // coupure. Leur hauteur animée pilote celle de la zone de contenu, donc
        // tout glisse ensemble.
        Column {
            anchors.fill: parent

            StatusBar {
                id: statusBar
                width: parent.width
                height: AppState.showStatusBar ? 66 : 0
                opacity: AppState.showStatusBar ? 1 : 0
                visible: height > 0
                Behavior on height { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
            }

            Item {
                id: content
                width: parent.width
                height: parent.height - statusBar.height - bottomNav.height

                // Les écrans entrent en fondu et en léger glissement vers le
                // haut quand la séquence de démarrage rend la main.
                Item {
                    id: screens
                    width: parent.width
                    height: parent.height
                    opacity: AppState.booting ? 0 : 1
                    y: AppState.booting ? 30 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: 620; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutCubic } }

                    DashboardScreen { anchors.fill: parent; visible: AppState.screen === "dash" }
                    MenuScreen { anchors.fill: parent; visible: AppState.screen === "menu" }
                    VehiculeScreen { anchors.fill: parent; visible: AppState.screen === "veh" }
                    NavigationScreen { anchors.fill: parent; visible: AppState.screen === "nav" }
                    MediaScreen { anchors.fill: parent; visible: AppState.screen === "media" }
                    MediaNowScreen { anchors.fill: parent; visible: AppState.screen === "mediaNow" }
                    AdasScreen { anchors.fill: parent; visible: AppState.screen === "adas" }
                    ConduiteScreen { anchors.fill: parent; visible: AppState.screen === "conduite" }
                    PhoneScreen { anchors.fill: parent; visible: AppState.screen === "phone" }
                    EntretienScreen { anchors.fill: parent; visible: AppState.screen === "entretien" }
                    SettingsScreen { anchors.fill: parent; visible: AppState.screen === "parametres" }
                }
            }

            BottomNav {
                id: bottomNav
                width: parent.width
                height: AppState.showNavBar ? 78 : 0
                opacity: AppState.showNavBar ? 1 : 0
                visible: height > 0
                Behavior on height { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 520; easing.type: Easing.OutCubic } }
            }
        }

        // La séquence de démarrage n'est pas un écran mais une couche, posée
        // par-dessus toute l'application et retirée une fois jouée. Elle est
        // hors de la colonne pour garder sa taille pleine pendant que les
        // barres se déploient derrière elle.
        Loader {
            id: bootLayer
            anchors.fill: parent
            z: 5
            active: AppState.bootPlaying
            sourceComponent: BootScreen {
                // La coque se révèle d'abord, le fondu de la séquence
                // se joue par-dessus : les deux se croisent.
                onHandoff: AppState.bootReveal()
                onFinished: AppState.bootDone()
            }
        }

        // Sits above the screens purely as a depth cue — never interactive.
        Vignette {
            anchors.fill: parent
            z: 10
            strength: 0.40
        }
    }
}

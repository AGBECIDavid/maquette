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

        Column {
            anchors.fill: parent

            StatusBar {
                width: parent.width
            }

            Item {
                id: content
                width: parent.width
                height: parent.height - 66 - (AppState.showNavBar ? bottomNav.height : 0)

                AccueilScreen { anchors.fill: parent; visible: AppState.screen === "accueil" }
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

            BottomNav {
                id: bottomNav
                width: parent.width
                visible: AppState.showNavBar
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

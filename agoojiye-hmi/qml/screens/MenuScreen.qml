import QtQuick
import AgoojiyeHMI

Item {
    id: root

    // Toutes les pastilles partagent l'accent de marque : le menu se lit d'un
    // coup d'œil, et la couleur reste porteuse de sens ailleurs (vert = OK,
    // rouge = alerte) au lieu d'être décorative ici.
    //
    // `badge` est une info vivante lue depuis VehicleData — c'est ce qui rendra
    // le menu utile une fois le backend branché.
    readonly property var menuAll: [
        { label: "VÉHICULE", icon: "ph-car-simple", sub: "État du véhicule et informations", go: "veh",
          badge: VehicleData.faultPresent ? "Défaut" : "", alert: true },
        { label: "NAVIGATION", icon: "ph-navigation-arrow", sub: "Carte, itinéraire et guidage", go: "nav",
          badge: VehicleData.navigationActive ? "En cours" : "", alert: false },
        { label: "MÉDIA", icon: "ph-music-notes", sub: "Musique, radio et audio", go: "media",
          badge: VehicleData.mediaPlaying ? "Lecture" : "", alert: false },
        { label: "TÉLÉPHONE", icon: "ph-phone", sub: "Appels, contacts et Bluetooth", go: "phone",
          badge: VehicleData.missedCallCount > 0 ? String(VehicleData.missedCallCount) : "", alert: true },
        { label: "CONDUITE", icon: "ph-steering-wheel", sub: "Modes de conduite et réglages", go: "conduite",
          badge: VehicleData.driveMode, alert: false },
        { label: "ADAS", icon: "ph-shield-check", sub: "Aides à la conduite et sécurité", go: "adas",
          badge: "", alert: false },
        { label: "ENTRETIEN", icon: "ph-wrench", sub: "Maintenance et diagnostics", go: "entretien",
          badge: VehicleData.serviceDueIn < 2000 ? "Bientôt" : "", alert: true },
        { label: "PARAMÈTRES", icon: "ph-gear-six", sub: "Réglages système et préférences", go: "parametres",
          badge: "", alert: false },
        { label: "À PROPOS", icon: "ph-info", sub: "Informations système et version", go: "parametres",
          badge: "", alert: false }
    ]

    Column {
        anchors.fill: parent
        anchors.margins: 0
        anchors.topMargin: 26
        anchors.bottomMargin: 26
        anchors.leftMargin: 56
        anchors.rightMargin: 56
        spacing: 24

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "MENU"; font.family: Theme.fontFamily; font.pixelSize: 32; font.weight: Font.Bold; font.letterSpacing: 2; color: Theme.textPrimary }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 44; height: 3; radius: 2; color: Theme.blue }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Sélectionnez une fonction"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.textMuted; topPadding: 2 }
        }

        Grid {
            width: parent.width
            columns: 5
            columnSpacing: 16
            rowSpacing: 16
            Repeater {
                model: root.menuAll.slice(0, 5)
                delegate: MenuTile {
                    width: (parent.width - 16 * 4) / 5
                    height: 190
                    iconName: modelData.icon; label: modelData.label; sub: modelData.sub
                    accentColor: Theme.blue
                    badge: modelData.badge; badgeAlert: modelData.alert
                    onClicked: AppState.go(modelData.go)
                }
            }
        }

        Grid {
            width: parent.width - 180
            anchors.horizontalCenter: parent.horizontalCenter
            columns: 4
            columnSpacing: 16
            rowSpacing: 16
            Repeater {
                model: root.menuAll.slice(5)
                delegate: MenuTile {
                    width: (parent.width - 16 * 3) / 4
                    height: 190
                    iconName: modelData.icon; label: modelData.label; sub: modelData.sub
                    accentColor: Theme.blue
                    badge: modelData.badge; badgeAlert: modelData.alert
                    onClicked: AppState.go(modelData.go)
                }
            }
        }
    }
}

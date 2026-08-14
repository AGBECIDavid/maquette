import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property var menuAll: [
        { label: "VÉHICULE", icon: "ph-car-simple", c: Theme.green, sub: "État du véhicule et informations", go: "veh" },
        { label: "NAVIGATION", icon: "ph-navigation-arrow", c: Theme.blue, sub: "Carte, itinéraire et guidage", go: "nav" },
        { label: "MÉDIA", icon: "ph-music-notes", c: Theme.purple, sub: "Musique, radio et audio", go: "media" },
        { label: "TÉLÉPHONE", icon: "ph-phone", c: Theme.green, sub: "Appels, contacts et Bluetooth", go: "phone" },
        { label: "CONDUITE", icon: "ph-steering-wheel", c: Theme.orange, sub: "Modes de conduite et réglages", go: "conduite" },
        { label: "ADAS", icon: "ph-shield-check", c: Theme.blue, sub: "Aides à la conduite et sécurité", go: "adas" },
        { label: "ENTRETIEN", icon: "ph-wrench", c: Theme.yellow, sub: "Maintenance et diagnostics", go: "entretien" },
        { label: "PARAMÈTRES", icon: "ph-gear-six", c: Theme.teal, sub: "Réglages système et préférences", go: "parametres" },
        { label: "À PROPOS", icon: "ph-info", c: Theme.red, sub: "Informations système et version", go: "parametres" }
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
                    iconName: modelData.icon; label: modelData.label; sub: modelData.sub; accentColor: modelData.c
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
                    iconName: modelData.icon; label: modelData.label; sub: modelData.sub; accentColor: modelData.c
                    onClicked: AppState.go(modelData.go)
                }
            }
        }
    }
}

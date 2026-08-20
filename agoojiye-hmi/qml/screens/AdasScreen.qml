import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property var sideItems: [
        { label: "Aides à la conduite", icon: "ph-road-horizon", active: true },
        { label: "Régulateur de vitesse", icon: "ph-gauge", active: false },
        { label: "Sécurité", icon: "ph-shield-check", active: false },
        { label: "Stationnement", icon: "ph-letter-circle-p", active: false },
        { label: "Vision", icon: "ph-eye", active: false },
        { label: "Alerte conducteur", icon: "ph-coffee", active: false }
    ]
    readonly property var chips: [
        { label: "Voie détectée", icon: "ph-road-horizon", hot: false },
        { label: "Véhicule détecté", icon: "ph-car-simple", hot: true },
        { label: "Distance sûre", icon: "ph-arrows-out-line-horizontal", hot: false },
        { label: "30 km/h — Limite", icon: "ph-gauge", hot: false }
    ]
    readonly property var items: [
        { key: "acc", label: "Régulateur de vitesse adaptatif (ACC)", sub: "Maintient la distance avec le véhicule devant", icon: "ph-gauge" },
        { key: "lka", label: "Aide au maintien dans la voie (LKA)", sub: "Corrige la trajectoire si nécessaire", icon: "ph-road-horizon" },
        { key: "ldw", label: "Alerte de sortie de voie (LDW)", sub: "Alerte en cas de franchissement de ligne", icon: "ph-warning-diamond" },
        { key: "fcw", label: "Alerte collision avant (FCW)", sub: "Alerte en cas de risque de collision", icon: "ph-car-profile" },
        { key: "aeb", label: "Freinage d'urgence automatique (AEB)", sub: "Freine automatiquement si nécessaire", icon: "ph-record" },
        { key: "bsd", label: "Détection des angles morts (BSD)", sub: "Alerte en cas de véhicule dans l'angle mort", icon: "ph-eye" }
    ]

    Row {
        id: layout
        anchors.fill: parent
        anchors.topMargin: 20; anchors.bottomMargin: 20
        anchors.leftMargin: 32; anchors.rightMargin: 32
        spacing: 20

        Column {
            width: 280
            height: layout.height
            spacing: 6
            Row {
                spacing: 14
                bottomPadding: 12
                Rectangle {
                    width: 42; height: 42; radius: 21
                    color: Theme.alpha(Theme.panelBgTop, 0.9)
                    border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.16)
                    Icon { anchors.centerIn: parent; name: "ph-arrow-left"; size: 19; color: Theme.textPrimary }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AppState.go("menu") }
                }
                Text { text: "ADAS"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
            }
            Repeater {
                model: root.sideItems
                delegate: SidebarItem {
                    width: 280
                    iconName: modelData.icon; label: modelData.label; active: modelData.active
                    accentColor: Theme.green; tintColor: Theme.alpha(Theme.green, 0.09)
                }
            }
        }

        Column {
            width: layout.width - 280 - 460 - 40
            height: layout.height
            spacing: 14

            Row {
                spacing: 10
                Text { text: "AIDES À LA CONDUITE"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Icon { name: "ph-info"; size: 19; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
            }
            Row {
                width: parent.width
                spacing: 14
                Repeater {
                    model: root.chips
                    delegate: Rectangle {
                        width: (parent.width - 14 * 3) / 4
                        height: 84
                        radius: 12
                        color: modelData.hot ? Theme.alpha(Theme.green, 0.12) : Theme.alpha(Theme.navBg, 0.7)
                        border.width: 1
                        border.color: modelData.hot ? Theme.green : Theme.alpha(Theme.green, 0.25)
                        Column {
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: modelData.icon; size: 26; color: Theme.green }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 12; color: "#a7e8bd" }
                        }
                    }
                }
            }

            PanelCard {
                width: parent.width
                height: parent.height - 19 - 14 - 84 - 14 - 76 - 14
                radius: 16
                color: "transparent"
                border.color: Theme.alpha(Theme.green, 0.2)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.panelBgTop, 0.6) }
                    GradientStop { position: 1.0; color: Theme.alpha(Theme.panelBgBottom, 0.8) }
                }
                ImageAsset {
                    anchors.fill: parent
                    radius: 16
                    source: "qrc:/AgoojiyeHMI/assets/images/adas-road.png"
                }
            }

            Rectangle {
                width: parent.width
                height: 76
                radius: 14
                color: Theme.alpha(Theme.navBg, 0.9)
                border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.14)
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 20; anchors.rightMargin: 20
                    spacing: 14
                    Icon { name: "ph-check-circle"; fill: true; size: 26; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Système activé"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Text { text: "Les aides à la conduite sont actives et opérationnelles."; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }
                    }
                }
            }
        }

        Column {
            width: 460
            height: layout.height
            spacing: 11
            Text { text: "SYSTÈMES ADAS"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary; topPadding: 8; bottomPadding: 4 }
            Repeater {
                model: root.items
                delegate: PanelCard {
                    width: parent.width
                    height: 68
                    radius: 13
                    border.color: Theme.alpha(Theme.panelBorder, 0.12)
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        spacing: 14
                        Icon {
                            name: modelData.icon; size: 24
                            color: AppState.adas[modelData.key] ? Theme.green : "#5b6579"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            width: parent.width - 24 - 14 - 52 - 14
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary; wrapMode: Text.WordWrap; width: parent.width }
                            Text { text: modelData.sub; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted; wrapMode: Text.WordWrap; width: parent.width }
                        }
                        ToggleSwitch {
                            checked: AppState.adas[modelData.key]
                            accentColor: Theme.green
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: AppState.toggleAdas(modelData.key)
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width
                height: 52
                radius: 13
                color: Theme.alpha(Theme.navBg, 0.9)
                border.width: 1
                border.color: settingsHover.containsMouse ? Theme.alpha(Theme.panelBorder, 0.4) : Theme.alpha(Theme.panelBorder, 0.14)
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 18; anchors.rightMargin: 18
                    Text { text: "Paramètres des alertes"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    Item { width: parent.width - 220; height: 1 }
                    Icon { name: "ph-caret-right"; size: 16; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: settingsHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}

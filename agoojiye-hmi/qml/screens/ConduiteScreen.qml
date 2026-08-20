import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property var sideItems: [
        { label: "Modes de conduite", icon: "ph-car-simple", active: true },
        { label: "Régénération", icon: "ph-lightning", active: false },
        { label: "Traction", icon: "ph-steering-wheel", active: false },
        { label: "Direction", icon: "ph-arrows-left-right", active: false },
        { label: "Suspension", icon: "ph-arrows-vertical", active: false },
        { label: "Freinage", icon: "ph-record", active: false }
    ]
    readonly property var modes: [
        { key: "eco", label: "ECO", icon: "ph-leaf", c: Theme.green, desc: "Optimise l'efficacité énergétique pour maximiser l'autonomie. Idéal pour une conduite économique au quotidien." },
        { key: "normal", label: "NORMAL", icon: "ph-car-simple", c: Theme.blue, desc: "Équilibre entre performance et consommation pour tous les trajets." },
        { key: "sport", label: "SPORT", icon: "ph-flag-checkered", c: Theme.orange, desc: "Réponse immédiate de l'accélérateur et direction plus ferme." },
        { key: "comfort", label: "COMFORT", icon: "ph-armchair", c: Theme.purple, desc: "Souplesse et silence privilégiés pour les longs trajets." }
    ]
    function currentMode() {
        for (var i = 0; i < modes.length; i++) if (modes[i].key.toUpperCase() === VehicleData.driveMode) return modes[i]
        return modes[0]
    }

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
            Text { text: "CONDUITE"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; bottomPadding: 14; topPadding: 6 }
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

            Text { text: "MODE DE CONDUITE"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

            Grid {
                width: parent.width
                columns: 4
                columnSpacing: 12
                Repeater {
                    model: root.modes
                    delegate: Rectangle {
                        readonly property bool active: modelData.key.toUpperCase() === VehicleData.driveMode
                        width: (parent.width - 12 * 3) / 4
                        height: 100
                        radius: 14
                        color: "transparent"
                        border.width: 1
                        border.color: active ? modelData.c : Theme.alpha(Theme.panelBorder, 0.14)
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: active ? Theme.alpha(modelData.c, 0.08) : Theme.panelGradTop }
                            GradientStop { position: 1.0; color: active ? Theme.alpha(modelData.c, 0.08) : Theme.panelGradBottom }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: modelData.icon; size: 30; color: modelData.c }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 1; color: active ? Theme.textPrimary : Theme.textDim }
                            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 34; height: 3; radius: 2; color: active ? modelData.c : "transparent" }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AppState.setDriveMode(modelData.key) }
                    }
                }
            }

            PanelCard {
                width: parent.width
                height: parent.height - 19 - 14 - 100 - 14 - 90 - 14
                radius: 16
                ImageAsset {
                    anchors.fill: parent
                    anchors.margins: 26
                    radius: 16
                    // A transparent cut-out has to be fitted, not cropped, or
                    // the panel zooms into the middle of the vehicle.
                    fillMode: Image.PreserveAspectFit
                    source: "qrc:/AgoojiyeHMI/assets/images/conduite-car.png"
                }
            }

            Column {
                width: parent.width
                spacing: 6
                Row {
                    spacing: 10
                    Icon { name: root.currentMode().icon; size: 22; color: root.currentMode().c; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: root.currentMode().label; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: root.currentMode().c; anchors.verticalCenter: parent.verticalCenter }
                }
                Text { width: parent.width; text: root.currentMode().desc; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textDim; wrapMode: Text.WordWrap; lineHeight: 1.55; lineHeightMode: Text.ProportionalHeight }
                Row {
                    topPadding: 6
                    spacing: 8
                    Repeater {
                        model: root.modes
                        delegate: Rectangle { width: 8; height: 8; radius: 4; color: modelData.key.toUpperCase() === VehicleData.driveMode ? root.currentMode().c : Theme.dotInactive }
                    }
                }
            }
        }

        PanelCard {
            width: 460
            height: layout.height
            radius: 16
            border.color: Theme.alpha(Theme.panelBorder, 0.12)
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.alpha(Theme.panelBgTop, 0.7) }
                GradientStop { position: 1.0; color: Theme.alpha(Theme.panelBgBottom, 0.85) }
            }

            Column {
                x: 22; y: 22
                width: parent.width - 44
                spacing: 22
                Text { text: "PARAMÈTRES DE CONDUITE"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                Column {
                    width: parent.width
                    spacing: 9
                    Text { text: "RÉGÉNÉRATION D'ÉNERGIE"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted }
                    SegmentedControl {
                        width: parent.width
                        options: ["Faible", "Moyenne", "Forte", "Auto"]
                        currentIndex: options.indexOf(AppState.regen)
                        accentColor: Theme.green
                        onSelected: (i) => AppState.setRegen(options[i])
                    }
                }

                Column {
                    width: parent.width
                    spacing: 12
                    Text { text: "RÉPONSE DE L'ACCÉLÉRATEUR"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted }
                    Row {
                        width: parent.width
                        spacing: 14
                        Text { text: "Douce"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: parent.width - 14 * 2 - 46 - 62
                            height: 5; radius: 3; color: "#0d1a2e"
                            anchors.verticalCenter: parent.verticalCenter
                            Rectangle { width: parent.width * 0.62; height: parent.height; radius: 3; color: Theme.green }
                            Rectangle { x: parent.width * 0.62 - 8; y: -5.5; width: 16; height: 16; radius: 8; color: "#4ade80" }
                        }
                        Text { text: "Réactive"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                Column {
                    width: parent.width
                    spacing: 9
                    Text { text: "DIRECTION"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted }
                    SegmentedControl {
                        width: parent.width
                        options: ["Légère", "Standard", "Ferme"]
                        currentIndex: options.indexOf(AppState.dir)
                        accentColor: Theme.green
                        onSelected: (i) => AppState.setDir(options[i])
                    }
                }

                Column {
                    width: parent.width
                    spacing: 9
                    Text { text: "TRACTION"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted }
                    SegmentedControl {
                        width: parent.width
                        options: ["Eco", "Standard", "Sport"]
                        currentIndex: options.indexOf(AppState.trac)
                        accentColor: Theme.green
                        onSelected: (i) => AppState.setTrac(options[i])
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 52
                    radius: 13
                    color: Theme.alpha(Theme.navBg, 0.85)
                    border.width: 1
                    border.color: customHover.containsMouse ? Theme.alpha(Theme.panelBorder, 0.4) : Theme.alpha(Theme.panelBorder, 0.14)
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 18; anchors.rightMargin: 18
                        Text { text: "Personnaliser le mode"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        Item { width: parent.width - 220; height: 1 }
                        Icon { name: "ph-caret-right"; size: 16; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: customHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}

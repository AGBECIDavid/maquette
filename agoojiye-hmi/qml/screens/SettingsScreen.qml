import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property var sideItems: [
        { label: "Général", sub: "Langue, unités, date, heure", icon: "ph-gear-six", c: Theme.blue, active: true },
        { label: "Affichage", sub: "Luminosité, thème, mode", icon: "ph-sun", c: Theme.orange, active: false },
        { label: "Son", sub: "Volume, balance, notifications", icon: "ph-speaker-high", c: Theme.blue, active: false },
        { label: "Véhicule", sub: "Préférences, conduite", icon: "ph-car-simple", c: Theme.textMuted, active: false },
        { label: "Système", sub: "Infos système, mises à jour", icon: "ph-cube", c: Theme.textMuted, active: false }
    ]
    readonly property var genRows: [
        { label: "Langue", val: "Français", icon: "ph-globe-simple", c: Theme.purple, chev: "ph-caret-down" },
        { label: "Unités", val: "Métrique", icon: "ph-ruler", c: Theme.blue, chev: "ph-caret-down" },
        { label: "Heure", val: AppState.time, icon: "ph-clock", c: Theme.orange, chev: "ph-caret-down" },
        { label: "Date", val: "24 / 05 / 2026", icon: "ph-calendar-blank", c: Theme.green, chev: "ph-caret-right" }
    ]
    readonly property var aboutRows: [
        { k: "Nom du système", v: "AGOOJIYE V1" },
        { k: "Version logicielle", v: "1.0.0" },
        { k: "Version UI", v: "1.0.0" },
        { k: "ID du véhicule (VIN)", v: "VR3A1ZK87P1234567" },
        { k: "Espace de stockage", v: "28.4 GB / 64 GB" }
    ]

    Row {
        id: layout
        anchors.fill: parent
        anchors.topMargin: 20; anchors.bottomMargin: 20
        anchors.leftMargin: 32; anchors.rightMargin: 32
        spacing: 22

        Column {
            width: 330
            height: layout.height
            spacing: 10
            Text { text: "PARAMÈTRES"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; bottomPadding: 8; topPadding: 6 }
            Repeater {
                model: root.sideItems
                delegate: Rectangle {
                    width: parent.width; height: 78; radius: 13
                    color: "transparent"
                    border.width: 1
                    border.color: modelData.active ? Theme.blue : Theme.alpha(Theme.panelBorder, 0.14)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: modelData.active ? Theme.alpha(Theme.blue, 0.1) : (settHover.containsMouse ? Theme.alpha(Theme.panelBgTop, 0.95) : Theme.panelGradTop) }
                        GradientStop { position: 1.0; color: modelData.active ? Theme.alpha(Theme.blue, 0.1) : (settHover.containsMouse ? Theme.alpha(Theme.panelBgTop, 0.95) : Theme.panelGradBottom) }
                    }
                    Rectangle { width: 3; height: parent.height; radius: 1.5; color: modelData.active ? Theme.blue : "transparent" }
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        spacing: 15
                        Rectangle {
                            width: 46; height: 46; radius: 23
                            color: Theme.alpha(modelData.c, 0.12)
                            anchors.verticalCenter: parent.verticalCenter
                            Icon { anchors.centerIn: parent; name: modelData.icon; size: 22; color: modelData.c }
                        }
                        Column {
                            width: parent.width - 46 - 15 - 15 - 20
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.textPrimary }
                            Text { text: modelData.sub; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                        }
                        Icon { name: "ph-caret-right"; size: 15; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: settHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                }
            }
        }

        Column {
            width: layout.width - 330 - 400 - 44
            height: layout.height
            spacing: 11
            Text { text: "GÉNÉRAL"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary; topPadding: 8; bottomPadding: 4 }
            Repeater {
                model: root.genRows
                delegate: PanelCard {
                    width: parent.width; height: 60; radius: 13
                    border.color: Theme.alpha(Theme.panelBorder, 0.12)
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 18; anchors.rightMargin: 18
                        spacing: 15
                        Rectangle {
                            width: 42; height: 42; radius: 21
                            color: Theme.alpha(modelData.c, 0.12)
                            anchors.verticalCenter: parent.verticalCenter
                            Icon { anchors.centerIn: parent; name: modelData.icon; size: 20; color: modelData.c }
                        }
                        Text { text: modelData.label; width: parent.width - 42 - 15 - 15 - 120; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.val; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                        Icon { name: modelData.chev; size: 15; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
            PanelCard {
                width: parent.width; height: 66; radius: 13
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 18; anchors.rightMargin: 18
                    spacing: 15
                    Rectangle {
                        width: 42; height: 42; radius: 21
                        color: Theme.alpha(Theme.blue, 0.12)
                        anchors.verticalCenter: parent.verticalCenter
                        Icon { anchors.centerIn: parent; name: "ph-clock-clockwise"; size: 20; color: Theme.blue }
                    }
                    Column {
                        width: parent.width - 42 - 15 - 15 - 52
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Heure automatique"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Medium; color: Theme.textPrimary }
                        Text { text: "Synchroniser l'heure avec le réseau"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                    }
                    ToggleSwitch { checked: AppState.autoTime; accentColor: Theme.blue; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.toggleAutoTime() }
                }
            }
            PanelCard {
                width: parent.width; height: 60; radius: 13
                border.color: Theme.alpha(Theme.panelBorder, 0.12)
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 18; anchors.rightMargin: 18
                    spacing: 15
                    Rectangle {
                        width: 42; height: 42; radius: 21
                        color: Theme.alpha(Theme.purple, 0.12)
                        anchors.verticalCenter: parent.verticalCenter
                        Icon { anchors.centerIn: parent; name: "ph-globe-hemisphere-west"; size: 20; color: Theme.purple }
                    }
                    Text { text: "Fuseau horaire"; width: parent.width - 42 - 15 - 15 - 150; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "GMT+01:00"; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                    Icon { name: "ph-caret-right"; size: 15; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        Column {
            width: 400
            height: layout.height
            spacing: 12
            Text { text: "À PROPOS DU SYSTÈME"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary; topPadding: 8; bottomPadding: 4 }
            ImageAsset {
                width: parent.width; height: 170; radius: 14
                fillMode: Image.PreserveAspectFit
                source: "qrc:/AgoojiyeHMI/assets/images/settings-car.png"
            }
            PanelCard {
                width: parent.width
                height: aboutCol.implicitHeight + 12
                radius: 14
                Column {
                    id: aboutCol
                    x: 18; y: 6
                    width: parent.width - 36
                    Repeater {
                        model: root.aboutRows
                        delegate: Column {
                            width: aboutCol.width
                            Item {
                                width: parent.width
                                height: 45
                                Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: modelData.k; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }
                                Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.v; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium; color: Theme.textPrimary }
                            }
                            Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.textMuted, 0.12) }
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 54; radius: 13
                border.width: 1; border.color: updHover.containsMouse ? Theme.blue : Theme.alpha(Theme.panelBorder, 0.3)
                color: "transparent"
                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Icon { name: "ph-arrows-clockwise"; size: 19; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Vérifier les mises à jour"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: updHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}

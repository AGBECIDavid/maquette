import QtQuick
import AgoojiyeHMI

// Avant le départ : la destination, le point de départ, et jusqu'à trois
// itinéraires à comparer. Rien ne démarre sans « Démarrer ».
PanelCard {
    id: root
    radius: 18
    opaque: true
    height: col.implicitHeight + 40

    readonly property var dest: Navigation.destinationId !== "" ? Navigation.place(Navigation.destinationId) : null
    signal chooseOrigin()
    signal showSteps()

    Column {
        id: col
        x: 20; y: 20
        width: parent.width - 40
        spacing: 16

        // ---- destination ----
        Item {
            width: parent.width
            height: 48
            Rectangle {
                id: destBadge
                width: 46; height: 46; radius: 23
                color: Theme.alpha(Theme.red, 0.18)
                Icon {
                    anchors.centerIn: parent
                    name: root.dest ? root.dest.icon : "ph-map-pin"
                    size: 21; color: Theme.red
                }
            }
            Column {
                anchors.left: destBadge.right
                anchors.leftMargin: 14
                anchors.right: close.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "Vers"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: Navigation.destinationName
                    font.family: Theme.fontFamily; font.pixelSize: 21; font.weight: Font.DemiBold; color: Theme.textPrimary
                }
            }
            Rectangle {
                id: close
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20
                color: closeHover.containsMouse ? Theme.alpha(Theme.textMuted, 0.18) : "transparent"
                Icon { anchors.centerIn: parent; name: "ph-x"; size: 18; color: Theme.textMuted }
                MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Navigation.stop() }
            }
        }

        // ---- départ ----
        Rectangle {
            width: parent.width
            height: 50
            radius: 12
            color: originHover.containsMouse ? Theme.alpha("#ffffff", 0.07) : Theme.alpha("#ffffff", 0.04)
            border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.14)
            Row {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Icon {
                    name: Navigation.originId === "" ? "ph-navigation-arrow" : "ph-map-pin"
                    fill: true; size: 17; color: Navigation.originId === "" ? Theme.blueLight : Theme.textSecondary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text { text: "Départ :"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Navigation.originName; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
            }
            Icon { anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; name: "ph-caret-right"; size: 16; color: Theme.textMuted }
            MouseArea { id: originHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.chooseOrigin() }
        }

        // ---- erreur ----
        Row {
            visible: Navigation.routeError !== ""
            width: parent.width
            spacing: 10
            Icon { name: "ph-warning"; size: 18; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
            Text {
                width: parent.width - 30
                text: Navigation.routeError
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.orange
            }
        }

        // ---- itinéraires ----
        Column {
            width: parent.width
            spacing: 8
            Repeater {
                model: Navigation.routes
                delegate: Rectangle {
                    readonly property bool sel: index === Navigation.selectedRoute
                    width: parent.width
                    height: 76
                    radius: 14
                    color: sel ? Theme.alpha(Theme.blue, 0.16) : (rHover.containsMouse ? Theme.alpha("#ffffff", 0.05) : "transparent")
                    border.width: 1
                    border.color: sel ? Theme.alpha(Theme.blue, 0.65) : Theme.alpha(Theme.panelBorder, 0.14)

                    Column {
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Row {
                            spacing: 10
                            Text {
                                text: modelData.durationText
                                font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold
                                color: parent.parent.parent.sel ? Theme.blueLighter : Theme.textPrimary
                            }
                            Text {
                                anchors.baseline: parent.children[0].baseline
                                text: modelData.distanceText
                                font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textSecondary
                            }
                        }
                        Text {
                            text: (modelData.via !== "" ? modelData.via + " · " : "") + "arrivée " + modelData.arrival
                            font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted
                        }
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        height: 26; radius: 13
                        width: tag.implicitWidth + 20
                        color: modelData.fastest ? Theme.alpha(Theme.green, 0.16) : Theme.alpha(Theme.textMuted, 0.12)
                        Text {
                            id: tag
                            anchors.centerIn: parent
                            text: modelData.fastest ? "Le plus rapide" : modelData.extra
                            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
                            color: modelData.fastest ? Theme.greenLight : Theme.textSecondary
                        }
                    }
                    MouseArea { id: rHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Navigation.selectRoute(index) }
                }
            }
        }

        // ---- actions ----
        Row {
            width: parent.width
            spacing: 10
            visible: Navigation.routes.length > 0

            Rectangle {
                readonly property bool fromHere: Navigation.originId === ""
                width: parent.width - stepsBtn.width - 10
                height: 54; radius: 14
                color: goHover.containsMouse ? Theme.blueLight : Theme.blue
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Icon { name: parent.parent.fromHere ? "ph-navigation-arrow" : "ph-crosshair-simple"; fill: true; size: 19; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        text: parent.parent.fromHere ? "Démarrer" : "Partir de ma position"
                        font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold; color: "#ffffff"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
                MouseArea {
                    id: goHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    // Un départ choisi sert à prévoir un trajet ; le guidage, lui,
                    // part toujours d'où est la navette.
                    onClicked: parent.fromHere ? Navigation.start() : Navigation.setOrigin("")
                }
            }
            Rectangle {
                id: stepsBtn
                width: 112; height: 54; radius: 14
                color: stHover.containsMouse ? Theme.alpha("#ffffff", 0.1) : Theme.alpha("#ffffff", 0.05)
                border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.22)
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { name: "ph-list"; size: 18; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Étapes"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: stHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showSteps() }
            }
        }
    }
}

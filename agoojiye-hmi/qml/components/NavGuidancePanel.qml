import QtQuick
import AgoojiyeHMI

// Le guidage, posé sur la carte : la prochaine manœuvre en haut à gauche, en
// grand, lisible d'un coup d'œil ; le trajet restant en bas. C'est tout :
// pendant la conduite, l'écran ne montre que ce qui sert maintenant.
Item {
    id: root

    property real rightInset: 100
    signal showSteps()

    readonly property var next: Navigation.nextStep
    readonly property var after: Navigation.thenStep
    readonly property bool arrived: Navigation.state === "arrived"
    readonly property bool positionLost: Navigation.positionState === "lost"

    // ---- prochaine manœuvre --------------------------------------------
    PanelCard {
        id: maneuver
        x: 24; y: 20
        width: 440
        height: mCol.implicitHeight + 40
        radius: 18
        opaque: true
        visible: !root.arrived
        border.color: Theme.alpha(Theme.blue, 0.35)

        Column {
            id: mCol
            x: 20; y: 20
            width: parent.width - 40
            spacing: 14

            Row {
                width: parent.width
                spacing: 18
                Rectangle {
                    width: 76; height: 76; radius: 18
                    color: root.positionLost ? Theme.alpha(Theme.textMuted, 0.25) : Theme.blue
                    Icon {
                        anchors.centerIn: parent
                        name: root.next.icon || "ph-navigation-arrow"
                        fill: true; size: 44; color: "#ffffff"
                    }
                }
                Column {
                    width: parent.width - 94
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text {
                        text: root.positionLost ? "- -" : (root.next.distanceText || "")
                        font.family: Theme.fontFamily; font.pixelSize: 40; font.weight: Font.Bold
                        color: root.positionLost ? Theme.textMuted : Theme.textPrimary
                    }
                    Text {
                        width: parent.width
                        text: root.next.text || ""
                        wrapMode: Text.WordWrap; maximumLineCount: 3; elide: Text.ElideRight
                        font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Medium; color: Theme.textPrimary
                        lineHeight: 1.08
                    }
                }
            }

            // Une seconde consigne qui suit de près : on la montre tout de suite.
            Rectangle {
                visible: root.after.text !== undefined
                width: parent.width
                height: 44; radius: 12
                color: Theme.alpha(Theme.blue, 0.12)
                Row {
                    x: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Text { text: "Puis"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.blueLight; anchors.verticalCenter: parent.verticalCenter }
                    Icon { name: root.after.icon || ""; size: 19; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        width: maneuver.width - 140
                        elide: Text.ElideRight
                        text: root.after.text || ""
                        font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Rectangle {
                visible: Navigation.offRoute
                width: parent.width
                height: 38; radius: 10
                color: Theme.alpha(Theme.orange, 0.15)
                Row {
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Icon { name: "ph-arrows-clockwise"; size: 17; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Hors itinéraire — recalcul…"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }

    // ---- arrivée ---------------------------------------------------------
    PanelCard {
        x: 24; y: 20
        width: 440
        height: aCol.implicitHeight + 44
        radius: 18
        opaque: true
        visible: root.arrived
        border.color: Theme.alpha(Theme.green, 0.4)

        Column {
            id: aCol
            x: 22; y: 22
            width: parent.width - 44
            spacing: 16
            Row {
                spacing: 16
                Rectangle {
                    width: 64; height: 64; radius: 32
                    color: Theme.alpha(Theme.green, 0.2)
                    Icon { anchors.centerIn: parent; name: "ph-flag-checkered"; fill: true; size: 30; color: Theme.greenLight }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Vous êtes arrivé"; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.greenLight }
                    Text {
                        width: 300; elide: Text.ElideRight
                        text: Navigation.destinationName
                        font.family: Theme.fontFamily; font.pixelSize: 23; font.weight: Font.DemiBold; color: Theme.textPrimary
                    }
                    Text {
                        visible: (root.next.side || 0) !== 0
                        text: root.next.side > 0 ? "Sur votre droite" : "Sur votre gauche"
                        font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 52; radius: 14
                color: endHover.containsMouse ? Theme.blueLight : Theme.blue
                Text { anchors.centerIn: parent; text: "Terminer"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold; color: "#ffffff" }
                MouseArea { id: endHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Navigation.stop() }
            }
        }
    }

    // ---- trajet restant --------------------------------------------------
    PanelCard {
        id: bar
        visible: !root.arrived
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.right: parent.right
        anchors.rightMargin: root.rightInset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        height: 84
        radius: 18
        opaque: true

        Row {
            id: stats
            x: 26
            anchors.verticalCenter: parent.verticalCenter
            spacing: 30
            Repeater {
                model: [
                    { v: Navigation.arrivalTime, l: "Arrivée", accent: true },
                    { v: Navigation.formatDuration(Navigation.remainingTime), l: "Temps restant" },
                    { v: Navigation.formatDistance(Navigation.remainingDistance), l: "Distance" }
                ]
                delegate: Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: root.positionLost ? "- -" : modelData.v
                        font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold
                        color: modelData.accent ? Theme.greenLight : Theme.textPrimary
                    }
                    Text { text: modelData.l; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                }
            }
        }

        // Avancement : une barre fine sous les chiffres.
        Rectangle {
            anchors.left: stats.left
            anchors.right: buttons.left
            anchors.rightMargin: 28
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 12
            height: 4; radius: 2
            color: Theme.trackBg
            Rectangle {
                width: parent.width * Navigation.progress
                height: parent.height; radius: 2
                color: Theme.blue
            }
        }

        Row {
            id: buttons
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 52; height: 52; radius: 26
                color: listHover.containsMouse ? Theme.alpha("#ffffff", 0.12) : Theme.alpha("#ffffff", 0.06)
                Icon { anchors.centerIn: parent; name: "ph-list"; size: 21; color: Theme.textPrimary }
                MouseArea { id: listHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showSteps() }
            }
            Rectangle {
                width: 52; height: 52; radius: 26
                color: voiceHover.containsMouse ? Theme.alpha("#ffffff", 0.12) : Theme.alpha("#ffffff", 0.06)
                Icon {
                    anchors.centerIn: parent
                    name: Navigation.voiceGuidance ? "ph-speaker-high" : "ph-speaker-slash"
                    size: 21; color: Navigation.voiceGuidance ? Theme.textPrimary : Theme.orange
                }
                MouseArea { id: voiceHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Navigation.voiceGuidance = !Navigation.voiceGuidance }
            }
            Rectangle {
                width: stopRow.implicitWidth + 40; height: 52; radius: 26
                color: stopHover.containsMouse ? Theme.alpha(Theme.red, 0.3) : Theme.alpha(Theme.red, 0.16)
                border.width: 1; border.color: Theme.alpha(Theme.red, 0.6)
                Row {
                    id: stopRow
                    anchors.centerIn: parent
                    spacing: 8
                    Icon { name: "ph-x"; size: 17; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Arrêter"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: stopHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Navigation.stop() }
            }
        }
    }
}

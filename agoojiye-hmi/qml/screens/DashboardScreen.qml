import QtQuick
import AgoojiyeHMI

Item {
    id: root
    clip: true

    // Ground: a cool pool of light behind the road, darkening to the corners.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#122442" }
            GradientStop { position: 0.55; color: "#070d1a" }
            GradientStop { position: 1.0; color: "#03060d" }
        }
    }

    // Night road scene the cluster is composited over. Feathered on every edge
    // so it reads as part of the scene rather than a pasted photo.
    ImageAsset {
        id: road
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 78
        width: 1200
        height: 470
        // The asset carries its own baked alpha falloff, so it dissolves into
        // whatever is behind it without assuming a backdrop colour.
        source: "qrc:/AgoojiyeHMI/assets/images/dash-road.png"
    }

    // Hold the scene back so the readouts stay the brightest thing on screen.
    Rectangle {
        anchors.fill: road
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.alpha("#080f1d", 0.55) }
            GradientStop { position: 0.45; color: Theme.alpha("#080f1d", 0.18) }
            GradientStop { position: 1.0; color: Theme.alpha("#080f1d", 0.05) }
        }
    }

    // Headlight wash spilling up off the road surface.
    Glow {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 60
        width: 1100; height: 520
        glowColor: Theme.blue
        intensity: 0.10
    }

    // ---- left: energy summary -------------------------------------------
    PanelCard {
        x: 36; y: 36
        width: 300
        height: energyCol.implicitHeight + 48
        radius: 16
        elevated: true

        Column {
            id: energyCol
            x: 24; y: 24
            width: parent.width - 48
            spacing: 20

            Column {
                spacing: 8
                Text { text: "BATTERIE"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.6; color: Theme.textMuted }
                Row {
                    spacing: 12
                    Icon { name: "ph-battery-high"; fill: true; size: 30; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: AppState.batPct + " %"; font.family: Theme.fontFamily; font.pixelSize: 30; font.weight: Font.Bold; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Divider { width: parent.width }
            Column {
                spacing: 6
                Text { text: "AUTONOMIE"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.6; color: Theme.textMuted }
                Row {
                    spacing: 6
                    Text { text: AppState.range; font.family: Theme.fontFamily; font.pixelSize: 28; font.weight: Font.Bold; color: Theme.textPrimary; anchors.baseline: kmLabel.baseline }
                    Text { id: kmLabel; text: "km"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.textMuted }
                }
            }
            Divider { width: parent.width }
            Column {
                spacing: 6
                Text { text: "CONSOMMATION"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.6; color: Theme.textMuted }
                Row {
                    spacing: 6
                    Text { text: "16.8"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; color: Theme.textPrimary; anchors.baseline: kwhLabel.baseline }
                    Text { id: kwhLabel; text: "kWh/100km"; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textMuted }
                }
            }
        }
    }

    // ---- state-of-charge arc --------------------------------------------
    Item {
        id: socGauge
        x: 348
        y: 36
        width: 104
        height: 452

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            text: "100%"
            font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted
        }
        Glow {
            anchors.centerIn: arc
            width: arc.width * 2.4; height: arc.height * 1.05
            glowColor: Theme.green
            intensity: 0.13
        }
        BatteryArc {
            id: arc
            anchors.horizontalCenter: parent.horizontalCenter
            y: 26
            width: 92
            height: parent.height - 52
            value: AppState.batteryFraction
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: "0%"
            font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted
        }
        // Charge marker sitting on the arc's midline, as in the reference art.
        Row {
            anchors.verticalCenter: arc.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: -4
            spacing: 4
            Icon { name: "ph-lightning"; fill: true; size: 19; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 34; height: 1; color: Theme.alpha(Theme.blueLighter, 0.5); anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---- centre: speed ---------------------------------------------------
    Glow {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        width: 760; height: 380
        glowColor: Theme.blue
        intensity: 0.20
    }
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 56
        spacing: 0
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: AppState.speed
            font.family: Theme.fontFamily
            font.pixelSize: 172
            font.weight: Font.Bold
            font.letterSpacing: -3.4
            color: "#ffffff"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "km/h"
            font.family: Theme.fontFamily; font.pixelSize: 22; color: Theme.textDim
            topPadding: 2
        }
    }

    // ---- right: next manoeuvre ------------------------------------------
    PanelCard {
        x: parent.width - 36 - 340
        y: 36
        width: 340
        height: navCol.implicitHeight + 44
        radius: 16
        elevated: true

        Column {
            id: navCol
            x: 24; y: 22
            width: parent.width - 48
            spacing: 14
            Text { text: "NAVIGATION"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 1.4; color: Theme.blue }
            Row {
                spacing: 14
                Icon { name: "ph-arrow-bend-up-right"; size: 38; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Row {
                        spacing: 6
                        Text { text: "1.2"; font.family: Theme.fontFamily; font.pixelSize: 28; font.weight: Font.Bold; color: Theme.textPrimary }
                        Text { text: "km"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { text: "Avenue des Champs-Élysées"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textSecondary }
                }
            }
            Column {
                spacing: 2
                Text { text: "Puis"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                Text { text: "Boulevard Périphérique"; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textBright }
            }
            Rectangle {
                width: parent.width; height: 5; radius: 3; color: Theme.trackBg
                Rectangle {
                    width: parent.width * 0.42; height: parent.height; radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Theme.blueDeep }
                        GradientStop { position: 1.0; color: Theme.blueLight }
                    }
                }
            }
            Row {
                width: parent.width
                Repeater {
                    model: [
                        { v: "16:04", l: "arrivée" },
                        { v: "85 km", l: "restants" },
                        { v: "1h 32", l: "temps" }
                    ]
                    delegate: Item {
                        width: navCol.width / 3
                        height: col.implicitHeight
                        Column {
                            id: col
                            anchors.horizontalCenter: parent.horizontalCenter
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.v; font.family: Theme.fontFamily; font.pixelSize: 18; font.weight: Font.DemiBold; color: Theme.textPrimary }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.l; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                        }
                    }
                }
            }
        }
    }

    // ---- cruise / limit pill --------------------------------------------
    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height - 78 - 24 - 52
        height: 52
        width: limitRow.implicitWidth + 56
        radius: 16
        color: Theme.alpha("#080d18", 0.82)
        border.width: 1
        border.color: Theme.alpha(Theme.blue, 0.18)
        Row {
            id: limitRow
            anchors.centerIn: parent
            spacing: 26
            Icon { name: "ph-road-horizon"; size: 26; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            Row {
                spacing: 9
                anchors.verticalCenter: parent.verticalCenter
                Icon { name: "ph-gauge"; size: 24; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "100 km/h"; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
            }
            Icon { name: "ph-car-simple"; size: 26; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---- telltale strip (stands in for the nav bar on this screen) -------
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 78
        color: Theme.alpha(Theme.navBg, 0.9)
        Rectangle { anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right; height: 1; color: Theme.alpha(Theme.blue, 0.12) }

        Row {
            anchors.fill: parent
            anchors.leftMargin: 60
            anchors.rightMargin: 60

            Item {
                width: parent.width / 6; height: parent.height
                Icon {
                    anchors.centerIn: parent; name: "ph-house-simple"; size: 24
                    color: homeHover.containsMouse ? Theme.textPrimary : Theme.textMuted
                    MouseArea { id: homeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: AppState.go("accueil") }
                }
            }
            Item {
                width: parent.width / 6; height: parent.height
                Icon { anchors.centerIn: parent; name: "ph-seatbelt"; fill: true; size: 26; color: Theme.red }
            }
            Item {
                width: parent.width / 6; height: parent.height
                Rectangle {
                    anchors.centerIn: parent
                    width: 30; height: 30; radius: 15
                    border.width: 2.5; border.color: Theme.red; color: "transparent"
                    Text { anchors.centerIn: parent; text: "P"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.red }
                }
            }
            Item {
                width: parent.width / 6; height: parent.height
                Text { anchors.centerIn: parent; text: "ECO"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1.5; color: Theme.green }
            }
            Item {
                width: parent.width / 6; height: parent.height
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Text { text: "ODO"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; font.letterSpacing: 1.1; anchors.baseline: odoVal.baseline }
                    Text { id: odoVal; text: "12 458 km"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.DemiBold; color: Theme.textPrimary }
                }
            }
            Item {
                width: parent.width / 6; height: parent.height
                Row {
                    anchors.centerIn: parent
                    spacing: 24
                    Icon { name: "ph-tire"; size: 25; color: Theme.yellow; anchors.verticalCenter: parent.verticalCenter }
                    Icon { name: "ph-headlights"; size: 25; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}

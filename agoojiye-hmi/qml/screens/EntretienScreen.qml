import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property var okRows: [
        { label: "Batterie", icon: "ph-car-battery" },
        { label: "Freins", icon: "ph-record" },
        { label: "Pneus", icon: "ph-tire" },
        { label: "Liquides", icon: "ph-drop" }
    ]
    readonly property var histRows: [
        { date: "15/03/2026", label: "Contrôle général" },
        { date: "12/01/2026", label: "Pneus" },
        { date: "20/09/2025", label: "Révision" }
    ]

    Column {
        id: layout
        anchors.fill: parent
        anchors.topMargin: 18; anchors.bottomMargin: 18
        anchors.leftMargin: 32; anchors.rightMargin: 32
        spacing: 18

        Row {
            width: parent.width
            height: parent.height - 108 - 18
            spacing: 18

            // left: état du véhicule
            Column {
                width: 400
                height: parent.height
                spacing: 12
                Text { text: "ÉTAT DU VÉHICULE"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                PanelCard {
                    width: parent.width
                    height: parent.height - 17 - 12
                    radius: 16
                    Column {
                        x: 20; y: 20
                        width: parent.width - 40
                        spacing: 12
                        Row {
                            spacing: 16
                            Icon { name: "ph-shield-check"; fill: true; size: 52; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "VÉHICULE EN"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 0.8; color: Theme.green }
                                Text { text: "BON ÉTAT"; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; font.letterSpacing: 0.8; color: Theme.green }
                                Text { text: "Aucun problème détecté"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                            }
                        }
                        Repeater {
                            model: root.okRows
                            delegate: Rectangle {
                                width: parent.width; height: 48; radius: 11
                                color: Theme.alpha(Theme.navBg, 0.85)
                                border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.1)
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16; anchors.rightMargin: 16
                                    spacing: 13
                                    Icon { name: modelData.icon; size: 20; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: modelData.label; width: parent.width - 20 - 13 - 40 - 20 - 14; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "OK"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                                    Icon { name: "ph-caret-right"; size: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Dernière vérification : Aujourd'hui 08:42"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                    }
                }
            }

            // center: prochain entretien
            Column {
                width: layout.width - 400 - 460 - 36
                height: parent.height
                spacing: 12
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "PROCHAIN ENTRETIEN"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                PanelCard {
                    width: parent.width
                    height: parent.height - 17 - 12
                    radius: 16
                    color: "transparent"
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.alpha(Theme.panelBgTop, 0.7) }
                        GradientStop { position: 1.0; color: Theme.alpha(Theme.panelBgBottom, 0.85) }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 18

                        Item {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 270; height: 270

                            Glow {
                                anchors.centerIn: parent
                                width: 400; height: 400
                                glowColor: Theme.blueDeep
                                intensity: 0.26
                                core: 0.34
                            }
                            Canvas {
                                id: ring
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.reset()
                                    var cx = width / 2, cy = height / 2, r = width / 2
                                    var start = (220 - 90) * Math.PI / 180
                                    function seg(a0, a1, color) {
                                        ctx.beginPath()
                                        ctx.moveTo(cx, cy)
                                        ctx.arc(cx, cy, r, start + a0 * 2 * Math.PI, start + a1 * 2 * Math.PI)
                                        ctx.closePath()
                                        ctx.fillStyle = color
                                        ctx.fill()
                                    }
                                    seg(0, 0.30, Theme.blue)
                                    seg(0.30, 0.72, Theme.green)
                                    seg(0.72, 1.0, "#12233a")
                                }
                            }

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: 13
                                radius: width / 2
                                color: "#080e1a"
                                Column {
                                    anchors.centerIn: parent
                                    spacing: 2
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "DANS"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "12 450"; font.family: Theme.fontFamily; font.pixelSize: 44; font.weight: Font.Bold; color: Theme.textPrimary }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "km"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }
                                    Item { width: 1; height: 7 }
                                    Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 110; height: 1; color: Theme.alpha(Theme.textMuted, 0.3) }
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        topPadding: 7
                                        spacing: 5
                                        Text { text: "1 850"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.green }
                                        Text { text: "km restants"; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textDim }
                                    }
                                    Row {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        topPadding: 6
                                        spacing: 8
                                        Icon { name: "ph-calendar-blank"; size: 16; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                        Text { text: "15 SEPT. 2026"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                                    }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Entretien prévu"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                                }
                            }
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: detailsRow.implicitWidth + 64; height: 52; radius: 13
                            color: detailsHover.containsMouse ? Theme.alpha(Theme.blue, 0.18) : Theme.alpha(Theme.blue, 0.08)
                            border.width: 1; border.color: Theme.blue
                            Row {
                                id: detailsRow
                                anchors.centerIn: parent
                                spacing: 12
                                Text { text: "Voir détails"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                                Icon { name: "ph-caret-right"; size: 16; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: detailsHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }

            // right: état des composants
            Column {
                width: 460
                height: parent.height
                spacing: 11
                Row {
                    width: parent.width
                    Text { text: "ÉTAT DES COMPOSANTS"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                    Item { width: parent.width - 300; height: 1 }
                    Icon { name: "ph-info"; size: 19; color: Theme.textMuted }
                }

                PanelCard {
                    width: parent.width; height: 92; radius: 14
                    Row {
                        anchors.fill: parent; anchors.margins: 18
                        spacing: 16
                        Icon { name: "ph-tire"; size: 30; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "PNEUS"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 0.8; color: Theme.textPrimary }
                            Row {
                                spacing: 6
                                Rectangle { width: 8; height: 8; radius: 4; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Normal"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.green }
                            }
                        }
                        Item { width: parent.width - 30 - 16 - 130 - 150; height: 1 }
                        Row {
                            spacing: 10
                            anchors.verticalCenter: parent.verticalCenter
                            Column {
                                spacing: 5
                                Text { text: "2.5"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                                Text { text: "2.6"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                            }
                            Rectangle { width: 26; height: 44; radius: 10; color: "#101a2c"; border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.3) }
                            Column {
                                spacing: 5
                                Text { text: "2.5"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                                Row {
                                    spacing: 4
                                    Text { text: "2.6"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                                    Text { text: "bar"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                    }
                }

                PanelCard {
                    width: parent.width; height: 92; radius: 14
                    Row {
                        anchors.fill: parent; anchors.margins: 18
                        spacing: 16
                        Icon { name: "ph-record"; size: 30; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: 110
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "FREINS"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 0.8; color: Theme.textPrimary }
                            Row {
                                spacing: 6
                                Rectangle { width: 8; height: 8; radius: 4; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Normal"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.green }
                            }
                        }
                        Column {
                            width: parent.width - 30 - 16 - 110 - 16
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Row {
                                width: parent.width; spacing: 10
                                Text { text: "Avant"; width: 52; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }
                                Rectangle { width: parent.width - 52 - 10 - 40; height: 5; radius: 3; color: "#0d1a2e"; anchors.verticalCenter: parent.verticalCenter; Rectangle { width: parent.width * 0.92; height: parent.height; radius: 3; color: Theme.green } }
                                Text { text: "92 %"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                            }
                            Row {
                                width: parent.width; spacing: 10
                                Text { text: "Arrière"; width: 52; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }
                                Rectangle { width: parent.width - 52 - 10 - 40; height: 5; radius: 3; color: "#0d1a2e"; anchors.verticalCenter: parent.verticalCenter; Rectangle { width: parent.width * 0.88; height: parent.height; radius: 3; color: Theme.green } }
                                Text { text: "88 %"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                            }
                        }
                    }
                }

                PanelCard {
                    width: parent.width; height: 92; radius: 14
                    Row {
                        anchors.fill: parent; anchors.margins: 18
                        spacing: 16
                        Icon { name: "ph-battery-charging"; fill: true; size: 30; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            width: parent.width - 30 - 16 - 120
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "BATTERIE"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 0.8; color: Theme.textPrimary }
                            Row {
                                spacing: 6
                                Rectangle { width: 8; height: 8; radius: 4; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Excellent"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.green }
                            }
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: VehicleData.batteryLevel + " "; font.family: Theme.fontFamily; font.pixelSize: 30; font.weight: Font.Bold; color: Theme.green }
                            Text { text: "%"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                PanelCard {
                    width: parent.width; height: 92; radius: 14
                    Row {
                        anchors.fill: parent; anchors.margins: 18
                        spacing: 16
                        Icon { name: "ph-drop"; size: 30; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "LIQUIDES"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 0.8; color: Theme.textPrimary }
                            Row {
                                spacing: 6
                                Rectangle { width: 8; height: 8; radius: 4; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Normaux"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.green }
                            }
                        }
                        Item { width: parent.width - 30 - 16 - 170; height: 1 }
                        Text { text: "Tous les niveaux"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }

        // bottom: derniers entretiens
        PanelCard {
            width: parent.width
            height: 108
            radius: 16
            Row {
                anchors.fill: parent
                anchors.leftMargin: 24; anchors.rightMargin: 24
                spacing: 20
                Text { text: "DERNIERS ENTRETIENS"; width: 200; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Repeater {
                    model: root.histRows
                    delegate: Row {
                        width: (parent.width - 200 - 20 * 4 - 240) / 3
                        height: 44
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14
                        Rectangle {
                            width: 1; height: parent.height
                            color: Theme.alpha(Theme.textMuted, 0.2)
                        }
                        Rectangle {
                            width: 44; height: 44; radius: 11
                            color: Theme.alpha(Theme.navBg, 0.9)
                            border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.2)
                            Icon { anchors.centerIn: parent; name: "ph-calendar-check"; size: 20; color: Theme.textSecondary }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.date; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary }
                            Text { text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                        }
                        Icon { name: "ph-check-circle"; size: 22; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Rectangle {
                    width: 240; height: 48; radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: "transparent"
                    border.width: 1; border.color: histHover.containsMouse ? Theme.blue : Theme.alpha(Theme.panelBorder, 0.25)
                    Row {
                        anchors.centerIn: parent
                        spacing: 10
                        Text { text: "Voir tout l'historique"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium; color: Theme.textPrimary }
                        Icon { name: "ph-caret-right"; size: 15; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: histHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
}

import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property var sideItems: [
        { label: "Aperçu", icon: "ph-car-simple", active: true },
        { label: "Portes et ouvrants", icon: "ph-lock-simple-open", active: false },
        { label: "Pression des pneus", icon: "ph-tire", active: false },
        { label: "Énergie", icon: "ph-battery-charging", active: false },
        { label: "Températures", icon: "ph-thermometer-simple", active: false },
        { label: "Informations", icon: "ph-info", active: false }
    ]

    readonly property var callouts: [
        { label: "Coffre", status: "Fermé", x: 22, y: 20, align: "left" },
        { label: "Toit ouvrant", status: "Fermé", xf: 0.44, y: 20, align: "left" },
        { label: "Capot", status: "Fermé", x: 22, yf: 0.42, align: "left" },
        { label: "Porte avant G", status: "Fermée", x: 22, bottom: 22, align: "left" },
        { label: "Porte avant D", status: "Fermée", right: 22, yf: 0.32, align: "right" },
        { label: "Porte arrière D", status: "Fermée", right: 22, yf: 0.58, align: "right" },
        { label: "Porte arrière G", status: "Fermée", xf: 0.44, bottom: 22, align: "left" }
    ]

    readonly property var statCards: [
        { title: "Kilométrage", icon: "ph-chart-line-up" },
        { title: "Pression des pneus", icon: "" },
        { title: "Températures", icon: "" },
        { title: "Niveau de liquide", icon: "" }
    ]

    Row {
        id: layout
        anchors.fill: parent
        anchors.margins: 0
        anchors.topMargin: 20; anchors.bottomMargin: 20
        anchors.leftMargin: 32; anchors.rightMargin: 32
        spacing: 18

        // left sidebar
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
                Text { text: "VÉHICULE"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
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

        // center: car + callouts + bottom stat row
        Column {
            width: layout.width - 280 - 300 - 36
            height: layout.height
            spacing: 18

            PanelCard {
                width: parent.width
                height: parent.height - 190 - 18
                radius: 16
                border.color: Theme.alpha(Theme.panelBorder, 0.14)
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.panelBgTop, 0.6) }
                    GradientStop { position: 1.0; color: Theme.alpha(Theme.panelBgBottom, 0.8) }
                }

                ImageAsset {
                    id: carShot
                    anchors.fill: parent
                    anchors.margins: 1
                    radius: 15
                    // Fit rather than crop so the whole vehicle stays visible;
                    // the asset's baked alpha melts its edges into the panel.
                    fillMode: Image.PreserveAspectFit
                    source: "qrc:/AgoojiyeHMI/assets/images/vehicule-car.png"
                }

                // The vehicle plate already carries the reference's own anchor
                // dots and dotted leader lines, so the labels below just sit at
                // the ends of them rather than drawing a second set.

                Repeater {
                    model: root.callouts
                    delegate: Column {
                        property var m: modelData
                        x: m.x !== undefined ? m.x : (m.right !== undefined ? parent.width - m.right - width : parent.width * m.xf)
                        y: m.y !== undefined ? m.y : (m.bottom !== undefined ? parent.height - m.bottom - height : parent.height * m.yf)
                        spacing: 2
                        Text {
                            text: m.label
                            font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary
                            anchors.right: m.align === "right" ? parent.right : undefined
                        }
                        Row {
                            spacing: 5
                            anchors.right: m.align === "right" ? parent.right : undefined
                            layoutDirection: m.align === "right" ? Qt.RightToLeft : Qt.LeftToRight
                            Text { text: m.status; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                            Text { text: "●"; font.family: Theme.fontFamily; font.pixelSize: 10; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            Grid {
                width: parent.width
                height: 190
                columns: 4
                columnSpacing: 14

                PanelCard {
                    width: (parent.width - 14 * 3) / 4; height: 190; radius: 14
                    Column {
                        anchors.fill: parent; anchors.margins: 18
                        spacing: 10
                        Text { text: "Batterie"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Row {
                            spacing: 8
                            Icon { name: "ph-battery-high"; fill: true; size: 24; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: AppState.batPct + " %"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row {
                            width: parent.width
                            Text { text: "Autonomie"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                            Item { width: parent.width - 130; height: 1 }
                            Text { text: AppState.range + " km"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        }
                    }
                }
                PanelCard {
                    width: (parent.width - 14 * 3) / 4; height: 190; radius: 14
                    Column {
                        anchors.fill: parent; anchors.margins: 18
                        spacing: 8
                        Text { text: "Pression des pneus"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Row {
                            width: parent.width
                            spacing: 8
                            Column {
                                width: (parent.width - 34) / 2
                                Text { anchors.right: parent.right; text: "2.5 bar"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                                Text { anchors.right: parent.right; topPadding: 10; text: "2.6 bar"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                            }
                            Rectangle { width: 34; height: 62; radius: 16; color: "#101a2c"; border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.25) }
                            Column {
                                width: (parent.width - 34) / 2
                                Text { text: "2.5 bar"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                                Text { topPadding: 10; text: "2.6 bar"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                            }
                        }
                    }
                }
                PanelCard {
                    width: (parent.width - 14 * 3) / 4; height: 190; radius: 14
                    Column {
                        anchors.fill: parent; anchors.margins: 18
                        spacing: 10
                        Text { text: "Températures"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Row {
                            width: parent.width; spacing: 10
                            Icon { name: "ph-thermometer-simple"; size: 18; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Moteur"; width: parent.width - 90; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "90 °C"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle { width: parent.width; height: 4; radius: 2; color: "#0d1a2e"; Rectangle { width: parent.width * 0.62; height: parent.height; radius: 2; color: Theme.blue } }
                        Row {
                            width: parent.width; spacing: 10
                            Icon { name: "ph-car-battery"; size: 18; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Batterie"; width: parent.width - 90; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "28 °C"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Rectangle { width: parent.width; height: 4; radius: 2; color: "#0d1a2e"; Rectangle { width: parent.width * 0.35; height: parent.height; radius: 2; color: Theme.blue } }
                    }
                }
                PanelCard {
                    width: (parent.width - 14 * 3) / 4; height: 190; radius: 14
                    Column {
                        anchors.fill: parent; anchors.margins: 18
                        spacing: 12
                        Text { text: "Niveau de liquide"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Item {
                            width: parent.width; height: 20
                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Icon { name: "ph-drop"; size: 18; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Lave-glace"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "OK"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.green }
                        }
                        Item {
                            width: parent.width; height: 20
                            Row {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: 10
                                Icon { name: "ph-brake-warning"; size: 18; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: "Liquide de frein"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "OK"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.green }
                        }
                    }
                }
            }
        }

        // right stat column
        Column {
            width: 300
            height: layout.height
            spacing: 14
            topPadding: 54

            PanelCard {
                width: parent.width; height: 74; radius: 14
                Row {
                    anchors.fill: parent; anchors.margins: 18
                    Column {
                        width: parent.width - 24
                        Text { text: "Kilométrage"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                        Row {
                            spacing: 6
                            Text { text: "12 458"; font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; color: Theme.textPrimary }
                            Text { text: "km"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    Icon { name: "ph-chart-line-up"; size: 24; color: Theme.blue }
                }
            }
            PanelCard {
                width: parent.width; height: 68; radius: 14
                Column {
                    anchors.fill: parent; anchors.margins: 18
                    spacing: 6
                    Text { text: "Statut général"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                    Row {
                        spacing: 8
                        Icon { name: "ph-check-circle"; size: 20; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Aucun défaut"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
            PanelCard {
                width: parent.width; height: 74; radius: 14
                Row {
                    anchors.fill: parent; anchors.margins: 18
                    Column {
                        width: parent.width - 24
                        Text { text: "Prochaine révision"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                        Text { text: "Dans 12 000 km"; font.family: Theme.fontFamily; font.pixelSize: 18; font.weight: Font.DemiBold; color: Theme.textPrimary }
                    }
                    Icon { name: "ph-calendar-blank"; size: 24; color: Theme.blue }
                }
            }
            PanelCard {
                width: parent.width; height: 74; radius: 14
                Row {
                    anchors.fill: parent; anchors.margins: 18
                    Column {
                        width: parent.width - 24
                        Text { text: "VIN"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.blue }
                        Text { text: "VR3D1A23XKY123456"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                    }
                    Icon { name: "ph-copy"; size: 22; color: Theme.textMuted }
                }
            }
        }
    }
}

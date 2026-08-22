import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property int section: AppState.section("veh")

    readonly property var sideItems: [
        { label: "Aperçu", icon: "ph-car-simple" },
        { label: "Ouvrants et accès", icon: "ph-lock-simple-open" },
        { label: "Pression des pneus", icon: "ph-tire" },
        { label: "Énergie", icon: "ph-battery-charging" },
        { label: "Températures", icon: "ph-thermometer-simple" },
        { label: "Informations", icon: "ph-info" }
    ]

    // 12458 -> "12 458"
    function formatKm(v) {
        return String(v).replace(/\B(?=(\d{3})+(?!\d))/g, " ")
    }

    // An open-sided shuttle has no boot, sunroof or four passenger doors, so
    // the callouts track what this vehicle actually has: a bonnet, the driver's
    // door, the open boarding sides, the charge flap and the battery bay.
    //
    // The render shows the shuttle three-quarter on with the cab to the RIGHT,
    // so each label sits on the side of the panel its part is actually on.
    // `tx`/`ty` are the anchor point on the vehicle, as a fraction of the panel.
    readonly property var callouts: [
        { label: "Trappe de charge",      open: 4, x: 22,     y: 20,      align: "left",  tx: 0.20, ty: 0.30 },
        { label: "Accès passagers G",     open: 1, x: 22,     yf: 0.50,   align: "left",  tx: 0.34, ty: 0.56 },
        { label: "Compartiment batterie", open: 5, x: 22,     bottom: 22, align: "left",  tx: 0.46, ty: 0.74 },
        { label: "Porte conducteur",      open: 0, right: 22, y: 20,      align: "right", tx: 0.73, ty: 0.34 },
        { label: "Capot",                 open: 3, right: 22, yf: 0.50,   align: "right", tx: 0.86, ty: 0.58 },
        { label: "Accès passagers D",     open: 2, right: 22, bottom: 22, align: "right", tx: 0.64, ty: 0.70 }
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
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AppState.back() }
                }
                Text { text: "VÉHICULE"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
            }
            Repeater {
                model: root.sideItems
                delegate: SidebarItem {
                    required property var modelData
                    required property int index
                    width: 280
                    iconName: modelData.icon; label: modelData.label
                    active: index === root.section
                    accentColor: Theme.green; tintColor: Theme.alpha(Theme.green, 0.09)
                    onClicked: AppState.selectSection("veh", index)
                }
            }
        }

        // ---- panneau de la section ---------------------------------------
        Item {
            id: pane
            width: layout.width - 280 - 18
            height: layout.height

            // ---- 0 · Aperçu ----------------------------------------------
            Row {
                anchors.fill: parent
                spacing: 18
                visible: root.section === 0

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
                            // Inset so the callouts down each edge have clear space and
                            // never land on the vehicle itself.
                            anchors.leftMargin: 150
                            anchors.rightMargin: 150
                            anchors.topMargin: 46
                            anchors.bottomMargin: 54
                            radius: 15
                            // Fit rather than crop so the whole vehicle stays visible;
                            // the render carries its own transparency, so no scrim is
                            // needed to blend it into the panel.
                            fillMode: Image.PreserveAspectFit
                            source: "qrc:/AgoojiyeHMI/assets/images/vehicule-car.png"
                        }

                        // Dotted leader lines tying each label to its point on the
                        // vehicle. The render is a clean cut-out, so unlike the earlier
                        // reference plate there is no baked-in annotation to reuse.
                        Canvas {
                            anchors.fill: parent
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.lineWidth = 1
                                ctx.strokeStyle = Theme.alpha(Theme.textMuted, 0.4)
                                ctx.setLineDash([2, 4])

                                for (var i = 0; i < root.callouts.length; i++) {
                                    var m = root.callouts[i]
                                    var right = m.align === "right"
                                    // Start just inboard of the label block.
                                    var sx = right ? width - 22 - 148 : 22 + 148
                                    var sy = m.y !== undefined ? m.y + 20
                                           : (m.bottom !== undefined ? height - m.bottom - 18
                                                                     : height * m.yf + 20)
                                    var ex = width * m.tx
                                    var ey = height * m.ty

                                    ctx.beginPath()
                                    ctx.moveTo(sx, sy)
                                    ctx.lineTo(sx + (ex - sx) * 0.4, sy)
                                    ctx.lineTo(ex, ey)
                                    ctx.stroke()
                                }

                                ctx.setLineDash([])
                                ctx.fillStyle = Theme.green
                                for (var j = 0; j < root.callouts.length; j++) {
                                    var c = root.callouts[j]
                                    ctx.beginPath()
                                    ctx.arc(width * c.tx, height * c.ty, 3.5, 0, Math.PI * 2)
                                    ctx.fill()
                                }
                            }
                        }

                        Repeater {
                            model: root.callouts
                            delegate: Column {
                                property var m: modelData
                                x: m.x !== undefined ? m.x : parent.width - m.right - width
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
                                    Text {
                                        // `open` désigne l'ouvrant dans VehicleData : l'état montré
                                        // ici et celui du panneau « Ouvrants » ne peuvent plus diverger.
                                        text: VehicleData.openings[m.open].open ? "Ouvert" : "Fermé"
                                        font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted
                                    }
                                    Text {
                                        text: "●"; font.family: Theme.fontFamily; font.pixelSize: 10
                                        color: VehicleData.openings[m.open].open ? Theme.yellow : Theme.green
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
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
                                    Text { text: VehicleData.batteryLevel + " %"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Row {
                                    width: parent.width
                                    Text { text: "Autonomie"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                                    Item { width: parent.width - 130; height: 1 }
                                    Text { text: VehicleData.range + " km"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary }
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
                                        Text { anchors.right: parent.right; text: VehicleData.tyreFrontLeft.toFixed(1) + " bar"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                                        Text { anchors.right: parent.right; topPadding: 10; text: VehicleData.tyreRearLeft.toFixed(1) + " bar"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                                    }
                                    Rectangle { width: 34; height: 62; radius: 16; color: "#101a2c"; border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.25) }
                                    Column {
                                        width: (parent.width - 34) / 2
                                        Text { text: VehicleData.tyreFrontRight.toFixed(1) + " bar"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                                        Text { topPadding: 10; text: VehicleData.tyreRearRight.toFixed(1) + " bar"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
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
                                    Text { text: VehicleData.motorTemp + " °C"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Rectangle { width: parent.width; height: 4; radius: 2; color: "#0d1a2e"; Rectangle { width: parent.width * Math.max(0, Math.min(1, VehicleData.motorTemp / 120)); height: parent.height; radius: 2; color: VehicleData.motorTemp > 105 ? Theme.red : Theme.blue } }
                                Row {
                                    width: parent.width; spacing: 10
                                    Icon { name: "ph-car-battery"; size: 18; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: "Batterie"; width: parent.width - 90; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: VehicleData.batteryTemp + " °C"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Rectangle { width: parent.width; height: 4; radius: 2; color: "#0d1a2e"; Rectangle { width: parent.width * Math.max(0, Math.min(1, VehicleData.batteryTemp / 60)); height: parent.height; radius: 2; color: VehicleData.batteryTemp > 45 ? Theme.red : Theme.blue } }
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
                                    Text { text: root.formatKm(VehicleData.odometer); font.family: Theme.fontFamily; font.pixelSize: 22; font.weight: Font.Bold; color: Theme.textPrimary }
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
                                Text { text: VehicleData.faultPresent ? "Défaut détecté" : "Aucun défaut"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
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
                                Text { text: "Dans " + root.formatKm(VehicleData.serviceDueIn) + " km"; font.family: Theme.fontFamily; font.pixelSize: 18; font.weight: Font.DemiBold; color: Theme.textPrimary }
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
                                Text { text: VehicleData.vin; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
                            }
                            Icon { name: "ph-copy"; size: 22; color: Theme.textMuted }
                        }
                    }
                }
            }

            // ---- 1 · Ouvrants et accès -----------------------------------
            Column {
                id: openPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 1

                Text { text: "OUVRANTS ET ACCÈS"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    Repeater {
                        model: VehicleData.openings
                        delegate: SettingRow {
                            required property var modelData
                            width: (openPane.width - 18) / 2
                            iconName: modelData.icon
                            accentColor: modelData.open ? Theme.orange : Theme.green
                            label: modelData.label
                            value: modelData.open ? "Ouvert" : "Fermé"
                        }
                    }
                }

                Text { text: "VERROUILLAGE"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted; topPadding: 10 }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    SettingRow {
                        width: (openPane.width - 18) / 2
                        iconName: "ph-lock-simple-open"; accentColor: Theme.blue
                        label: "Verrouillage automatique"; sub: "Au-delà de 10 km/h"
                        ToggleSwitch { checked: AppState.autoLock; accentColor: Theme.blue; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.autoLock = !AppState.autoLock }
                    }
                    SettingRow {
                        width: (openPane.width - 18) / 2
                        iconName: "ph-headlights"; accentColor: Theme.orange
                        label: "Éclairage d'accueil"; sub: "S'allume à l'approche"
                        ToggleSwitch { checked: AppState.welcomeLighting; accentColor: Theme.orange; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.welcomeLighting = !AppState.welcomeLighting }
                    }
                }
            }

            // ---- 2 · Pression des pneus -----------------------------------
            Column {
                id: tyrePane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 2

                Text { text: "PRESSION DES PNEUS"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                Grid {
                    width: parent.width
                    columns: 4
                    columnSpacing: 14
                    Repeater {
                        model: [
                            { l: "AVANT GAUCHE", v: VehicleData.tyreFrontLeft },
                            { l: "AVANT DROIT", v: VehicleData.tyreFrontRight },
                            { l: "ARRIÈRE GAUCHE", v: VehicleData.tyreRearLeft },
                            { l: "ARRIÈRE DROIT", v: VehicleData.tyreRearRight }
                        ]
                        delegate: StatTile {
                            required property var modelData
                            width: (tyrePane.width - 14 * 3) / 4
                            iconName: "ph-tire"
                            label: modelData.l
                            value: modelData.v.toFixed(1)
                            unit: "bar"
                            // Un écart de plus de 0,3 bar à la consigne se voit.
                            valueColor: Math.abs(modelData.v - VehicleData.tyreRecommended) > 0.3
                                        ? Theme.yellow : Theme.green
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    SettingRow { width: (tyrePane.width - 18) / 2; iconName: "ph-gauge"; accentColor: Theme.blue; label: "Pression recommandée"; value: VehicleData.tyreRecommended.toFixed(1) + " bar" }
                    SettingRow { width: (tyrePane.width - 18) / 2; iconName: "ph-ruler"; accentColor: Theme.blue; label: "Unité"; value: AppState.pressureUnit; chevron: "ph-caret-down" }
                    SettingRow {
                        width: (tyrePane.width - 18) / 2
                        iconName: "ph-brake-warning"
                        accentColor: VehicleData.tyrePressureWarning ? Theme.yellow : Theme.green
                        label: "Alerte de pression"
                        value: VehicleData.tyrePressureWarning ? "Active" : "Aucune"
                    }
                    SettingRow { width: (tyrePane.width - 18) / 2; iconName: "ph-clock-counter-clockwise"; accentColor: Theme.textMuted; label: "Dernier contrôle"; value: "Aujourd'hui 08:42" }
                }
            }

            // ---- 3 · Énergie ----------------------------------------------
            Column {
                id: energyPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 3

                Text { text: "ÉNERGIE"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                Grid {
                    width: parent.width
                    columns: 4
                    columnSpacing: 14
                    StatTile { width: (energyPane.width - 42) / 4; iconName: "ph-battery-high"; label: "BATTERIE"; value: String(VehicleData.batteryLevel); unit: "%"; valueColor: Theme.green }
                    StatTile {
                        width: (energyPane.width - 42) / 4
                        iconName: "ph-road-horizon"
                        label: "AUTONOMIE"
                        value: String(VehicleData.range)
                        unit: "km"
                        // Vert tant que la consommation constatée tient la
                        // promesse du catalogue, ambre quand elle la dépasse.
                        valueColor: VehicleData.range >= VehicleData.rangeFullCharge * VehicleData.batteryFraction * 0.9
                                    ? Theme.green : Theme.yellow
                    }
                    StatTile { width: (energyPane.width - 42) / 4; iconName: "ph-lightning"; label: "PUISSANCE"; value: VehicleData.power.toFixed(1); unit: "kW"; valueColor: Theme.blue }
                    StatTile { width: (energyPane.width - 42) / 4; iconName: "ph-leaf"; label: "RÉCUPÉRATION"; value: VehicleData.regenPower.toFixed(1); unit: "kW"; valueColor: Theme.green }
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    SettingRow { width: (energyPane.width - 18) / 2; iconName: "ph-lightning"; accentColor: VehicleData.charging ? Theme.green : Theme.textMuted; label: "État de charge"; value: VehicleData.chargeStatus }
                    SettingRow { width: (energyPane.width - 18) / 2; iconName: "ph-chart-bar"; accentColor: Theme.blue; label: "Consommation moyenne"; value: VehicleData.consumption.toFixed(1) + " kWh/100km" }
                    SettingRow { width: (energyPane.width - 18) / 2; iconName: "ph-repeat"; accentColor: Theme.purple; label: "Cycles de charge"; value: String(VehicleData.chargeCycles) }
                    SettingRow { width: (energyPane.width - 18) / 2; iconName: "ph-car-battery"; accentColor: Theme.orange; label: "Température batterie"; value: VehicleData.batteryTemp + " °C" }
                }

                Text { text: "RÉGÉNÉRATION"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted; topPadding: 8 }
                SegmentedControl {
                    width: parent.width
                    options: ["Faible", "Moyenne", "Forte", "Auto"]
                    accentColor: Theme.green
                    currentIndex: Math.max(0, ["Faible", "Moyenne", "Forte", "Auto"].indexOf(AppState.regen))
                    onSelected: (i) => AppState.regen = ["Faible", "Moyenne", "Forte", "Auto"][i]
                }
            }

            // ---- 4 · Températures ------------------------------------------
            Column {
                id: tempPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 4

                Text { text: "TEMPÉRATURES"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                Grid {
                    width: parent.width
                    columns: 4
                    columnSpacing: 14
                    Repeater {
                        model: [
                            { l: "MOTEUR", v: VehicleData.motorTemp, f: 0.62, i: "ph-thermometer-simple" },
                            { l: "BATTERIE", v: VehicleData.batteryTemp, f: 0.28, i: "ph-car-battery" },
                            { l: "HABITACLE", v: VehicleData.cabinTemp, f: 0.22, i: "ph-armchair" },
                            { l: "EXTÉRIEUR", v: VehicleData.outsideTemp, f: 0.23, i: "ph-sun" }
                        ]
                        delegate: PanelCard {
                            required property var modelData
                            width: (tempPane.width - 42) / 4
                            height: 124
                            radius: 14
                            Column {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 10
                                Row {
                                    spacing: 8
                                    Icon { name: modelData.i; size: 16; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                    Text { text: modelData.l; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                }
                                Row {
                                    spacing: 6
                                    Text { id: tv; text: String(modelData.v); font.family: Theme.fontFamily; font.pixelSize: 27; font.weight: Font.Bold; color: Theme.textPrimary }
                                    Text { text: "°C"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.baseline: tv.baseline }
                                }
                                Rectangle {
                                    width: parent.width; height: 4; radius: 2; color: Theme.trackBg
                                    Rectangle { width: parent.width * modelData.f; height: parent.height; radius: 2; color: modelData.f > 0.8 ? Theme.red : Theme.blue }
                                }
                            }
                        }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    SettingRow { width: (tempPane.width - 18) / 2; iconName: "ph-drop"; accentColor: Theme.blue; label: "Liquide de refroidissement"; value: "Normal" }
                    SettingRow { width: (tempPane.width - 18) / 2; iconName: "ph-record"; accentColor: Theme.green; label: "Freins"; value: "Normal" }
                }
            }

            // ---- 5 · Informations -------------------------------------------
            Column {
                id: infoPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 5

                Text { text: "INFORMATIONS"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    SettingRow { width: (infoPane.width - 18) / 2; iconName: "ph-car-simple"; accentColor: Theme.blue; label: "Modèle"; value: VehicleData.vehicleModel }
                    SettingRow { width: (infoPane.width - 18) / 2; iconName: "ph-info"; accentColor: Theme.blue; label: "Identifiant (VIN)"; value: VehicleData.vin }
                    SettingRow { width: (infoPane.width - 18) / 2; iconName: "ph-chart-line-up"; accentColor: Theme.green; label: "Kilométrage"; value: root.formatKm(VehicleData.odometer) + " km" }
                    SettingRow { width: (infoPane.width - 18) / 2; iconName: "ph-calendar-blank"; accentColor: Theme.purple; label: "Mise en service"; value: VehicleData.commissioningDate }
                    SettingRow { width: (infoPane.width - 18) / 2; iconName: "ph-cube"; accentColor: Theme.blue; label: "Version logicielle"; value: VehicleData.softwareVersion }
                    SettingRow { width: (infoPane.width - 18) / 2; iconName: "ph-wrench"; accentColor: Theme.orange; label: "Prochaine révision"; value: "Dans " + root.formatKm(VehicleData.serviceDueIn) + " km"; chevron: "ph-caret-right"; onClicked: AppState.go("entretien") }
                }
            }
        }
    }
}

import QtQuick
import AgoojiyeHMI

Item {
    id: root
    clip: true

    readonly property var navSteps: [
        { label: "Boulevard Périphérique", dist: "850 m", icon: "ph-arrow-bend-up-right" },
        { label: "Porte Maillot", dist: "2.4 km", icon: "ph-arrow-bend-up-left" },
        { label: "Place de l'Étoile", dist: "3.1 km", icon: "ph-arrows-clockwise" }
    ]

    ImageAsset {
        anchors.fill: parent
        radius: 0
        source: "qrc:/AgoojiyeHMI/assets/images/nav-map.jpg"
    }

    // Guidance route. Drawn as a curve rather than a rotated bar so it reads
    // like a road being followed; a soft under-stroke gives it the lit look the
    // reference map has.
    Canvas {
        id: route
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height

            function trace() {
                ctx.beginPath()
                ctx.moveTo(w * 0.588, h * 0.095)
                ctx.bezierCurveTo(w * 0.600, h * 0.30,
                                  w * 0.578, h * 0.46,
                                  w * 0.556, h * 0.60)
                ctx.lineTo(w * 0.545, h * 0.655)
            }

            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            // Halo, then casing, then the route itself.
            trace()
            ctx.strokeStyle = Qt.rgba(0.23, 0.51, 0.96, 0.18)
            ctx.lineWidth = 26
            ctx.stroke()

            trace()
            ctx.strokeStyle = Qt.rgba(0.09, 0.22, 0.45, 0.9)
            ctx.lineWidth = 14
            ctx.stroke()

            trace()
            var g = ctx.createLinearGradient(0, h * 0.09, 0, h * 0.66)
            g.addColorStop(0, "#93c5fd")
            g.addColorStop(1, "#2563eb")
            ctx.strokeStyle = g
            ctx.lineWidth = 9
            ctx.stroke()
        }
    }
    Rectangle {
        x: root.width * 0.545 - 26
        y: root.height * 0.66 - 26
        width: 52; height: 52; radius: 26
        color: "#2563eb"
        border.width: 3; border.color: "#93c5fd"
        Icon { anchors.centerIn: parent; name: "ph-navigation-arrow"; fill: true; size: 24; color: "#ffffff"; rotation: 90 }
    }
    Rectangle {
        x: root.width * 0.60
        y: root.height * 0.06
        radius: 6
        color: Theme.redDeep
        width: n13.width + 20; height: n13.height + 6
        Text { id: n13; anchors.centerIn: parent; text: "N13"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: "#ffffff" }
    }

    Repeater {
        model: [
            { label: "Avenue Foch", xf: 0.36, yf: 0.16 },
            { label: "Avenue Victor Hugo", xf: 0.34, yf: 0.33 },
            { label: "Avenue Kléber", xf: 0.37, yf: 0.48 },
            { label: "Rue de la Boétie", xf: 0.35, yf: 0.62 }
        ]
        delegate: Rectangle {
            x: root.width * modelData.xf
            y: root.height * modelData.yf
            radius: 8
            color: Theme.alpha(Theme.navBg, 0.85)
            border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.2)
            width: lbl.implicitWidth + 28; height: lbl.implicitHeight + 12
            Text { id: lbl; anchors.centerIn: parent; text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textPrimary }
        }
    }
    Rectangle {
        x: root.width * 0.59
        y: root.height * 0.52
        radius: 8
        color: "#2563eb"
        width: destLbl.implicitWidth + 32; height: destLbl.implicitHeight + 14
        Text { id: destLbl; anchors.centerIn: parent; text: "Avenue des Champs-Élysées"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: "#ffffff" }
    }

    // route card
    PanelCard {
        x: 28; y: 22
        width: 400
        color: Theme.alpha(Theme.navBg, 0.92)
        border.color: Theme.alpha(Theme.panelBorder, 0.18)
        radius: 18
        height: routeCol.implicitHeight + 48

        Column {
            id: routeCol
            x: 24; y: 24
            width: parent.width - 48
            spacing: 16

            Row {
                spacing: 16
                Icon { name: "ph-arrow-bend-up-right"; size: 52; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "1.2"; font.family: Theme.fontFamily; font.pixelSize: 40; font.weight: Font.Bold; color: Theme.textPrimary }
                    Text { text: "km"; font.family: Theme.fontFamily; font.pixelSize: 19; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            Text { text: "Avenue des Champs-Élysées"; font.family: Theme.fontFamily; font.pixelSize: 18; font.weight: Font.Medium; color: Theme.textPrimary }

            Rectangle {
                width: parent.width; height: 5; radius: 3; color: "#0d1a2e"
                Rectangle {
                    width: parent.width * 0.55; height: parent.height; radius: 3
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#2563eb" }
                        GradientStop { position: 1.0; color: "#60a5fa" }
                    }
                }
                Rectangle {
                    x: parent.width * 0.55 - 6.5; y: -4
                    width: 13; height: 13; radius: 6.5; color: "#93c5fd"
                }
            }

            Divider { width: parent.width }

            Repeater {
                model: root.navSteps
                delegate: Row {
                    width: routeCol.width
                    spacing: 14
                    Icon { name: modelData.icon; size: 22; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        width: routeCol.width - 22 - 14 - 60
                        Text { text: "Puis"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; color: Theme.blue }
                        Text { text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textPrimary }
                    }
                    Text { text: modelData.dist; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            Rectangle {
                width: parent.width; height: 52; radius: 12
                color: endHover.containsMouse ? Theme.alpha(Theme.red, 0.2) : Theme.alpha(Theme.red, 0.1)
                border.width: 1; border.color: Theme.alpha(Theme.red, 0.5)
                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Text { text: "Fin du trajet"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                    Icon { name: "ph-x"; size: 17; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: endHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: AppState.go("menu") }
            }
        }
    }

    // map controls
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 26
        y: 24
        spacing: 12
        Repeater {
            model: [
                { kind: "compass" },
                { kind: "3d" },
                { icon: "ph-plus" },
                { icon: "ph-minus" },
                { icon: "ph-crosshair-simple", accent: true }
            ]
            delegate: Rectangle {
                width: 54; height: 54; radius: 27
                color: Theme.alpha(Theme.navBg, 0.9)
                border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.2)

                Column {
                    visible: modelData.kind === "compass"
                    anchors.centerIn: parent
                    spacing: -2
                    Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "ph-caret-up"; fill: true; size: 15; color: Theme.red }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: "N"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.textPrimary }
                }
                Text { visible: modelData.kind === "3d"; anchors.centerIn: parent; text: "3D"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; color: Theme.textPrimary }
                Icon { visible: !!modelData.icon; anchors.centerIn: parent; name: modelData.icon || ""; size: 21; color: modelData.accent ? Theme.blue : Theme.textPrimary }
            }
        }
    }

    // bottom info bar
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 460
        anchors.right: parent.right
        anchors.rightMargin: 26
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        height: 78
        spacing: 14

        PanelCard {
            width: parent.width - 14 - altBtn.width
            height: parent.height
            radius: 14
            color: Theme.alpha(Theme.navBg, 0.92)
            border.color: Theme.alpha(Theme.panelBorder, 0.18)

            Row {
                anchors.fill: parent
                anchors.leftMargin: 24; anchors.rightMargin: 24
                spacing: 26

                Row {
                    spacing: 12
                    anchors.verticalCenter: parent.verticalCenter
                    Icon { name: "ph-flag-checkered"; size: 22; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        Text { text: "16:04"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; color: Theme.textPrimary }
                        Text { text: "Arrivée"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                    }
                }
                Rectangle { width: 1; height: parent.height * 0.6; anchors.verticalCenter: parent.verticalCenter; color: Theme.alpha(Theme.textMuted, 0.25) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "4.2 km"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; color: Theme.textPrimary }
                    Text { text: "Restants"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                }
                Rectangle { width: 1; height: parent.height * 0.6; anchors.verticalCenter: parent.verticalCenter; color: Theme.alpha(Theme.textMuted, 0.25) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "10 min"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; color: Theme.textPrimary }
                    Text { text: "Temps restant"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                }
                Rectangle { width: 1; height: parent.height * 0.6; anchors.verticalCenter: parent.verticalCenter; color: Theme.alpha(Theme.textMuted, 0.25) }
                Row {
                    spacing: 10
                    anchors.verticalCenter: parent.verticalCenter
                    Icon { name: "ph-traffic-cone"; size: 22; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        Text { text: "Trafic"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                        Text { text: "Fluide"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.green }
                    }
                }
            }
        }

        Rectangle {
            id: altBtn
            width: altRow.implicitWidth + 48
            height: parent.height
            radius: 14
            color: Theme.alpha(Theme.navBg, 0.92)
            border.width: 1
            border.color: altHover.containsMouse ? Theme.blue : Theme.alpha(Theme.panelBorder, 0.25)
            Row {
                id: altRow
                anchors.centerIn: parent
                spacing: 12
                Icon { name: "ph-arrows-left-right"; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Itinéraire alternatif"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { id: altHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
        }
    }
}

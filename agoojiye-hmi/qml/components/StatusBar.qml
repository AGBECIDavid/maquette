import QtQuick
import QtQuick.Shapes
import AgoojiyeHMI

// Bandeau permanent. Il ne change jamais d'un écran à l'autre : c'est là que
// vivent les informations que le conducteur doit pouvoir lire sans réfléchir —
// heure, température, vitesse, rapport engagé, batterie, connectivité.
Item {
    id: root
    height: 66
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.alpha(Theme.blue, 0.1)
    }

    // Left cluster: temperature + clock
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
            Icon { name: "ph-thermometer-simple"; size: 20; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
            Text { text: VehicleData.outsideTemp + "°C"; font.family: Theme.fontFamily; font.pixelSize: 19; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle { width: 1; height: 24; color: Theme.alpha(Theme.textMuted, 0.3); anchors.verticalCenter: parent.verticalCenter }
        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
            Icon { name: "ph-clock"; size: 20; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: AppState.time
                font.family: Theme.fontFamily
                font.pixelSize: 19
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        // La vitesse suit le conducteur hors du tableau de bord, où le grand
        // compteur ne l'accompagne plus.
        Rectangle {
            width: 1; height: 24; color: Theme.alpha(Theme.textMuted, 0.3)
            anchors.verticalCenter: parent.verticalCenter
            visible: AppState.screen !== "dash"
        }
        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: AppState.screen !== "dash"
            Text { text: Math.round(VehicleData.speed); font.family: Theme.fontFamily; font.pixelSize: 21; font.weight: Font.Bold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "km/h"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // Center notch: a tab hanging from the top edge, rounded only at the
    // bottom two corners (CSS border-radius: 0 0 26px 26px; border-top: none).
    Item {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 250
        height: 60
        property real r: 26

        Shape {
            anchors.fill: parent

            ShapePath {
                fillColor: "#08101f"
                strokeWidth: -1
                startX: 0; startY: 0
                PathLine { x: notch.width; y: 0 }
                PathLine { x: notch.width; y: notch.height - notch.r }
                PathArc { x: notch.width - notch.r; y: notch.height; radiusX: notch.r; radiusY: notch.r }
                PathLine { x: notch.r; y: notch.height }
                PathArc { x: 0; y: notch.height - notch.r; radiusX: notch.r; radiusY: notch.r }
                PathLine { x: 0; y: 0 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.alpha(Theme.blue, 0.22)
                strokeWidth: 1
                capStyle: ShapePath.FlatCap
                startX: 0; startY: 0
                PathLine { x: 0; y: notch.height - notch.r }
                PathArc { x: notch.r; y: notch.height; radiusX: notch.r; radiusY: notch.r }
                PathLine { x: notch.width - notch.r; y: notch.height }
                PathArc { x: notch.width; y: notch.height - notch.r; radiusX: notch.r; radiusY: notch.r }
                PathLine { x: notch.width; y: 0 }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0
            Text { text: VehicleData.driveGear; anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontFamily; font.pixelSize: 21; font.weight: Font.Bold; color: Theme.textPrimary }
            Text { text: VehicleData.systemReady ? "READY" : "STANDBY"; anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.green }
        }
    }

    // Right cluster
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18

        Rectangle {
            width: 36; height: 36; radius: 18
            color: "#f4f6fb"
            border.width: 4
            border.color: Theme.redDeep
            anchors.verticalCenter: parent.verticalCenter
            Text { anchors.centerIn: parent; text: VehicleData.speedLimit; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: "#0b1020" }
        }
        Row {
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter
            Icon { name: "ph-headlights"; size: 22; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "AUTO"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
        }
        // La charge restante ne doit jamais dépendre de l'écran ouvert.
        Row {
            spacing: 7
            anchors.verticalCenter: parent.verticalCenter
            Icon {
                name: VehicleData.charging ? "ph-battery-charging" : "ph-battery-high"
                fill: true; size: 22
                color: VehicleData.batteryLevel <= 15 ? Theme.red : Theme.green
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: VehicleData.batteryLevel + "%"
                font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold
                color: VehicleData.batteryLevel <= 15 ? Theme.red : Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Icon { name: "ph-bluetooth"; size: 20; color: VehicleData.bluetoothConnected ? Theme.blue : Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Text { text: VehicleData.network; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            Icon { name: "ph-cell-signal-full"; size: 19; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
        }
        Icon { name: "ph-wifi-high"; size: 20; color: VehicleData.wifiConnected ? Theme.textSecondary : Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
        // Tiroir d'applications. Les sept destinations principales sont dans la
        // barre du bas ; ce bouton ouvre le reste (téléphone, entretien,
        // à propos) sans encombrer la barre.
        Rectangle {
            width: 40; height: 40; radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: AppState.menuOpen ? Theme.alpha(Theme.blue, 0.14)
                                     : (menuHover.containsMouse ? Theme.alpha(Theme.panelBgTop, 0.9) : "transparent")
            border.width: 1
            border.color: AppState.menuOpen ? Theme.blue : "transparent"

            Icon {
                anchors.centerIn: parent
                name: "ph-squares-four"
                size: 24
                color: AppState.menuOpen ? Theme.blue
                                         : (menuHover.containsMouse ? Theme.textPrimary : Theme.textMuted)
            }
            MouseArea {
                id: menuHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Rappuyer referme le tiroir sur l'écran d'où l'on venait.
                onClicked: AppState.menuOpen ? AppState.back() : AppState.go("menu")
            }
        }
    }
}

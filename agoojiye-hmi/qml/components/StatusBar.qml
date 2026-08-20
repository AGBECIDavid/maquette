import QtQuick
import QtQuick.Shapes
import AgoojiyeHMI

Item {
    id: root
    height: 66

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
            Text { text: "23°C"; font.family: Theme.fontFamily; font.pixelSize: 19; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
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
            Text { text: "D"; anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontFamily; font.pixelSize: 21; font.weight: Font.Bold; color: Theme.textPrimary }
            Text { text: "READY"; anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.green }
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
            Text { anchors.centerIn: parent; text: "30"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: "#0b1020" }
        }
        Row {
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter
            Icon { name: "ph-headlights"; size: 22; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "AUTO"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
        }
        Icon { name: "ph-bluetooth"; size: 20; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Text { text: "4G"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            Icon { name: "ph-cell-signal-full"; size: 19; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
        }
        Icon { name: "ph-wifi-high"; size: 20; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
        Icon {
            name: "ph-user-circle"
            size: 27
            color: Theme.textMuted
            anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AppState.go("accueil") }
        }
    }
}

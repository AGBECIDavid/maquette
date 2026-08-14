import QtQuick
import AgoojiyeHMI

// Left-rail navigation row used on Véhicule / Média / ADAS / Conduite /
// Paramètres screens: icon + label, left accent bar + tint when active.
Rectangle {
    id: root
    property string iconName: ""
    property string label: ""
    property bool active: false
    property color accentColor: Theme.blue
    property color tintColor: Theme.alpha(Theme.blue, 0.09)
    signal clicked()

    height: 52
    radius: 12
    color: active ? tintColor : (hover.containsMouse ? Theme.alpha(Theme.panelBgTop, 0.9) : "transparent")

    Rectangle {
        width: 3
        height: parent.height
        radius: 1.5
        color: active ? root.accentColor : "transparent"
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 13

        Icon {
            name: root.iconName
            size: 20
            color: active ? root.accentColor : "#aeb9cc"
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: 16
            font.weight: Font.Medium
            color: active ? root.accentColor : "#aeb9cc"
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

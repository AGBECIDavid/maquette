import QtQuick
import AgoojiyeHMI

PanelCard {
    id: root
    property string iconName: ""
    property string label: ""
    property string sub: ""
    property color accentColor: Theme.blue
    signal clicked()

    border.color: hover.containsMouse ? Theme.alpha(Theme.panelBorder, 0.4) : Theme.alpha(Theme.panelBorder, 0.14)
    clip: true

    Column {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 22
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 10

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 66; height: 66

            // The icon rings read as lit tokens, not flat outlines.
            Glow {
                anchors.centerIn: parent
                width: 150; height: 150
                glowColor: root.accentColor
                intensity: hover.containsMouse ? 0.40 : 0.26
                core: 0.16
                Behavior on intensity { NumberAnimation { duration: 160 } }
            }
            Rectangle {
                anchors.fill: parent
                radius: 33
                color: Theme.alpha(root.accentColor, 0.12)
                border.width: 2
                border.color: root.accentColor
                Icon { anchors.centerIn: parent; name: root.iconName; size: 30; color: root.accentColor }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: 17
            font.weight: Font.Bold
            font.letterSpacing: 0.6
            color: Theme.textPrimary
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.sub
            font.family: Theme.fontFamily
            font.pixelSize: 13
            color: Theme.textMuted
            wrapMode: Text.WordWrap
            lineHeight: 1.45
            lineHeightMode: Text.ProportionalHeight
        }
        Icon {
            anchors.right: parent.right
            anchors.rightMargin: 2
            name: "ph-caret-right"
            size: 14
            color: Theme.textMuted
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 4
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: root.accentColor }
            GradientStop { position: 1.0; color: Theme.alpha(root.accentColor, 0) }
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

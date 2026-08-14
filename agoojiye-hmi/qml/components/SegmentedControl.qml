import QtQuick
import AgoojiyeHMI

// The pill-shaped multi-option segmented control (régénération, direction,
// traction, etc.) — matches the .seg row styling in the prototype.
Rectangle {
    id: root
    property var options: []
    property int currentIndex: 0
    property color accentColor: Theme.green
    signal selected(int index)

    height: 54
    radius: 12
    color: Theme.alpha(Theme.navBg, 0.8)

    Row {
        anchors.fill: parent
        anchors.margins: 5
        spacing: 6

        Repeater {
            model: root.options
            delegate: Rectangle {
                required property var modelData
                required property int index
                readonly property bool active: index === root.currentIndex
                width: (root.width - 10 - (root.options.length - 1) * 6) / root.options.length
                height: parent.height
                radius: 9
                color: active ? Theme.alpha(root.accentColor, 0.12) : "transparent"
                border.width: 1
                border.color: active ? root.accentColor : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: modelData
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: active ? "#d9f7e4" : Theme.textMuted
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selected(index)
                }
            }
        }
    }
}

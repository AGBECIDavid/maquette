import QtQuick
import AgoojiyeHMI

// The 52x29 pill switch used for ADAS toggles, spatial audio, auto time, etc.
Rectangle {
    id: root
    property bool checked: false
    property color accentColor: Theme.green
    signal toggled()

    width: 52
    height: 29
    radius: 15
    color: checked ? accentColor : Theme.dotInactive

    Behavior on color { ColorAnimation { duration: 150 } }

    Rectangle {
        width: 22
        height: 22
        radius: 11
        color: Theme.knob
        y: 3.5
        x: root.checked ? root.width - width - 3.5 : 3.5
        Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}

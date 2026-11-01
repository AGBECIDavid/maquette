import QtQuick
import AgoojiyeHMI

// Le détail d'un itinéraire, consigne par consigne. Avant le départ, chaque
// distance se compte depuis le départ ; en guidage, depuis la navette.
PanelCard {
    id: root
    radius: 18
    opaque: true

    property var steps: []
    property string title: "Étapes"
    property string subtitle: ""
    signal closed()

    Row {
        id: head
        x: 20; y: 18
        spacing: 12
        Rectangle {
            width: 40; height: 40; radius: 20
            color: backHover.containsMouse ? Theme.alpha(Theme.textMuted, 0.18) : "transparent"
            Icon { anchors.centerIn: parent; name: "ph-arrow-left"; size: 20; color: Theme.textPrimary }
            MouseArea { id: backHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closed() }
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            Text { text: root.title; font.family: Theme.fontFamily; font.pixelSize: 20; font.weight: Font.DemiBold; color: Theme.textPrimary }
            Text { visible: text !== ""; text: root.subtitle; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
        }
    }

    ListView {
        id: list
        x: 12
        anchors.top: head.bottom
        anchors.topMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: parent.width - 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.steps
        delegate: Item {
            width: list.width
            height: Math.max(58, txt.implicitHeight + 24)
            Rectangle {
                id: ic
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 38; height: 38; radius: 10
                color: index === 0 ? Theme.alpha(Theme.blue, 0.22) : Theme.alpha(Theme.textMuted, 0.12)
                Icon { anchors.centerIn: parent; name: modelData.icon; size: 20; color: index === 0 ? Theme.blueLight : Theme.textSecondary }
            }
            Text {
                id: txt
                anchors.left: ic.right
                anchors.leftMargin: 14
                anchors.right: d.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.text
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textPrimary
            }
            Text {
                id: d
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.distanceText
                font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.textMuted
            }
            Rectangle {
                visible: index < list.count - 1
                x: ic.x + ic.width / 2 - 0.5
                y: ic.y + ic.height + 2
                width: 1; height: parent.height - ic.height - 4
                color: Theme.alpha(Theme.textMuted, 0.2)
            }
        }
    }
}

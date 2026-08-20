import QtQuick
import AgoojiyeHMI

PanelCard {
    id: root
    property string iconName: ""
    property string label: ""
    property string sub: ""
    property color accentColor: Theme.blue
    // Statut vivant affiché en haut de la tuile. Vide = pas de badge.
    property string badge: ""
    // true pour ce qui demande une action (défaut, appel manqué, échéance).
    property bool badgeAlert: false
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

    // Badge d'état, aligné en haut à droite pour être lisible sans gêner l'icône.
    Rectangle {
        visible: root.badge.length > 0
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.rightMargin: 12
        width: badgeText.implicitWidth + 18
        height: 22
        radius: 11
        color: root.badgeAlert ? Theme.alpha(Theme.orange, 0.16)
                               : Theme.alpha(root.accentColor, 0.14)
        border.width: 1
        border.color: root.badgeAlert ? Theme.alpha(Theme.orange, 0.55)
                                      : Theme.alpha(root.accentColor, 0.45)
        Text {
            id: badgeText
            anchors.centerIn: parent
            text: root.badge
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.4
            color: root.badgeAlert ? Theme.orange : Theme.blueLighter
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

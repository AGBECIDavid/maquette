import QtQuick
import AgoojiyeHMI

// Barre de navigation permanente : les sept destinations de premier niveau,
// toujours au même endroit, toujours à un seul appui. Elle ne disparaît que
// pendant la séquence de démarrage.
Item {
    id: root
    height: 78
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Theme.alpha(Theme.blue, 0.12)
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.navBg, 0.7)
        z: -1
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: AppState.navItems

            delegate: Rectangle {
                id: navBtn
                required property var modelData
                height: 56
                // Chaque bouton se dimensionne sur son propre libellé : sept
                // cases de largeur égale gaspilleraient la place des courts.
                width: label.implicitWidth + icon.width + 12 + 36
                radius: 14
                color: modelData.active ? Theme.alpha(modelData.accent, 0.1) : (hover.containsMouse ? Theme.alpha(Theme.panelBgTop, 0.9) : "transparent")
                border.width: 1
                border.color: modelData.active ? modelData.accent : "transparent"

                // The selected tab reads as lit rather than merely outlined.
                Glow {
                    anchors.centerIn: parent
                    width: parent.width * 1.9
                    height: parent.height * 2.6
                    z: -1
                    visible: navBtn.modelData.active
                    glowColor: navBtn.modelData.accent
                    intensity: 0.34
                }

                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Icon { id: icon; name: navBtn.modelData.icon; size: 22; color: navBtn.modelData.active ? navBtn.modelData.accent : Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    Text {
                        id: label
                        text: navBtn.modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: navBtn.modelData.active ? navBtn.modelData.accent : Theme.textMuted
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: AppState.go(navBtn.modelData.key)
                }
            }
        }
    }
}

import QtQuick
import AgoojiyeHMI

// Curseur de niveau (luminosité, volume, balance…). `value` va de 0 à 1 ;
// `moved` est émis pendant le glissement, pas seulement au relâcher, pour que
// l'écran suive le doigt.
//
// La zone tactile déborde volontairement au-dessus et en dessous de la piste :
// 6 px de haut, ça se rate en roulant.
Item {
    id: root

    property real value: 0.5
    property color accentColor: Theme.blue
    signal moved(real value)

    height: 30
    implicitHeight: 30

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 6
        radius: 3
        color: Theme.trackBg

        Rectangle {
            width: Math.max(0, Math.min(1, root.value)) * parent.width
            height: parent.height
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.alpha(root.accentColor, 0.65) }
                GradientStop { position: 1.0; color: root.accentColor }
            }
        }
    }

    Rectangle {
        id: knob
        width: 18; height: 18; radius: 9
        color: Theme.knob
        border.width: 2
        border.color: root.accentColor
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(1, root.value)) * (track.width - width)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function apply(mx) {
            var span = track.width - knob.width
            if (span <= 0)
                return
            root.moved(Math.max(0, Math.min(1, (mx - knob.width / 2) / span)))
        }
        onPressed: (mouse) => apply(mouse.x)
        onPositionChanged: (mouse) => { if (pressed) apply(mouse.x) }
    }
}

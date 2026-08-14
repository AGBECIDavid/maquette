import QtQuick
import AgoojiyeHMI

// The translucent dark card used everywhere in the HMI:
// linear-gradient(180deg, rgba(16,24,40,.85), rgba(9,14,24,.9)) + 1px border.
//
// `elevated` adds a hairline highlight along the top edge. On a dark ground a
// lit rim reads as elevation far better than a drop shadow would, and unlike a
// blur it costs nothing on a software renderer.
Rectangle {
    id: root
    radius: 16
    color: "transparent"
    border.width: 1
    border.color: Theme.alpha(Theme.panelBorder, 0.14)

    // Large surfaces read as raised; compact list rows stay flat so the rim
    // highlight doesn't turn a dense list into stripes.
    property bool elevated: radius >= 16

    default property alias content: inner.data

    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { position: 0.0; color: Theme.panelGradTop }
        GradientStop { position: 1.0; color: Theme.panelGradBottom }
    }

    Rectangle {
        visible: root.elevated
        anchors.top: parent.top
        anchors.topMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width - root.radius * 1.6
        height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Theme.alpha(Theme.blueLighter, 0) }
            GradientStop { position: 0.5; color: Theme.alpha(Theme.blueLighter, 0.16) }
            GradientStop { position: 1.0; color: Theme.alpha(Theme.blueLighter, 0) }
        }
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}

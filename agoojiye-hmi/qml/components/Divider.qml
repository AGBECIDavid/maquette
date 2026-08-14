import QtQuick
import AgoojiyeHMI

// Thin rule that fades from muted to transparent, left-to-right.
Rectangle {
    height: 1
    color: "transparent"
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Theme.alpha(Theme.textMuted, 0.25) }
        GradientStop { position: 1.0; color: Theme.alpha(Theme.textMuted, 0) }
    }
}

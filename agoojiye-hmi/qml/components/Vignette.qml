import QtQuick
import AgoojiyeHMI

// Corner falloff over the whole display. Cheap depth cue that keeps the eye on
// the centre of the cluster, and it hides the seams where full-bleed artwork
// meets the frame. Canvas-painted, so no shader is required.
Canvas {
    id: root

    property color shade: "#000000"
    property real strength: 0.42
    // Fraction of the radius that stays completely clear.
    property real clearZone: 0.55

    onStrengthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0)
            return

        var cx = width / 2
        var cy = height / 2
        // Scale a circular gradient to the viewport so the falloff reaches the
        // corners of a wide screen at the same rate it reaches the sides.
        var r = Math.sqrt(cx * cx + cy * cy)
        var g = ctx.createRadialGradient(cx, cy, r * clearZone, cx, cy, r)
        var c = shade
        g.addColorStop(0, Qt.rgba(c.r, c.g, c.b, 0))
        g.addColorStop(0.65, Qt.rgba(c.r, c.g, c.b, strength * 0.35))
        g.addColorStop(1, Qt.rgba(c.r, c.g, c.b, strength))

        ctx.fillStyle = g
        ctx.fillRect(0, 0, width, height)
    }
}

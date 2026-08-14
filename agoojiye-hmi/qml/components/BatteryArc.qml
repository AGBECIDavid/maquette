import QtQuick
import AgoojiyeHMI

// The cluster's state-of-charge gauge: short segments swept along a shallow arc
// that bows left, a bright rail running down its outer edge and tick marks just
// outside the segments — the shape the reference cluster art uses. 0% sits at
// the bottom, 100% at the top.
//
// Painted on a Canvas so it survives software rendering, and repainted only
// when the charge or geometry actually changes.
//
// Geometry, all as fractions of `width`, laid out left to right at the arc's
// mid-height:  rail | ticks | segment band.  Sweeping the arc pushes everything
// right by `sagitta` at the top and bottom ends, so the widest point of the
// whole gauge is margin + sagitta + band.
Canvas {
    id: root

    property real value: 0.82          // 0..1 state of charge
    property int segments: 26
    property color fillColor: Theme.green
    property color fillColorBright: Theme.greenLight
    property color emptyColor: "#1b3b5c"
    property color railColor: Theme.blueLighter

    readonly property real margin: width * 0.11
    readonly property real band: width * 0.38     // radial length of a segment
    readonly property real sagitta: width * 0.38  // how far the arc bows out

    onValueChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (width <= 0 || height <= 0 || sagitta <= 0)
            return

        // Circle through the arc's two ends and its leftmost point.
        var halfChord = height / 2
        var radius = (sagitta * sagitta + halfChord * halfChord) / (2 * sagitta)
        var cx = radius + margin        // centre sits far off to the right
        var cy = height / 2
        var halfSweep = Math.asin(Math.min(1, halfChord / radius))

        // Larger radius => further left, so the segment band runs inward.
        var outerR = radius
        var innerR = radius - band
        var midR = (outerR + innerR) / 2
        var segH = (height / segments) * 0.60

        for (var i = 0; i < segments; i++) {
            // i = 0 at the bottom so the gauge fills upward.
            var t = (i + 0.5) / segments
            var a = Math.PI + halfSweep - 2 * halfSweep * t
            var cos = Math.cos(a), sin = Math.sin(a)

            ctx.save()
            ctx.translate(cx + cos * midR, cy + sin * midR)
            ctx.rotate(a)   // long axis follows the radius, so segments fan out
            if (t <= value) {
                var g = ctx.createLinearGradient(-band / 2, 0, band / 2, 0)
                g.addColorStop(0, fillColorBright)
                g.addColorStop(1, fillColor)
                ctx.fillStyle = g
            } else {
                ctx.fillStyle = emptyColor
            }
            ctx.fillRect(-band / 2, -segH / 2, band, segH)
            ctx.restore()

            // Tick marks just outside the band, every other segment.
            if (i % 2 === 0) {
                var tr = outerR + width * 0.045
                ctx.save()
                ctx.translate(cx + Math.cos(a) * tr, cy + Math.sin(a) * tr)
                ctx.rotate(a)
                ctx.fillStyle = Theme.alpha(Theme.textMuted, 0.5)
                ctx.fillRect(-width * 0.05, -0.75, width * 0.10, 1.5)
                ctx.restore()
            }
        }

        // Outer rail: a thin bright arc hugging the gauge, brightest at the ends.
        ctx.beginPath()
        ctx.arc(cx, cy, outerR + width * 0.10,
                Math.PI - halfSweep, Math.PI + halfSweep)
        var rg = ctx.createLinearGradient(0, 0, 0, height)
        rg.addColorStop(0, Theme.alpha(railColor, 0.8))
        rg.addColorStop(0.5, Theme.alpha(railColor, 0.25))
        rg.addColorStop(1, Theme.alpha(railColor, 0.8))
        ctx.strokeStyle = rg
        ctx.lineWidth = 2
        ctx.stroke()
    }
}

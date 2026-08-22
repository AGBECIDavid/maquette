import QtQuick

// Soft radial halo, painted on a Canvas so it works on software / lightweight
// renderers where shader-based blur effects are unavailable. Use it behind
// accent elements the way the night-theme reference art blooms around light
// sources (logo ring, active buttons, the speed readout).
Canvas {
    id: root

    // Halo tint. Alpha of this color is ignored; use `intensity` instead.
    property color glowColor: "#3b82f6"
    // Opacité au centre du halo (0..1).
    //
    // Le dégradé est peint UNE FOIS à pleine intensité, et `intensity` pilote
    // l'opacité de l'élément. Repeindre était le choix évident, et le mauvais :
    // sur l'écran de démarrage l'intensité s'anime pendant 2,6 s, ce qui
    // redessinait un Canvas de 900 × 420 px à chaque image — environ 150 fois,
    // au processeur, sur une cible sans accélération matérielle. Animer une
    // opacité ne coûte rien et donne exactement le même rendu.
    property real intensity: 0.45
    // Fraction of the radius that stays at full intensity before falling off.
    property real core: 0.0

    opacity: Math.max(0, Math.min(1, intensity))

    onGlowColorChanged: requestPaint()
    onCoreChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var cx = width / 2
        var cy = height / 2
        var r = Math.min(width, height) / 2
        if (r <= 0)
            return

        var g = ctx.createRadialGradient(cx, cy, 0, cx, cy, r)
        var c = glowColor
        function stop(pos, a) {
            g.addColorStop(pos, Qt.rgba(c.r, c.g, c.b, a))
        }
        stop(0.0, 1.0)
        if (core > 0 && core < 1)
            stop(core, 1.0)
        // Gaussian-ish falloff: a few stops read much softer than a linear ramp.
        var span = 1.0 - Math.max(0, Math.min(core, 0.95))
        stop(Math.min(core + span * 0.35, 0.99), 0.45)
        stop(Math.min(core + span * 0.65, 0.995), 0.15)
        stop(1.0, 0.0)

        ctx.fillStyle = g
        ctx.fillRect(0, 0, width, height)
    }
}

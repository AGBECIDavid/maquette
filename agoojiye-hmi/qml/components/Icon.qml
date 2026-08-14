import QtQuick
import "../Icons.js" as IconData

// Phosphor icon glyph. Mirrors the web prototype's <i class="ph ph-name">
// (regular) / <i class="ph-fill ph-name"> (fill) usage: pick a name from
// Icons.js and set `fill: true` for the filled weight.
Text {
    id: root
    property string name: ""
    property bool fill: false
    property real size: 20

    text: {
        var entry = IconData.codepoints[name]
        if (!entry) return ""
        var cp = fill ? (entry.fill || entry.regular) : entry.regular
        return cp || ""
    }
    font.family: fill ? "Phosphor-Fill" : "Phosphor"
    font.pixelSize: size
    color: "#ffffff"
    renderType: Text.NativeRendering
    antialiasing: true
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}

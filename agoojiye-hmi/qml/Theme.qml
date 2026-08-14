pragma Singleton
import QtQuick

QtObject {
    readonly property color bg: "#01030a"
    readonly property color frameBgTop: "#0b1424"
    readonly property color frameBgMid: "#04070f"
    readonly property color frameBgBottom: "#02040a"
    readonly property color frameBorder: "#1b2536"

    readonly property color blue: "#3b82f6"
    readonly property color blueLight: "#60a5fa"
    readonly property color blueLighter: "#93c5fd"
    readonly property color blueDeep: "#2563eb"
    readonly property color green: "#22c55e"
    readonly property color greenLight: "#4ade80"
    readonly property color purple: "#a78bfa"
    readonly property color purpleLight: "#c4b5fd"
    readonly property color orange: "#f59e0b"
    readonly property color yellow: "#eab308"
    readonly property color red: "#ef4444"
    readonly property color redDeep: "#dc2626"
    readonly property color teal: "#14b8a6"

    readonly property color textPrimary: "#eef2f8"
    readonly property color textBright: "#e6ebf4"
    readonly property color textSecondary: "#c3cee0"
    readonly property color textMuted: "#8b98ad"
    readonly property color textDim: "#aeb9cc"
    readonly property color knob: "#f2f5fa"

    readonly property color panelBgTop: "#101828"
    readonly property color panelBgBottom: "#090e18"
    readonly property color panelBorder: "#608cdc"
    readonly property color trackBg: "#0d1a2e"
    readonly property color dotInactive: "#2a3852"
    readonly property color navBg: "#04070f"

    // Pre-alpha'd stops for the translucent panel-card gradient used by PanelCard.
    readonly property color panelGradTop: Qt.rgba(0.063, 0.094, 0.157, 0.85)
    readonly property color panelGradBottom: Qt.rgba(0.035, 0.055, 0.094, 0.9)

    readonly property string fontFamily: "Inter"

    function alpha(c, a) {
        var col = Qt.color(c)
        return Qt.rgba(col.r, col.g, col.b, a)
    }
}

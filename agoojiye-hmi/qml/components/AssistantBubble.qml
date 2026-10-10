import QtQuick
import AgoojiyeHMI

// La conversation, par-dessus l'écran en cours.
//
// On parle à la navette depuis le tableau de bord, la carte ou la musique —
// pas depuis un écran dédié. Cette bulle apparaît au réveil et reste tant que
// la conversation vit : ce qui a été entendu, ce qui est répondu, et l'état
// de l'écoute. Elle ne prend jamais la main sur l'écran dessous : on continue
// de le voir, et le reste de l'interface reste utilisable.
//
// Dessin sans shader, comme le reste : un orbe dont l'anneau suit le niveau
// du micro, et qui respire pendant que le modèle réfléchit.
PanelCard {
    id: root

    readonly property var lastUser: _last("user")
    readonly property var lastReply: _last("assistant")

    function _last(role) {
        for (var i = Assistant.dialog.length - 1; i >= 0; i--)
            if (Assistant.dialog[i].role === role)
                return Assistant.dialog[i]
        return null
    }

    readonly property string statusLine: {
        if (Assistant.thinking) return "Je réfléchis…"
        if (VoiceListener.state === "hearing") return "J'écoute…"
        if (VoiceListener.state === "transcribing") return "Je transcris…"
        if (VoiceAnnouncer.speaking) return "Je réponds"
        if (VoiceCommands.pending !== null) return "Répondez « oui » ou « non »"
        if (Assistant.awake) return VoiceListener.state === "off"
                                    ? "Micro indisponible — écrivez dans Paramètres → Assistant vocal"
                                    : "Je vous écoute — parlez librement"
        return ""
    }

    width: 760
    height: 112
    radius: 20
    border.color: Theme.alpha(Theme.teal, 0.55)

    // Opaque, contrairement aux cartes : posée sur un écran, une bulle
    // translucide laisse son texte se mêler à celui de dessous, et une alerte
    // doit se lire d'un coup d'œil.
    gradient: Gradient {
        GradientStop { position: 0.0; color: Theme.panelBgTop }
        GradientStop { position: 1.0; color: Theme.panelBgBottom }
    }

    // Une annonce spontanée ne répond à rien : on n'affiche pas au-dessus la
    // dernière phrase du conducteur, qui semblerait l'avoir provoquée.
    readonly property bool announcing: lastReply !== null && lastReply.status === "alert"

    // ---- orbe ----------------------------------------------------------------
    Item {
        id: orb
        width: 64; height: 64
        x: 22
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            id: halo
            anchors.centerIn: parent
            width: 64; height: 64; radius: 32
            color: "transparent"
            border.width: 2
            border.color: Theme.alpha(Theme.teal, 0.25 + VoiceListener.level * 0.75)
            scale: 1 + VoiceListener.level * 0.25
            Behavior on scale { NumberAnimation { duration: 90 } }
        }
        Rectangle {
            id: core
            anchors.centerIn: parent
            width: 46; height: 46; radius: 23
            color: Theme.alpha(Theme.teal, 0.22)
            border.width: 1
            border.color: Theme.teal
            Icon {
                anchors.centerIn: parent
                name: Assistant.thinking ? "ph-waveform" : "ph-microphone"
                fill: true; size: 22; color: Theme.teal
            }
            SequentialAnimation on opacity {
                running: Assistant.thinking
                loops: Animation.Infinite
                NumberAnimation { to: 0.45; duration: 520; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutSine }
                onStopped: core.opacity = 1
            }
        }
    }

    // ---- texte -----------------------------------------------------------------
    Column {
        x: orb.x + orb.width + 20
        width: root.width - x - closeButton.width - 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            width: parent.width
            elide: Text.ElideRight
            visible: root.lastUser !== null || root.announcing
            text: root.announcing ? "ANNONCE"
                : root.lastUser !== null ? "« " + root.lastUser.text + " »" : ""
            font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted
        }
        Text {
            width: parent.width
            maximumLineCount: 2
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            text: root.lastReply !== null ? root.lastReply.text : "Bonjour, je suis " + Assistant.name + "."
            font.family: Theme.fontFamily; font.pixelSize: 18; font.weight: Font.Medium
            color: root.lastReply === null ? Theme.textPrimary
                 : root.lastReply.status === "alert" ? Theme.red
                 : root.lastReply.status === "refused" || root.lastReply.status === "unavailable" ? Theme.orange
                 : Theme.textPrimary
            lineHeight: 1.1
        }
        Text {
            text: root.statusLine
            visible: text !== ""
            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold
            font.letterSpacing: 0.6; color: Theme.teal
        }
    }

    // ---- fermer ----------------------------------------------------------------
    Rectangle {
        id: closeButton
        width: 34; height: 34; radius: 17
        anchors.right: parent.right; anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        color: closeHover.containsMouse ? Theme.alpha(Theme.textMuted, 0.18) : "transparent"
        Icon { anchors.centerIn: parent; name: "ph-x"; size: 16; color: Theme.textMuted }
        MouseArea {
            id: closeHover
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: Assistant.sleep()
        }
    }
}

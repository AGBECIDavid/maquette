import QtQuick
import AgoojiyeHMI

// Bandeau d'alerte, posé au-dessus de tous les écrans.
//
// C'est la seule chose de l'interface autorisée à s'imposer. Un témoin dans la
// barre du bas ne suffit pas : il n'est visible que sur le tableau de bord,
// alors qu'un frein de stationnement serré en roulant doit se voir même en
// train de régler la radio.
//
// Il prend sa place dans la colonne au lieu de se poser par-dessus : recouvrir
// un titre ou une commande à l'instant où le conducteur la cherche est pire que
// décaler l'écran. Sa hauteur s'anime, donc l'apparition reste un glissement.
//
// Trois niveaux, trois comportements :
//   CRITICAL  rouge, pulsation lente, ne se referme pas tant que la cause dure ;
//   WARNING   ambre, fixe, refermable ;
//   INFO      bleu, discret, refermable.
Item {
    id: root

    // Alerte masquée par l'utilisateur. Une nouvelle alerte, ou le retour de
    // celle-ci après disparition, rouvre le bandeau — on ne fait pas taire
    // définitivement une cause qui revient.
    property string dismissedId: ""

    readonly property var alert: VehicleData.topAlert
    readonly property bool critical: alert && alert.level === "CRITICAL"
    // Une alerte critique ne se masque pas : la sécurité prime sur le confort.
    readonly property bool shown:
        alert !== null && (critical || alert.id !== dismissedId)

    readonly property color accent: !alert ? Theme.blue
        : alert.level === "CRITICAL" ? Theme.red
        : alert.level === "WARNING" ? Theme.yellow
        : Theme.blue

    height: shown ? 74 : 0
    visible: height > 0
    clip: true
    Behavior on height { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 26
        anchors.rightMargin: 26
        anchors.topMargin: 8
        radius: 14
        color: Theme.alpha("#0a0f1c", 0.96)
        border.width: 2
        border.color: root.accent

        // Le fond porte la teinte du niveau, assez pour se lire d'un coup d'œil
        // sans noyer le texte.
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Theme.alpha(root.accent, 0.12)
        }

        // Pulsation réservée au critique : elle attire l'œil, donc elle doit
        // rester rare. Une alerte ambre qui clignote use l'attention pour rien.
        SequentialAnimation on opacity {
            running: root.critical && root.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.86; duration: 620; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: closeBtn.left
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 16

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: root.alert ? root.alert.icon : "ph-info"
                fill: true
                size: 30
                color: root.accent
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30 - 16 - countBadge.width - 16
                spacing: 2
                Text {
                    width: parent.width
                    text: root.alert ? root.alert.label : ""
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 19
                    font.weight: Font.Bold
                    color: Theme.textPrimary
                }
                Text {
                    width: parent.width
                    text: root.alert ? root.alert.detail : ""
                    elide: Text.ElideRight
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    color: Theme.textSecondary
                }
            }

            // Le nombre d'alertes en attente : sans lui, le conducteur croit
            // n'avoir qu'un problème alors qu'il en a trois.
            Rectangle {
                id: countBadge
                anchors.verticalCenter: parent.verticalCenter
                visible: VehicleData.activeAlerts.length > 1
                width: visible ? countText.implicitWidth + 20 : 0
                height: 26
                radius: 13
                color: Theme.alpha(root.accent, 0.25)
                border.width: 1
                border.color: root.accent
                Text {
                    id: countText
                    anchors.centerIn: parent
                    text: "+" + (VehicleData.activeAlerts.length - 1)
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Theme.textPrimary
                }
            }
        }

        // Zone tactile généreuse : 52 px de côté, ce qui reste atteignable en
        // roulant. Absente sur une alerte critique, qu'on ne masque pas.
        Rectangle {
            id: closeBtn
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? 52 : 0
            height: 52
            radius: 12
            visible: !root.critical
            color: closeHover.containsMouse ? Theme.alpha(root.accent, 0.2) : "transparent"
            Icon {
                anchors.centerIn: parent
                name: "ph-x"
                size: 20
                color: Theme.textSecondary
            }
            MouseArea {
                id: closeHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (root.alert) root.dismissedId = root.alert.id
            }
        }
    }
}

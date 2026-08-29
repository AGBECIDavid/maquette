import QtQuick
import AgoojiyeHMI

// Diagnostic de la chaîne haute tension.
//
// Cette couche s'ouvre quand la séquence de démarrage a refusé la mise en
// route. Elle couvre tout — barre du haut comprise — parce qu'à cet instant il
// n'y a rien d'autre à faire que lire ce qui ne va pas : afficher l'heure et le
// Bluetooth à côté d'un défaut d'isolement serait une invitation à l'ignorer.
//
// Les cinq organes sont tous montrés, pas seulement les fautifs. Un technicien
// a besoin de savoir ce qui a été vérifié, pas seulement ce qui a échoué : une
// liste de deux lignes rouges ne dit pas si les trois autres ont répondu ou
// n'ont jamais été interrogés.
Item {
    id: root

    signal dismissed()

    readonly property var chain: VehicleData.hvChain
    readonly property int faultCount: VehicleData.hvFaults.length
    readonly property bool blocking: VehicleData.hvBlocking

    // Relance du diagnostic. Elle n'efface rien : elle réinterroge. Un bouton
    // qui ferait disparaître un défaut sans que la cause ait changé serait un
    // mensonge — ici, tant que le défaut est là, il revient.
    property bool rescanning: false

    function rescan() {
        rescanning = true
        rescanTimer.restart()
    }

    Timer {
        id: rescanTimer
        interval: 1600
        onTriggered: {
            root.rescanning = false
            if (!VehicleData.hvFaultPresent)
                root.dismissed()
        }
    }

    // ---- fond --------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#1a0a0d" }
            GradientStop { position: 0.5; color: "#0d0509" }
            GradientStop { position: 1.0; color: "#050206" }
        }
    }

    // Halo rouge derrière l'en-tête : le seul écran de l'interface qui
    // n'utilise pas le bleu de marque, parce que ce n'est pas un écran de
    // marque.
    Glow {
        anchors.horizontalCenter: parent.horizontalCenter
        y: -160
        width: 1100; height: 520
        glowColor: Theme.red
        intensity: 0.22
    }

    // Rien ne passe au travers : la couche est un arrêt, pas une surimpression.
    MouseArea { anchors.fill: parent }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width - 120, 1180)
        spacing: 18

        // ---- en-tête -------------------------------------------------------
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20

            Item {
                width: 66; height: 66
                anchors.verticalCenter: parent.verticalCenter
                Rectangle {
                    anchors.fill: parent
                    radius: 20
                    color: Theme.alpha(Theme.red, 0.16)
                    border.width: 2
                    border.color: Theme.red
                }
                Icon {
                    anchors.centerIn: parent
                    name: "ph-warning-diamond"
                    fill: true
                    size: 34
                    color: Theme.red
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text {
                    text: "DÉFAUT HAUTE TENSION"
                    font.family: Theme.fontFamily
                    font.pixelSize: 30
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                    color: Theme.textPrimary
                }
                Text {
                    text: root.faultCount === 1
                          ? "1 organe de la chaîne ne répond pas"
                          : root.faultCount + " organes de la chaîne ne répondent pas"
                    font.family: Theme.fontFamily
                    font.pixelSize: 16
                    color: Theme.textSecondary
                }
            }
        }

        Item { width: 1; height: 6 }

        // ---- les cinq organes ----------------------------------------------
        Repeater {
            model: root.chain
            delegate: Rectangle {
                id: organ
                required property var modelData
                readonly property bool faulty: modelData.fault === 1

                width: parent.width
                height: 76
                radius: 14
                color: organ.faulty ? Theme.alpha(Theme.red, 0.1)
                              : Theme.alpha(Theme.panelBgTop, 0.55)
                border.width: organ.faulty ? 2 : 1
                border.color: organ.faulty ? Theme.red
                                     : Theme.alpha(Theme.panelBorder, 0.16)

                // Le contrôle en cours de relance : les lignes clignotent
                // doucement pour dire que la mesure est refaite, pas figée.
                opacity: root.rescanning ? 0.55 : 1
                Behavior on opacity { NumberAnimation { duration: 300 } }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: 22
                    anchors.rightMargin: 22

                    Rectangle {
                        id: badge
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        width: 46; height: 46; radius: 14
                        color: Theme.alpha(organ.faulty ? Theme.red : Theme.green, 0.14)
                        Icon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            size: 24
                            color: organ.faulty ? Theme.red : Theme.green
                        }
                    }

                    // ---- pastille d'état, à droite -------------------------
                    Rectangle {
                        id: statusPill
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: statusRow.implicitWidth + 30
                        height: 36
                        radius: 18
                        color: Theme.alpha(organ.faulty ? Theme.red : Theme.green, 0.16)
                        border.width: 1
                        border.color: organ.faulty ? Theme.red : Theme.green

                        Row {
                            id: statusRow
                            anchors.centerIn: parent
                            spacing: 9
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: organ.faulty ? "ph-x" : "ph-check-circle"
                                fill: true
                                size: 17
                                color: organ.faulty ? Theme.red : Theme.green
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: organ.faulty ? "EN DÉFAUT" : "CONFORME"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                                color: organ.faulty ? Theme.red : Theme.green
                            }
                        }
                    }

                    // Marque le défaut qui interdit de rouler : sans elle, un
                    // conducteur pressé essaierait de contourner celui-là comme
                    // les autres.
                    Rectangle {
                        id: lockTag
                        anchors.right: statusPill.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: organ.modelData.blocking && organ.faulty
                        width: visible ? lockText.implicitWidth + 22 : 0
                        height: 30
                        radius: 15
                        color: "transparent"
                        border.width: 1
                        border.color: Theme.alpha(Theme.red, 0.55)
                        Text {
                            id: lockText
                            anchors.centerIn: parent
                            text: "DÉMARRAGE INTERDIT"
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                            color: Theme.red
                        }
                    }

                    Column {
                        anchors.left: badge.right
                        anchors.leftMargin: 18
                        anchors.right: lockTag.visible ? lockTag.left : statusPill.left
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: modelData.label
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 18
                            font.weight: Font.DemiBold
                            color: organ.faulty ? Theme.textPrimary : Theme.textSecondary
                        }
                        Text {
                            width: parent.width
                            text: modelData.detail
                            elide: Text.ElideRight
                            font.family: Theme.fontFamily
                            font.pixelSize: 13
                            color: Theme.textMuted
                        }
                    }
                }
            }
        }

        Item { width: 1; height: 8 }

        // ---- consigne et actions -------------------------------------------
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.blocking
                  ? "Le circuit haute tension est en contact avec la caisse. La mise en route est refusée tant que le défaut persiste : faites intervenir un technicien habilité."
                  : "Le véhicule peut rouler, mais la puissance et l'autonomie ne sont pas garanties. Faites vérifier la chaîne dès que possible."
            font.family: Theme.fontFamily
            font.pixelSize: 15
            color: root.blocking ? Theme.red : Theme.textSecondary
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            topPadding: 6

            Rectangle {
                width: 260; height: 58; radius: 14
                color: rescanHover.containsMouse ? Theme.alpha(Theme.blue, 0.2)
                                                 : Theme.alpha(Theme.blue, 0.1)
                border.width: 1
                border.color: Theme.blue
                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "ph-arrows-clockwise"
                        size: 20
                        color: Theme.blueLight
                        RotationAnimation on rotation {
                            running: root.rescanning
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 900
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.rescanning ? "Diagnostic en cours…" : "Relancer le diagnostic"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: Theme.blueLight
                    }
                }
                MouseArea {
                    id: rescanHover
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.rescanning
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.rescan()
                }
            }

            // Absent sur un défaut bloquant. Un bouton grisé inviterait à
            // chercher comment l'activer ; mieux vaut qu'il n'existe pas.
            Rectangle {
                visible: !root.blocking
                width: visible ? 260 : 0
                height: 58; radius: 14
                color: contHover.containsMouse ? Theme.alpha(Theme.textMuted, 0.14) : "transparent"
                border.width: 1
                border.color: Theme.alpha(Theme.panelBorder, 0.4)
                Row {
                    anchors.centerIn: parent
                    spacing: 12
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Continuer malgré tout"
                        font.family: Theme.fontFamily
                        font.pixelSize: 16
                        font.weight: Font.Medium
                        color: Theme.textSecondary
                    }
                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: "ph-caret-right"
                        size: 16
                        color: Theme.textMuted
                    }
                }
                MouseArea {
                    id: contHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.dismissed()
                }
            }
        }
    }

    // Référence véhicule en pied de page : c'est le premier renseignement que
    // demandera l'assistance téléphonique.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        text: VehicleData.vehicleName + "  ·  " + VehicleData.vin
              + "  ·  logiciel " + VehicleData.softwareVersion
        font.family: Theme.fontFamily
        font.pixelSize: 13
        font.letterSpacing: 1
        color: Theme.textDim
    }
}

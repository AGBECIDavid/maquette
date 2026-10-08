import QtQuick
import AgoojiyeHMI

// Console d'essai de l'assistant vocal, sans micro.
//
// Une phrase tapée — ou touchée dans la liste — suit exactement le chemin
// d'une phrase reconnue : `VoiceCommands.handle()`. Ce que l'on voit ici est
// donc ce que fera l'assistant une fois le moteur de reconnaissance branché ;
// seule l'oreille manque.
//
// À gauche : saisie, état du véhicule (il décide des refus), échanges.
// À droite : tout ce que l'assistant comprend, et ce qu'il ne fera jamais.
Item {
    id: root

    readonly property real colW: (width - 22) / 2

    // Couleur et libellé d'un résultat, partagés par l'historique.
    function statusColor(s) {
        return { executed: Theme.green, noop: Theme.blueLight, confirm: Theme.orange,
                 cancelled: Theme.textMuted, refused: Theme.red, unknown: Theme.textMuted }[s]
               || Theme.textMuted
    }
    function statusLabel(s) {
        return { executed: "EXÉCUTÉE", noop: "DÉJÀ FAIT", confirm: "CONFIRMATION",
                 cancelled: "ANNULÉE", refused: "REFUSÉE", unknown: "NON COMPRISE" }[s] || s
    }

    function send(text) {
        if (String(text).trim() === "")
            return
        VoiceCommands.handle(text)
    }

    // Groupes dans l'ordre de la table, sans doublon.
    readonly property var groups: {
        var seen = []
        for (var i = 0; i < VoiceCommands.commands.length; i++) {
            var g = VoiceCommands.commands[i].group
            if (seen.indexOf(g) === -1)
                seen.push(g)
        }
        return seen
    }
    function commandsOf(group) {
        return VoiceCommands.commands.filter(function (c) { return c.group === group })
    }

    // ==== colonne gauche ======================================================
    // `leftCol` / `rightCol`, jamais `left` / `right` : tout Item possède déjà
    // des propriétés de ces noms (ses lignes d'ancrage), et elles masquent un
    // id. `right.width` lu dans un Flow renvoie alors l'ancre du Flow, la
    // largeur devient indéfinie, et le Flow cesse de passer à la ligne — sans
    // un seul avertissement.
    Column {
        id: leftCol
        width: root.colW
        height: root.height
        spacing: 12

        Column {
            width: parent.width
            spacing: 3
            Text { text: "ESSAI SANS MICRO"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted }
            Text {
                width: parent.width; wrapMode: Text.WordWrap
                text: "Chaque phrase suit le chemin d'une phrase reconnue. Accents et ponctuation sont facultatifs."
                font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted
            }
        }

        // ---- saisie ---------------------------------------------------------
        Rectangle {
            id: inputBar
            width: parent.width; height: 56; radius: 14
            color: Theme.alpha(Theme.panelBgTop, 0.9)
            border.width: 1
            border.color: input.activeFocus ? Theme.teal : Theme.alpha(Theme.panelBorder, 0.3)

            Icon {
                id: micIcon
                anchors.left: parent.left; anchors.leftMargin: 18
                anchors.verticalCenter: parent.verticalCenter
                name: "ph-microphone"; size: 21; color: Theme.teal
            }
            TextInput {
                id: input
                anchors.left: micIcon.right; anchors.leftMargin: 14
                anchors.right: sendButton.left; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.fontFamily; font.pixelSize: 16
                color: Theme.textPrimary
                selectionColor: Theme.alpha(Theme.teal, 0.4)
                clip: true
                onAccepted: { root.send(text); text = "" }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === "" && !input.activeFocus
                    text: "Tapez une commande, puis Entrée"
                    font: input.font; color: Theme.textMuted
                }
            }
            Rectangle {
                id: sendButton
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 10
                color: sendHover.containsMouse ? Theme.alpha(Theme.teal, 0.28) : Theme.alpha(Theme.teal, 0.16)
                Icon { anchors.centerIn: parent; name: "ph-waveform"; size: 20; color: Theme.teal }
                MouseArea {
                    id: sendHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { root.send(input.text); input.text = "" }
                }
            }
        }

        // ---- état du véhicule ----------------------------------------------
        // Affiché parce qu'il décide : une même phrase est exécutée à l'arrêt et
        // refusée en roulant. Sans ce bandeau, un refus aurait l'air d'un bug.
        Rectangle {
            id: stateStrip
            width: parent.width; height: 44; radius: 12
            readonly property color tone: VehicleData.moving ? Theme.orange : Theme.green
            color: Theme.alpha(tone, 0.08)
            border.width: 1; border.color: Theme.alpha(tone, 0.3)
            Row {
                anchors.left: parent.left; anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                Rectangle { width: 9; height: 9; radius: 4.5; color: stateStrip.tone; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: VehicleData.moving
                          ? "En roulage — " + VehicleData.reading("speed", VehicleData.speed, 0) + " km/h"
                          : "Navette à l'arrêt"
                    font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium; color: Theme.textPrimary
                }
            }
            Text {
                anchors.right: parent.right; anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: VehicleData.moving ? "Ouvertures refusées" : "Toutes les commandes permises"
                font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted
            }
        }

        // ---- question en attente -------------------------------------------
        // Les deux boutons envoient « oui » et « non » par le même chemin qu'une
        // réponse dite : il n'existe pas de confirmation qui contourne la table.
        Rectangle {
            width: parent.width
            height: VoiceCommands.pending !== null ? 64 : 0
            visible: height > 0
            radius: 12
            color: Theme.alpha(Theme.orange, 0.1)
            border.width: 1; border.color: Theme.alpha(Theme.orange, 0.5)
            Row {
                anchors.left: parent.left; anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Icon { name: "ph-question"; size: 22; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: VoiceCommands.pending !== null ? VoiceCommands.pending.ask : ""
                    font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary
                }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Repeater {
                    model: [ { word: "oui", c: Theme.green }, { word: "non", c: Theme.textMuted } ]
                    delegate: Rectangle {
                        required property var modelData
                        width: 70; height: 40; radius: 10
                        color: answerHover.containsMouse ? Theme.alpha(modelData.c, 0.28) : Theme.alpha(modelData.c, 0.14)
                        border.width: 1; border.color: Theme.alpha(modelData.c, 0.5)
                        Text { anchors.centerIn: parent; text: modelData.word.charAt(0).toUpperCase() + modelData.word.slice(1); font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        MouseArea { id: answerHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.send(modelData.word) }
                    }
                }
            }
        }

        // ---- échanges -------------------------------------------------------
        Text { text: "ÉCHANGES"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted; topPadding: 2 }

        Item {
            id: historyBox
            width: parent.width
            // Ce qui reste de la colonne entre les commandes et la carte du bas :
            // l'historique cède la place (question en attente, bandeau
            // d'alerte) plutôt que de pousser l'écran hors du cadre.
            height: Math.max(0, leftCol.height - y - forbiddenCard.height - leftCol.spacing)
            clip: true

            Text {
                visible: VoiceCommands.history.length === 0
                width: parent.width; wrapMode: Text.WordWrap
                text: "Aucun échange pour l'instant. Essayez «\u00a0mode sport\u00a0», puis «\u00a0oui\u00a0» — ou, en roulant, «\u00a0ouvre la trappe de charge\u00a0»."
                font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted
                lineHeight: 1.2
            }

            // Autant d'échanges qu'il en tient en entier : une carte coupée à
            // mi-hauteur se lit comme un défaut d'affichage, pas comme une suite.
            readonly property int fits: Math.max(0, Math.floor((height + 8) / (62 + 8)))

            Column {
                width: parent.width
                spacing: 8
                Repeater {
                    model: VoiceCommands.history.slice(0, historyBox.fits)
                    delegate: PanelCard {
                        id: exchange
                        required property var modelData
                        width: historyBox.width
                        height: 62; radius: 12
                        readonly property color tone: root.statusColor(modelData.status)
                        Rectangle { width: 3; height: parent.height - 18; radius: 1.5; color: exchange.tone; anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            x: 22; y: 10
                            width: parent.width - 22 - badge.width - 24
                            elide: Text.ElideRight
                            text: exchange.modelData.heard !== "" ? "« " + exchange.modelData.heard + " »" : "(délai écoulé)"
                            font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted
                        }
                        Text {
                            x: 22; y: 32
                            width: parent.width - 44
                            elide: Text.ElideRight
                            text: exchange.modelData.reply
                            font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; color: Theme.textPrimary
                        }
                        Rectangle {
                            id: badge
                            anchors.right: parent.right; anchors.rightMargin: 12; y: 9
                            width: badgeText.implicitWidth + 16; height: 20; radius: 10
                            color: Theme.alpha(exchange.tone, 0.15)
                            Text { id: badgeText; anchors.centerIn: parent; text: root.statusLabel(exchange.modelData.status); font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8; color: exchange.tone }
                        }
                    }
                }
            }
        }

        // ---- ce qui est exclu ----------------------------------------------
        // Lu dans la même source que la table : la liste affichée ne peut pas
        // promettre une exclusion que le code n'a pas faite.
        PanelCard {
            id: forbiddenCard
            width: parent.width
            height: forbiddenCol.implicitHeight + 24
            radius: 14
            border.color: Theme.alpha(Theme.red, 0.3)
            Column {
                id: forbiddenCol
                x: 18; y: 12
                width: parent.width - 36
                spacing: 6
                Row {
                    spacing: 8
                    Icon { name: "ph-prohibit"; size: 16; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "JAMAIS À LA VOIX — ABSENT DE LA TABLE"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                }
                Repeater {
                    model: VoiceCommands.forbidden
                    delegate: Item {
                        required property var modelData
                        width: forbiddenCol.width; height: 20
                        Text { anchors.left: parent.left; text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Medium; color: Theme.textPrimary }
                        Text { anchors.right: parent.right; text: modelData.why; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                    }
                }
            }
        }
    }

    // ==== colonne droite ======================================================
    Column {
        id: rightCol
        x: root.colW + 22
        width: root.colW
        height: root.height
        spacing: 10

        Column {
            width: parent.width
            spacing: 3
            Text { text: "CE QUE L'ASSISTANT COMPREND — " + VoiceCommands.commands.length + " COMMANDES"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted }
            Row {
                spacing: 16
                Text { text: "Touchez une phrase pour l'essayer."; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                Row { spacing: 5; Icon { name: "ph-question"; size: 13; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter } Text { text: "demande un oui"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted } }
                Row { spacing: 5; Icon { name: "ph-hand-palm"; size: 13; color: Theme.yellow; anchors.verticalCenter: parent.verticalCenter } Text { text: "à l'arrêt seulement"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted } }
            }
        }

        // Une ligne par groupe : le libellé du groupe ouvre la ligne, puis ses
        // phrases canoniques. Chaque pastille envoie sa phrase par `handle()`.
        // Le libellé tient sa propre colonne : à la ligne suivante, les
        // pastilles restent alignées sous les pastilles, pas sous le libellé.
        Repeater {
            model: root.groups
            delegate: Row {
                id: groupRow
                required property string modelData
                width: rightCol.width
                spacing: 6

                Text {
                    width: 82; height: 30
                    verticalAlignment: Text.AlignVCenter
                    text: groupRow.modelData.toUpperCase()
                    font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textMuted
                }
                Flow {
                    width: groupRow.width - 82 - groupRow.spacing
                    spacing: 6
                Repeater {
                    model: root.commandsOf(groupRow.modelData)
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        height: 30; radius: 15
                        width: chipRow.implicitWidth + 24
                        color: chipHover.containsMouse ? Theme.alpha(Theme.teal, 0.18) : Theme.alpha(Theme.panelBgTop, 0.9)
                        border.width: 1
                        border.color: chipHover.containsMouse ? Theme.alpha(Theme.teal, 0.6) : Theme.alpha(Theme.panelBorder, 0.22)
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 5
                            Icon { visible: chip.modelData.confirm === true; name: "ph-question"; size: 12; color: Theme.orange; anchors.verticalCenter: parent.verticalCenter }
                            Icon { visible: chip.modelData.stoppedOnly === true; name: "ph-hand-palm"; size: 12; color: Theme.yellow; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: chip.modelData.phrases[0]; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: chipHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.send(chip.modelData.phrases[0]) }
                    }
                }
                }
            }
        }

    }
}

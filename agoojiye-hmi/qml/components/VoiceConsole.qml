import QtQuick
import AgoojiyeHMI

// Page de l'assistant : la conversation en entier.
//
// À gauche, le fil — ce qui a été dit, ce qui a été répondu, et ce que la
// table a fait de chaque demande. On y écrit aussi : une phrase tapée suit le
// même chemin qu'une phrase dite (`Assistant.ask`), sans le mot de réveil,
// puisque taper est déjà une intention.
//
// À droite, ce qu'il faut pour que la conversation ait lieu : comment lui
// parler, et l'état des trois maillons — micro, reconnaissance, compréhension.
// En démonstration, c'est ce panneau qui explique un silence.
Item {
    id: root

    readonly property real leftW: Math.round((width - 22) * 0.58)
    readonly property real rightW: width - 22 - leftW

    function statusColor(s) {
        return { executed: Theme.green, noop: Theme.blueLight, confirm: Theme.orange,
                 cancelled: Theme.textMuted, refused: Theme.red, unknown: Theme.textMuted,
                 unavailable: Theme.orange, alert: Theme.red }[s]
               || Theme.textMuted
    }
    function statusLabel(s) {
        return { executed: "EXÉCUTÉ", noop: "DÉJÀ FAIT", confirm: "À CONFIRMER",
                 cancelled: "ANNULÉ", refused: "REFUSÉ", unknown: "NON COMPRIS",
                 unavailable: "NON DISPONIBLE", alert: "ALERTE" }[s] || ""
    }

    function send(text) {
        if (String(text).trim() === "")
            return
        Assistant.ask(text, "clavier")
    }

    // Phrases dites comme on les dit, pas comme la table les écrit : c'est le
    // modèle de langage qui fait le lien. La dernière montre un refus.
    readonly property var examples: [
        "Quelle est mon autonomie ?", "Mets un peu plus fort", "Passe en mode sport",
        "Il fait sombre, active le mode nuit", "Ouvre la trappe de charge", "Freine !"
    ]

    // ==== colonne gauche : le fil ============================================
    // `leftCol` / `rightCol`, jamais `left` / `right` : tout Item possède déjà
    // des propriétés de ces noms (ses lignes d'ancrage), et elles masquent un
    // id — un `right.width` lu dans un Flow y renvoie l'ancre du Flow, sans un
    // avertissement.
    Item {
        id: leftCol
        width: root.leftW
        height: root.height

        Row {
            id: header
            width: parent.width
            height: 26
            spacing: 10
            Text { text: "CONVERSATION"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
            Rectangle {
                visible: Assistant.awake || Assistant.thinking
                width: awakeLabel.implicitWidth + 18; height: 22; radius: 11
                color: Theme.alpha(Theme.teal, 0.16)
                anchors.verticalCenter: parent.verticalCenter
                Text { id: awakeLabel; anchors.centerIn: parent; text: Assistant.thinking ? "RÉFLÉCHIT" : "À L'ÉCOUTE"; font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8; color: Theme.teal }
            }
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: header.verticalCenter
            visible: Assistant.dialog.length > 0
            text: "Effacer"
            font.family: Theme.fontFamily; font.pixelSize: 13; color: clearHover.containsMouse ? Theme.textPrimary : Theme.textMuted
            MouseArea { id: clearHover; anchors.fill: parent; anchors.margins: -6; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Assistant.clear() }
        }

        // ---- fil -------------------------------------------------------------
        PanelCard {
            id: threadCard
            anchors.top: header.bottom; anchors.topMargin: 10
            anchors.bottom: bottomBlock.top; anchors.bottomMargin: 12
            width: parent.width
            radius: 16

            Text {
                visible: Assistant.dialog.length === 0
                anchors.centerIn: parent
                width: parent.width - 80
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Dites « Salut " + Assistant.name + " », puis ce que vous voulez — ou écrivez ci-dessous."
                font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.textMuted
                lineHeight: 1.25
            }

            ListView {
                id: thread
                anchors.fill: parent
                anchors.margins: 14
                clip: true
                spacing: 10
                model: Assistant.dialog
                // Le plus récent en bas, et toujours visible. La hauteur d'une
                // bulle n'est connue qu'après sa mise en page : suivre le nombre
                // d'éléments seul laissait la dernière à moitié coupée.
                onCountChanged: Qt.callLater(thread.positionViewAtEnd)
                onContentHeightChanged: Qt.callLater(thread.positionViewAtEnd)
                delegate: Item {
                    id: msg
                    required property var modelData
                    readonly property bool mine: modelData.role === "user"
                    readonly property string badge: mine ? "" : root.statusLabel(modelData.status)
                    width: thread.width
                    height: bubble.height

                    Rectangle {
                        id: bubble
                        width: Math.min(msg.width * 0.82, Math.max(bubbleText.implicitWidth, metaRow.visible ? metaRow.implicitWidth : 0) + 30)
                        height: bubbleCol.implicitHeight + 20
                        radius: 14
                        anchors.right: msg.mine ? parent.right : undefined
                        anchors.left: msg.mine ? undefined : parent.left
                        color: msg.mine ? Theme.alpha(Theme.teal, 0.16) : Theme.alpha(Theme.panelBgTop, 0.95)
                        border.width: 1
                        border.color: msg.mine ? Theme.alpha(Theme.teal, 0.4)
                                               : (msg.badge !== "" ? Theme.alpha(root.statusColor(msg.modelData.status), 0.45)
                                                                   : Theme.alpha(Theme.panelBorder, 0.2))
                        Column {
                            id: bubbleCol
                            x: 15; y: 10
                            width: bubble.width - 30
                            spacing: 5
                            Row {
                                id: metaRow
                                spacing: 6
                                visible: msg.mine ? msg.modelData.via === "voix" : msg.badge !== ""
                                Icon { visible: msg.mine; name: "ph-microphone"; size: 11; color: Theme.teal; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: msg.mine ? "dit" : msg.badge
                                    font.family: Theme.fontFamily; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 0.8
                                    color: msg.mine ? Theme.teal : root.statusColor(msg.modelData.status)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Text {
                                id: bubbleText
                                width: Math.min(implicitWidth, msg.width * 0.82 - 30)
                                wrapMode: Text.WordWrap
                                text: msg.modelData.text
                                font.family: Theme.fontFamily; font.pixelSize: 16
                                color: Theme.textPrimary
                                lineHeight: 1.15
                            }
                        }
                    }
                }
            }
        }

        // ---- bas : question, saisie, exemples ----------------------------------
        Column {
            id: bottomBlock
            anchors.bottom: parent.bottom
            width: parent.width
            spacing: 10

            Text {
                visible: Assistant.ignored !== ""
                width: parent.width
                elide: Text.ElideRight
                text: "Entendu sans « Salut " + Assistant.name + " », ignoré : " + Assistant.ignored
                font.family: Theme.fontFamily; font.pixelSize: 12; font.italic: true; color: Theme.textMuted
            }

            // Les deux boutons répondent par le même chemin qu'un « oui » dit :
            // il n'existe pas de confirmation qui contourne la table.
            Rectangle {
                width: parent.width
                height: VoiceCommands.pending !== null ? 58 : 0
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
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8
                    Repeater {
                        model: [ { word: "Oui", c: Theme.green }, { word: "Non", c: Theme.textMuted } ]
                        delegate: Rectangle {
                            required property var modelData
                            width: 66; height: 38; radius: 10
                            color: answerHover.containsMouse ? Theme.alpha(modelData.c, 0.28) : Theme.alpha(modelData.c, 0.14)
                            border.width: 1; border.color: Theme.alpha(modelData.c, 0.5)
                            Text { anchors.centerIn: parent; text: modelData.word; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary }
                            MouseArea { id: answerHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.send(modelData.word) }
                        }
                    }
                }
            }

            Rectangle {
                width: parent.width; height: 54; radius: 14
                color: Theme.alpha(Theme.panelBgTop, 0.9)
                border.width: 1
                border.color: input.activeFocus ? Theme.teal : Theme.alpha(Theme.panelBorder, 0.3)

                TextInput {
                    id: input
                    anchors.left: parent.left; anchors.leftMargin: 18
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
                        text: "Écrivez à " + Assistant.name + ", puis Entrée"
                        font: input.font; color: Theme.textMuted
                    }
                }
                Rectangle {
                    id: sendButton
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 40; height: 40; radius: 10
                    color: sendHover.containsMouse ? Theme.alpha(Theme.teal, 0.28) : Theme.alpha(Theme.teal, 0.16)
                    Icon { anchors.centerIn: parent; name: "ph-arrow-bend-up-right"; size: 19; color: Theme.teal }
                    MouseArea {
                        id: sendHover
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { root.send(input.text); input.text = "" }
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 6
                Repeater {
                    model: root.examples
                    delegate: Rectangle {
                        id: chip
                        required property string modelData
                        height: 30; radius: 15
                        width: chipText.implicitWidth + 24
                        color: chipHover.containsMouse ? Theme.alpha(Theme.teal, 0.18) : "transparent"
                        border.width: 1
                        border.color: chipHover.containsMouse ? Theme.alpha(Theme.teal, 0.6) : Theme.alpha(Theme.panelBorder, 0.22)
                        Text { id: chipText; anchors.centerIn: parent; text: chip.modelData; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textSecondary }
                        MouseArea { id: chipHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.send(chip.modelData) }
                    }
                }
            }
        }
    }

    // ==== colonne droite : comment, et avec quoi ===============================
    Column {
        id: rightCol
        x: root.leftW + 22
        width: root.rightW
        spacing: 12

        // ---- comment lui parler ----------------------------------------------
        PanelCard {
            width: parent.width
            height: howCol.implicitHeight + 28
            radius: 14
            Column {
                id: howCol
                x: 18; y: 14
                width: parent.width - 36
                spacing: 9
                Text { text: "COMMENT LUI PARLER"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.teal }
                Repeater {
                    model: [
                        { n: "1", t: "« Salut " + Assistant.name + " », puis votre demande — ou le bouton micro en haut à droite." },
                        { n: "2", t: "Parlez normalement : « il fait sombre, tu peux mettre le mode nuit ? »" },
                        { n: "3", t: "La conversation reste ouverte quelques secondes. Pour finir : « merci »." }
                    ]
                    delegate: Row {
                        required property var modelData
                        width: howCol.width
                        spacing: 10
                        Rectangle {
                            width: 22; height: 22; radius: 11
                            color: Theme.alpha(Theme.teal, 0.16)
                            Text { anchors.centerIn: parent; text: modelData.n; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold; color: Theme.teal }
                        }
                        Text { width: parent.width - 32; wrapMode: Text.WordWrap; text: modelData.t; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textSecondary; lineHeight: 1.15 }
                    }
                }
            }
        }

        // ---- les trois maillons ----------------------------------------------
        PanelCard {
            width: parent.width
            height: chainCol.implicitHeight + 28
            radius: 14
            Column {
                id: chainCol
                x: 18; y: 14
                width: parent.width - 36
                spacing: 10
                Text { text: "CE QUI EST PRÊT"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textMuted }
                Repeater {
                    model: [
                        // Trois causes distinctes, trois remèdes distincts : les
                        // confondre, c'est envoyer chercher au mauvais endroit.
                        { label: "Micro", ok: VoiceListener.micName !== "",
                          why: !VoiceListener.micCompiled ? "compilé sans Qt Multimedia : ./run.sh --clean"
                             : !VoiceListener.enabled ? "coupé"
                             : !VoiceListener.micAvailable ? "aucun micro trouvé par le système"
                             : VoiceListener.micName !== "" ? VoiceListener.micName
                             : "ouverture du micro…" },
                        { label: "Reconnaissance vocale", ok: VoiceListener.serverReady,
                          why: VoiceListener.serverReady ? "whisper — local" : "arrêtée : ./voice.sh start" },
                        { label: "Compréhension libre", ok: Assistant.modelReady,
                          why: Assistant.modelReady ? "modèle de langage — local" : "arrêtée : formules exactes seulement" }
                    ]
                    delegate: Item {
                        required property var modelData
                        width: chainCol.width; height: 22
                        Rectangle { width: 9; height: 9; radius: 4.5; color: modelData.ok ? Theme.green : Theme.orange; anchors.verticalCenter: parent.verticalCenter }
                        Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium; color: Theme.textPrimary }
                        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.why; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                    }
                }
                Item {
                    width: chainCol.width; height: 30
                    visible: VoiceListener.micCompiled
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Écoute du micro"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textSecondary }
                    ToggleSwitch {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        checked: VoiceListener.enabled; accentColor: Theme.teal
                        onToggled: VoiceListener.enabled = !VoiceListener.enabled
                    }
                }
            }
        }

        // ---- ce qui est exclu ------------------------------------------------
        // Lu dans la même source que la table : la liste affichée ne peut pas
        // promettre une exclusion que le code n'a pas faite. Le modèle de
        // langage n'y change rien — il ne peut désigner qu'une commande de la
        // table, et celles-ci n'y sont pas.
        PanelCard {
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
                    Text { text: "JAMAIS À LA VOIX"; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.red; anchors.verticalCenter: parent.verticalCenter }
                }
                Repeater {
                    model: VoiceCommands.forbidden
                    delegate: Text {
                        required property var modelData
                        width: forbiddenCol.width
                        elide: Text.ElideRight
                        text: modelData.label
                        font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textSecondary
                    }
                }
            }
        }
    }
}

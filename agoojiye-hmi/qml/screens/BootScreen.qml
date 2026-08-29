import QtQuick
import AgoojiyeHMI

// Séquence de démarrage.
//
// Elle contrôle d'abord la chaîne haute tension. Si elle répond, le véhicule
// approche sur une route qui défile, un assistant vocal souhaite la bienvenue,
// et la main passe au tableau de bord. Sinon la séquence s'arrête et ouvre le
// diagnostic haute tension.
//
// La chronologie tient dans les trois animations en fin de fichier —
// `bootIntro`, puis `bootRest` ou `abortSequence` selon l'issue du contrôle.
// Le rythme se règle là et nulle part ailleurs.
Item {
    id: root

    // La main se rend en deux temps : `handoff` révèle le tableau de bord
    // derrière la séquence, `finished` retire la séquence une fois effacée.
    signal handoff()
    signal finished()

    readonly property string welcomeLine:
        "Bienvenue sur " + VehicleData.vehicleName

    // Avancement du véhicule, 0 = au loin, 1 = au premier plan.
    property real approach: 0
    property real roadScroll: 0
    property bool assistantVisible: false
    property bool brandVisible: false

    // Émis quand la chaîne haute tension refuse la mise en route.
    signal hvFault()

    // ---- contrôles système -------------------------------------------------
    // Deux étapes, jouées dans l'ordre où un véhicule électrique les enchaîne :
    //
    //   1. « hv »    la chaîne haute tension — un verrou. Elle conditionne la
    //                mise sous tension, donc rien ne sert de vérifier le GPS
    //                tant qu'elle n'a pas répondu.
    //   2. « bord »  les systèmes de bord, informatifs.
    //
    // Les deux listes viennent de VehicleData : l'écran ne sait pas ce qu'il
    // vérifie, il sait seulement l'afficher.
    property string stage: "idle"      // idle | hv | bord | pret | defaut
    property int checkIndex: -1        // -1 = pas encore commencé
    property bool checksDone: false

    readonly property var checks:
        stage === "hv" ? VehicleData.hvChain
      : stage === "defaut" ? VehicleData.hvChain
      : VehicleData.startupChecks

    readonly property bool checksVisible: checkIndex >= 0 && !assistantVisible

    readonly property string stageTitle:
        stage === "defaut" ? "DÉFAUT HAUTE TENSION"
      : stage === "pret" ? "SYSTÈME VÉHICULE"
      : stage === "hv" ? "CONTRÔLE HAUTE TENSION"
      : "SYSTÈMES DE BORD"

    readonly property string currentCheck:
        checkIndex >= 0 && checkIndex < checks.length ? checks[checkIndex].label : ""

    // Un jalon est vert quand l'organe répond, rouge quand il est en défaut.
    // Les contrôles de bord portent `ok`, la chaîne haute tension porte `fault` :
    // les deux conventions se rejoignent ici, une seule fois.
    function checkPassed(entry) {
        return entry.fault !== undefined ? entry.fault === 0 : entry.ok
    }

    function beginStage(name) {
        stage = name
        checkIndex = 0
        checkLoop.start()
    }

    // Appelé quand la liste en cours est épuisée. C'est ici que la chaîne haute
    // tension décide si le véhicule a le droit de démarrer.
    function stageComplete() {
        if (stage === "hv") {
            if (VehicleData.hvFaultPresent) {
                stage = "defaut"
                abortSequence.start()
            } else {
                bootRest.start()
            }
        } else {
            stage = "pret"
            checksDone = true
        }
    }

    function skip() {
        bootIntro.stop()
        bootRest.stop()
        abortSequence.stop()
        checkLoop.stop()
        roadLoop.stop()
        VoiceAnnouncer.stop()

        // « Passer » saute la mise en scène, pas le contrôle de sécurité. Sans
        // cette vérification, un appui suffirait à franchir un défaut
        // d'isolement — et un verrou qu'un bouton contourne n'est pas un verrou.
        if (VehicleData.hvFaultPresent) {
            stage = "defaut"
            root.hvFault()
            return
        }

        root.handoff()
        root.finished()
    }

    Component.onCompleted: bootIntro.start()

    // ---- fond ------------------------------------------------------------
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0a1526" }
            GradientStop { position: 0.55; color: "#050a14" }
            GradientStop { position: 1.0; color: "#02040a" }
        }
    }

    // ---- route en fuite ---------------------------------------------------
    // Dessinée plutôt que photographiée : elle défile, donc elle doit être
    // paramétrable image par image.
    Canvas {
        id: road
        anchors.fill: parent
        opacity: 0.85
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var w = width, h = height
            var hy = h * 0.42                 // horizon
            var vx = w / 2
            var farHalf = w * 0.012
            var nearHalf = w * 0.75

            // Bandes latérales.
            ctx.strokeStyle = Qt.rgba(0.42, 0.60, 0.86, 0.5)
            ctx.lineWidth = 2
            for (var side = -1; side <= 1; side += 2) {
                ctx.beginPath()
                ctx.moveTo(vx + side * farHalf, hy)
                ctx.lineTo(vx + side * nearHalf, h)
                ctx.stroke()
            }

            // Pointillés centraux, décalés par roadScroll pour donner le
            // sentiment d'avancer.
            ctx.fillStyle = Qt.rgba(0.55, 0.72, 0.95, 0.55)
            var n = 14
            for (var i = 0; i < n; i++) {
                var base = (i + root.roadScroll) % n
                var t0 = Math.pow(base / n, 2.3)
                var t1 = Math.pow((base + 0.42) / n, 2.3)
                var y0 = hy + (h - hy) * t0
                var y1 = hy + (h - hy) * t1
                var half0 = farHalf + (nearHalf - farHalf) * t0
                var half1 = farHalf + (nearHalf - farHalf) * t1
                for (var lane = -1; lane <= 1; lane += 2) {
                    var wid0 = Math.max(0.6, 2 * t0 * 6)
                    var wid1 = Math.max(0.8, 2 * t1 * 6)
                    ctx.beginPath()
                    ctx.moveTo(vx + lane * 0.36 * half0 - wid0, y0)
                    ctx.lineTo(vx + lane * 0.36 * half0 + wid0, y0)
                    ctx.lineTo(vx + lane * 0.36 * half1 + wid1, y1)
                    ctx.lineTo(vx + lane * 0.36 * half1 - wid1, y1)
                    ctx.closePath()
                    ctx.fill()
                }
            }
        }
    }
    Timer {
        id: roadLoop
        interval: 40; running: true; repeat: true
        onTriggered: { root.roadScroll = (root.roadScroll + 0.16) % 14; road.requestPaint() }
    }

    // Halo d'horizon : la lumière vers laquelle on roule.
    Glow {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.42 - height / 2
        width: 900; height: 420
        glowColor: Theme.blue
        intensity: 0.20 + root.approach * 0.12
    }

    // ---- véhicule ---------------------------------------------------------
    Item {
        id: shuttle
        anchors.horizontalCenter: parent.horizontalCenter
        // Il grandit et descend : il vient vers nous. L'échelle finale s'arrête
        // avant que le véhicule ne touche la bulle de l'assistant.
        readonly property real s: 0.22 + root.approach * 0.78
        width: parent.width * 0.26 * s
        height: width * 0.88
        y: parent.height * 0.34 + parent.height * 0.26 * root.approach - height * 0.5
        opacity: Math.min(1, root.approach * 3.2)

        Glow {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: parent.height * 0.22
            width: parent.width * 1.5; height: parent.height * 1.1
            glowColor: Theme.blueDeep
            intensity: 0.34 * root.approach
        }
        ImageAsset {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: "qrc:/AgoojiyeHMI/assets/images/boot-shuttle.png"
        }
    }

    // ---- marque ------------------------------------------------------------
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.10
        spacing: 10
        opacity: root.brandVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 78; height: 78
            Glow {
                anchors.centerIn: parent
                width: 250; height: 250
                glowColor: Theme.blue
                intensity: 0.46
                core: 0.12
            }
            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Theme.alpha(Theme.blueDeep, 0.2)
                border.width: 3
                border.color: Theme.blueDeep
                Text {
                    anchors.centerIn: parent
                    text: VehicleData.vehicleName.charAt(0)
                    font.family: Theme.fontFamily; font.pixelSize: 36; font.weight: Font.Bold
                    color: Theme.blueLight
                }
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
                text: VehicleData.vehicleName.slice(0, 4)
                font.family: Theme.fontFamily; font.pixelSize: 30; font.weight: Font.Bold
                font.letterSpacing: 3
                color: Theme.textPrimary
            }
            Text {
                text: VehicleData.vehicleName.slice(4)
                font.family: Theme.fontFamily; font.pixelSize: 30; font.weight: Font.Bold
                font.letterSpacing: 3
                color: Theme.blue
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: VehicleData.vehicleModel
            font.family: Theme.fontFamily; font.pixelSize: 15; font.letterSpacing: 1.6
            color: Theme.textMuted
        }
    }

    // ---- contrôles système -------------------------------------------------
    // Occupe la place que la bulle de l'assistant prendra ensuite : le regard
    // n'a pas à se déplacer entre les deux étapes. Volontairement sobre — une
    // ligne, une barre de jalons — plutôt qu'un journal technique déroulant.
    Column {
        id: initBlock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 92
        spacing: 15
        opacity: root.checksVisible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.stageTitle
            font.family: Theme.fontFamily
            font.pixelSize: 13
            font.weight: Font.DemiBold
            font.letterSpacing: 3
            color: root.stage === "defaut" ? Theme.red : Theme.textMuted
        }

        // Un jalon par contrôle : l'avancement se lit sans lire.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6
            Repeater {
                model: root.checks
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: 30; height: 3; radius: 1.5
                    color: index > root.checkIndex ? Theme.alpha(Theme.textMuted, 0.22)
                                                   : (root.checkPassed(modelData) ? Theme.green : Theme.red)
                    Behavior on color { ColorAnimation { duration: 260 } }
                }
            }
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            // La coche ne prend sa place qu'une fois acquise, sinon le libellé
            // du contrôle en cours ne serait pas centré sous les jalons.
            spacing: (root.checksDone || root.stage === "defaut") ? 9 : 0
            Behavior on spacing { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

            Item {
                width: (root.checksDone || root.stage === "defaut") ? 20 : 0
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Icon {
                    anchors.centerIn: parent
                    name: root.stage === "defaut" ? "ph-warning-diamond" : "ph-check-circle"
                    fill: true
                    size: 20
                    color: root.stage === "defaut" ? Theme.red : Theme.green
                    opacity: (root.checksDone || root.stage === "defaut") ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 300 } }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.stage === "defaut" ? "Démarrage refusé"
                    : root.checksDone ? "Système prêt"
                    : root.currentCheck
                font.family: Theme.fontFamily
                font.pixelSize: 18
                font.weight: (root.checksDone || root.stage === "defaut") ? Font.DemiBold : Font.Normal
                color: root.stage === "defaut" ? Theme.red
                     : root.checksDone ? Theme.green
                     : Theme.textSecondary
            }
        }
    }

    // Fait avancer les contrôles un par un. Ce n'est pas une attente réelle :
    // quand le backend fournira les diagnostics, c'est lui qui cadencera
    // `checkIndex` et ce minuteur disparaîtra.
    Timer {
        id: checkLoop
        interval: 240
        repeat: true
        onTriggered: {
            if (root.checkIndex + 1 < root.checks.length)
                root.checkIndex++
            else {
                stop()
                root.stageComplete()
            }
        }
    }

    // ---- assistant vocal ---------------------------------------------------
    Item {
        id: assistant
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 74
        width: bubble.width
        height: bubble.height
        opacity: root.assistantVisible ? 1 : 0
        y: root.assistantVisible ? 0 : 20
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }

        Glow {
            anchors.centerIn: bubble
            width: bubble.width * 1.35; height: bubble.height * 3.2
            glowColor: Theme.blue
            intensity: 0.24
        }

        Rectangle {
            id: bubble
            width: bubbleRow.implicitWidth + 72
            height: 78
            radius: 39
            color: Theme.alpha("#0b1524", 0.9)
            border.width: 1
            border.color: Theme.alpha(Theme.blue, 0.4)

            Row {
                id: bubbleRow
                anchors.centerIn: parent
                spacing: 18

                // Onde sonore : elle s'anime tant que l'assistant "parle", ce qui
                // rend l'annonce lisible même sans synthèse vocale disponible.
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Repeater {
                        model: 5
                        delegate: Rectangle {
                            required property int index
                            width: 3
                            radius: 1.5
                            color: Theme.blueLight
                            anchors.verticalCenter: parent.verticalCenter
                            height: 8
                            SequentialAnimation on height {
                                running: root.assistantVisible
                                loops: Animation.Infinite
                                PauseAnimation { duration: index * 90 }
                                NumberAnimation { to: 26; duration: 320; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 8; duration: 320; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.welcomeLine
                    font.family: Theme.fontFamily
                    font.pixelSize: 25
                    font.weight: Font.Medium
                    color: Theme.textPrimary
                }
            }
        }
    }

    // ---- passer ------------------------------------------------------------
    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 26
        text: "Passer"
        font.family: Theme.fontFamily; font.pixelSize: 14; font.letterSpacing: 1
        // Masqué pendant le contrôle haute tension et sur son échec : proposer
        // de « passer » un verrou de sécurité serait une invitation à le forcer.
        visible: root.stage !== "hv" && root.stage !== "defaut"
        color: skipHover.containsMouse ? Theme.textPrimary : Theme.textDim
        MouseArea {
            id: skipHover
            anchors.fill: parent
            anchors.margins: -14
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.skip()
        }
    }

    // ---- chronologie -------------------------------------------------------
    // Trois animations plutôt qu'une : la chaîne haute tension décide, au
    // milieu, si la suite a lieu. Une seule séquentielle aurait dû s'arrêter
    // elle-même en cours d'exécution, ce qui est fragile ; ici chaque issue a
    // sa propre suite, et l'aiguillage tient dans `stageComplete()`.

    // 1. Marque, puis contrôle de la chaîne haute tension.
    SequentialAnimation {
        id: bootIntro
        ScriptAction { script: root.brandVisible = true }
        PauseAnimation { duration: 550 }
        ScriptAction { script: root.beginStage("hv") }
    }

    // 2a. Chaîne saine : le véhicule approche pendant les contrôles de bord.
    //     L'attente technique se passe derrière une image, pas devant un écran
    //     figé.
    SequentialAnimation {
        id: bootRest

        ParallelAnimation {
            ScriptAction { script: root.beginStage("bord") }
            NumberAnimation {
                target: root; property: "approach"
                from: 0; to: 1
                duration: 2600
                easing.type: Easing.InOutCubic
            }
        }

        // « Système prêt » a le temps d'être lu.
        PauseAnimation { duration: 850 }

        // L'assistant salue.
        ScriptAction {
            script: {
                root.assistantVisible = true
                VoiceAnnouncer.speak(root.welcomeLine)
            }
        }
        PauseAnimation { duration: 2600 }

        // Passage au tableau de bord. Il se révèle *pendant* le fondu de la
        // séquence, pas après : les deux se croisent, la bascule ne se voit pas
        // comme une coupure.
        ScriptAction { script: root.handoff() }
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "opacity"
                to: 0; duration: 620; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root; property: "scale"
                to: 1.04; duration: 620; easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: {
                roadLoop.stop()
                root.finished()
            }
        }
    }

    // 2b. Chaîne en défaut : la séquence s'arrête là. Pas d'approche du
    //     véhicule, pas de « bienvenue » — une navette dont l'isolement haute
    //     tension est douteux n'accueille personne, elle refuse de démarrer.
    SequentialAnimation {
        id: abortSequence

        // Le refus a le temps d'être lu avant que le diagnostic ne s'ouvre.
        PauseAnimation { duration: 1400 }
        NumberAnimation {
            target: root; property: "opacity"
            to: 0; duration: 420; easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                roadLoop.stop()
                VoiceAnnouncer.stop()
                root.hvFault()
            }
        }
    }
}

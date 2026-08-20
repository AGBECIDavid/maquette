import QtQuick
import AgoojiyeHMI

// Séquence de démarrage. Le véhicule approche sur une route qui défile, un
// assistant vocal souhaite la bienvenue, puis la main passe automatiquement au
// tableau de bord.
//
// Toute la chronologie tient dans `timeline` ci-dessous : une seule animation
// séquentielle, pour que le rythme se lise et se règle d'un seul endroit.
Item {
    id: root

    // Émis quand la séquence est terminée (ou écourtée par l'utilisateur).
    signal finished()

    readonly property string welcomeLine:
        "Bienvenue sur " + VehicleData.vehicleName

    // Avancement du véhicule, 0 = au loin, 1 = au premier plan.
    property real approach: 0
    property real roadScroll: 0
    property bool assistantVisible: false
    property bool brandVisible: false

    function skip() {
        timeline.stop()
        roadLoop.stop()
        VoiceAnnouncer.stop()
        root.finished()
    }

    Component.onCompleted: timeline.start()

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
    SequentialAnimation {
        id: timeline

        // 1. La marque apparaît.
        ScriptAction { script: root.brandVisible = true }
        PauseAnimation { duration: 550 }

        // 2. Le véhicule approche.
        NumberAnimation {
            target: root; property: "approach"
            from: 0; to: 1
            duration: 2600
            easing.type: Easing.InOutCubic
        }

        // 3. L'assistant salue.
        ScriptAction {
            script: {
                root.assistantVisible = true
                VoiceAnnouncer.speak(root.welcomeLine)
            }
        }
        PauseAnimation { duration: 2900 }

        // 4. Fondu et passage au tableau de bord.
        NumberAnimation {
            target: root; property: "opacity"
            to: 0; duration: 600; easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                roadLoop.stop()
                root.finished()
            }
        }
    }
}

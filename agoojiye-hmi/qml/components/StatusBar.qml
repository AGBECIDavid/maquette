import QtQuick
import QtQuick.Shapes
import AgoojiyeHMI

// Bandeau permanent. Il ne change jamais d'un écran à l'autre : c'est là que
// vivent les informations que le conducteur doit pouvoir lire sans réfléchir —
// heure, température, vitesse, rapport engagé, batterie, connectivité.
Item {
    id: root
    height: 66
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: Theme.alpha(Theme.blue, 0.1)
    }

    // Left cluster: temperature + clock
    Row {
        anchors.left: parent.left
        anchors.leftMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 16

        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
            Icon { name: "ph-thermometer-simple"; size: 20; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
            Text { text: VehicleData.outsideTemp + "°C"; font.family: Theme.fontFamily; font.pixelSize: 19; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle { width: 1; height: 24; color: Theme.alpha(Theme.textMuted, 0.3); anchors.verticalCenter: parent.verticalCenter }
        Row {
            spacing: 8
            anchors.verticalCenter: parent.verticalCenter
            Icon { name: "ph-clock"; size: 20; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: AppState.time
                font.family: Theme.fontFamily
                font.pixelSize: 19
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        // La vitesse suit le conducteur hors du tableau de bord, où le grand
        // compteur ne l'accompagne plus.
        Rectangle {
            width: 1; height: 24; color: Theme.alpha(Theme.textMuted, 0.3)
            anchors.verticalCenter: parent.verticalCenter
            visible: AppState.screen !== "dash"
        }
        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter
            visible: AppState.screen !== "dash"
            Text { text: VehicleData.reading("speed", Math.round(VehicleData.speed)); font.family: Theme.fontFamily; font.pixelSize: 21; font.weight: Font.Bold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "km/h"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    // ---- clignotants ---------------------------------------------------------
    // De part et d'autre du rapport engagé, dans le bandeau permanent : un
    // clignotant oublié doit se voir depuis n'importe quel écran. Éteints, ils
    // restent esquissés à leur place ; allumés, ils battent au rythme d'un
    // relais (~1,4 Hz). Un appui les commande, à défaut de comodo en démo.
    property bool blinkOn: true
    Timer {
        interval: 360
        repeat: true
        running: VehicleData.turnSignal !== "off"
        onRunningChanged: root.blinkOn = true
        onTriggered: root.blinkOn = !root.blinkOn
    }

    Repeater {
        model: [ { side: "left", icon: "ph-arrow-fat-left", dx: -1 },
                 { side: "right", icon: "ph-arrow-fat-right", dx: 1 } ]
        delegate: Item {
            id: arrow
            required property var modelData
            readonly property bool lit: VehicleData.turnSignal === modelData.side
                                        || VehicleData.turnSignal === "hazard"
            width: 44; height: 44
            anchors.verticalCenter: parent.verticalCenter
            x: root.width / 2 + modelData.dx * (notch.width / 2 + 38) - width / 2
            Icon {
                anchors.centerIn: parent
                name: arrow.modelData.icon
                fill: arrow.lit
                size: 30
                color: arrow.lit ? (root.blinkOn ? Theme.green : Theme.alpha(Theme.green, 0.12))
                                 : Theme.alpha(Theme.textMuted, 0.22)
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: VehicleData.turnSignal =
                    VehicleData.turnSignal === arrow.modelData.side ? "off" : arrow.modelData.side
            }
        }
    }

    // Center notch: a tab hanging from the top edge, rounded only at the
    // bottom two corners (CSS border-radius: 0 0 26px 26px; border-top: none).
    Item {
        id: notch
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: 250
        height: 60
        property real r: 26

        Shape {
            anchors.fill: parent

            ShapePath {
                fillColor: "#08101f"
                strokeWidth: -1
                startX: 0; startY: 0
                PathLine { x: notch.width; y: 0 }
                PathLine { x: notch.width; y: notch.height - notch.r }
                PathArc { x: notch.width - notch.r; y: notch.height; radiusX: notch.r; radiusY: notch.r }
                PathLine { x: notch.r; y: notch.height }
                PathArc { x: 0; y: notch.height - notch.r; radiusX: notch.r; radiusY: notch.r }
                PathLine { x: 0; y: 0 }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: Theme.alpha(Theme.blue, 0.22)
                strokeWidth: 1
                capStyle: ShapePath.FlatCap
                startX: 0; startY: 0
                PathLine { x: 0; y: notch.height - notch.r }
                PathArc { x: notch.r; y: notch.height; radiusX: notch.r; radiusY: notch.r }
                PathLine { x: notch.width - notch.r; y: notch.height }
                PathArc { x: notch.width; y: notch.height - notch.r; radiusX: notch.r; radiusY: notch.r }
                PathLine { x: notch.width; y: 0 }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0
            Text { text: VehicleData.driveGear; anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontFamily; font.pixelSize: 21; font.weight: Font.Bold; color: Theme.textPrimary }
            Text { text: VehicleData.systemReady ? "READY" : "STANDBY"; anchors.horizontalCenter: parent.horizontalCenter; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.green }
        }
    }

    // Right cluster
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 30
        anchors.verticalCenter: parent.verticalCenter
        spacing: 18

        Rectangle {
            width: 36; height: 36; radius: 18
            color: "#f4f6fb"
            border.width: 4
            border.color: Theme.redDeep
            anchors.verticalCenter: parent.verticalCenter
            Text { anchors.centerIn: parent; text: VehicleData.speedLimit; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; color: "#0b1020" }
        }
        // Témoins d'éclairage et de visibilité, comme au combiné : le témoin des
        // phares dit leur réglage ; les autres n'apparaissent qu'actifs. Bleu
        // pour les feux de route, comme partout.
        Row {
            spacing: 5
            anchors.verticalCenter: parent.verticalCenter
            Icon {
                name: "ph-headlights"; size: 22; fill: VehicleData.headlightsLit
                color: VehicleData.highBeam ? Theme.blue
                     : VehicleData.headlightsLit ? Theme.green
                     : VehicleData.headlights === "auto" ? Theme.green : Theme.textDim
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: VehicleData.highBeam ? "ROUTE" : ({ off: "OFF", auto: "AUTO", on: "ON" })[VehicleData.headlights]
                font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.DemiBold
                color: VehicleData.highBeam ? Theme.blue : VehicleData.headlights === "off" ? Theme.textDim : Theme.green
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Icon { visible: VehicleData.fogLights; name: "ph-cloud-fog"; size: 21; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
        Icon { visible: VehicleData.wipers !== "off" || VehicleData.washing; name: VehicleData.washing ? "ph-spray-bottle" : "ph-cloud-rain"
               size: 21; color: Theme.teal; anchors.verticalCenter: parent.verticalCenter }
        Icon { visible: VehicleData.cabinLight; name: "ph-lightbulb"; size: 20; color: Theme.yellow; anchors.verticalCenter: parent.verticalCenter }
        // La charge restante ne doit jamais dépendre de l'écran ouvert.
        Row {
            spacing: 7
            anchors.verticalCenter: parent.verticalCenter
            Icon {
                name: VehicleData.charging ? "ph-battery-charging" : "ph-battery-high"
                fill: true; size: 22
                color: VehicleData.batteryLevel <= 15 ? Theme.red : Theme.green
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: VehicleData.reading("battery", VehicleData.batteryLevel) + (VehicleData.valid("battery") ? "%" : "")
                font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold
                color: VehicleData.batteryLevel <= 15 ? Theme.red : Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Icon { name: "ph-bluetooth"; size: 20; color: VehicleData.bluetoothConnected ? Theme.blue : Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
        Row {
            spacing: 4
            anchors.verticalCenter: parent.verticalCenter
            Text { text: VehicleData.network; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            Icon { name: "ph-cell-signal-full"; size: 19; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
        }
        Icon { name: "ph-wifi-high"; size: 20; color: VehicleData.wifiConnected ? Theme.textSecondary : Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
        // Appui-pour-parler. Équivaut à « Salut Agoojiye » : dans le vent d'une
        // navette ouverte, un bouton ne se déclenche jamais tout seul et ne
        // confond pas une conversation de passagers avec un ordre. Rappuyer
        // clôt la conversation. L'anneau suit le niveau du micro : on voit
        // qu'il entend avant même de parler.
        Rectangle {
            id: micButton
            readonly property bool active: Assistant.awake || Assistant.thinking
            width: 40; height: 40; radius: 20
            anchors.verticalCenter: parent.verticalCenter
            color: active ? Theme.alpha(Theme.teal, 0.2)
                          : (micHover.containsMouse ? Theme.alpha(Theme.panelBgTop, 0.9) : "transparent")
            border.width: 1
            border.color: active ? Theme.teal : Theme.alpha(Theme.teal, 0.25 + VoiceListener.level * 0.75)

            Icon {
                anchors.centerIn: parent
                name: "ph-microphone"
                fill: micButton.active
                size: 21
                color: micButton.active ? Theme.teal
                                        : (VoiceListener.state === "off" ? Theme.textDim : Theme.textSecondary)
            }
            MouseArea {
                id: micHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: micButton.active ? Assistant.sleep() : Assistant.wake()
            }
        }
        // Tiroir d'applications. Les sept destinations principales sont dans la
        // barre du bas ; ce bouton ouvre le reste (téléphone, entretien,
        // à propos) sans encombrer la barre.
        Rectangle {
            width: 40; height: 40; radius: 12
            anchors.verticalCenter: parent.verticalCenter
            color: AppState.menuOpen ? Theme.alpha(Theme.blue, 0.14)
                                     : (menuHover.containsMouse ? Theme.alpha(Theme.panelBgTop, 0.9) : "transparent")
            border.width: 1
            border.color: AppState.menuOpen ? Theme.blue : "transparent"

            Icon {
                anchors.centerIn: parent
                name: "ph-squares-four"
                size: 24
                color: AppState.menuOpen ? Theme.blue
                                         : (menuHover.containsMouse ? Theme.textPrimary : Theme.textMuted)
            }
            MouseArea {
                id: menuHover
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // Rappuyer referme le tiroir sur l'écran d'où l'on venait.
                onClicked: AppState.menuOpen ? AppState.back() : AppState.go("menu")
            }
        }
    }
}

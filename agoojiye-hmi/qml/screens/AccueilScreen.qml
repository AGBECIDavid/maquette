import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property var leftCards: [
        { icon: "ph-shield-check", label: "Sécurité", desc: "Votre sécurité est notre priorité.", color: Theme.blue },
        { icon: "ph-leaf", label: "Efficience", desc: "Conduisez plus loin, consommez moins.", color: Theme.green }
    ]
    readonly property var rightCards: [
        { icon: "ph-hand-tap", label: "Intuitif", desc: "Une interface simple, claire et moderne.", color: Theme.purple },
        { icon: "ph-gear-six", label: "Personnalisable", desc: "Réglez et personnalisez votre expérience de conduite.", color: Theme.blue }
    ]

    component FeatureCard: PanelCard {
        property string iconName: ""
        property string label: ""
        property string desc: ""
        property color accentColor: Theme.blue
        height: 168

        Column {
            anchors.centerIn: parent
            width: parent.width - 44
            spacing: 10

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 70; height: 70; radius: 35
                color: Theme.alpha(accentColor, 0.1)
                border.width: 2
                border.color: accentColor
                Icon { anchors.centerIn: parent; name: iconName; size: 32; color: accentColor }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: label
                font.family: Theme.fontFamily; font.pixelSize: 20; font.weight: Font.DemiBold
                color: Theme.textPrimary
            }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 30; height: 3; radius: 2; color: accentColor }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: desc
                wrapMode: Text.WordWrap
                font.family: Theme.fontFamily; font.pixelSize: 14
                color: Theme.textMuted
                lineHeight: 1.5
                lineHeightMode: Text.ProportionalHeight
            }
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 0
        anchors.topMargin: 24
        anchors.bottomMargin: 24
        anchors.leftMargin: 40
        anchors.rightMargin: 40
        spacing: 30

        Column {
            width: 290
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24
            Repeater {
                model: root.leftCards
                delegate: FeatureCard {
                    width: 290
                    iconName: modelData.icon; label: modelData.label; desc: modelData.desc; accentColor: modelData.color
                }
            }
        }

        Column {
            width: parent.width - 290 - 290 - 60
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 74; height: 74

                Glow {
                    anchors.centerIn: parent
                    width: 230; height: 230
                    glowColor: Theme.blue
                    intensity: 0.42
                    core: 0.12
                }
                Rectangle {
                    anchors.fill: parent
                    radius: 37
                    color: "transparent"
                    border.width: 3
                    border.color: Theme.blueDeep
                    Rectangle {
                        anchors.fill: parent
                        radius: 37
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.alpha(Theme.blueDeep, 0.25) }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                    }
                    Text { anchors.centerIn: parent; text: "A"; font.family: Theme.fontFamily; font.pixelSize: 34; font.weight: Font.Bold; color: Theme.blueLight }
                }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Bienvenue"; font.family: Theme.fontFamily; font.pixelSize: 44; font.weight: Font.Bold; font.letterSpacing: -0.4; color: Theme.textPrimary; topPadding: 8 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "dans votre " + VehicleData.vehicleModel.toLowerCase(); font.family: Theme.fontFamily; font.pixelSize: 19; color: Theme.textDim }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                topPadding: 6
                // Le nom se scinde en deux teintes : début neutre, fin en accent.
                Text { text: VehicleData.vehicleName.slice(0, 4); font.family: Theme.fontFamily; font.pixelSize: 23; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textPrimary }
                Text { text: VehicleData.vehicleName.slice(4); font.family: Theme.fontFamily; font.pixelSize: 23; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.blue }
            }

            // Hero vehicle, dissolved into the page: the reference art has the
            // car emerging out of the night rather than sitting in a frame.
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 660; height: 250

                Glow {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 30
                    width: parent.width * 1.05; height: parent.height * 1.15
                    glowColor: Theme.blueDeep
                    intensity: 0.30
                }
                ImageAsset {
                    anchors.fill: parent
                    source: "qrc:/AgoojiyeHMI/assets/images/hero-car.png"
                }
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 330; height: 60

                Glow {
                    anchors.centerIn: parent
                    width: 460; height: 150
                    glowColor: Theme.blueDeep
                    intensity: startHover.containsMouse ? 0.45 : 0.30
                    Behavior on intensity { NumberAnimation { duration: 160 } }
                }
                Rectangle {
                    id: startBtn
                    anchors.fill: parent
                    radius: 14
                    color: startHover.containsMouse ? Theme.alpha(Theme.blue, 0.2) : Theme.alpha(Theme.blue, 0.1)
                    border.width: 1
                    border.color: Theme.blue

                    Row {
                        anchors.centerIn: parent
                        spacing: 12
                        // Le libellé suit l'état réel : on ne propose de partir
                        // que si le véhicule est prêt.
                        Text {
                            text: VehicleData.systemReady ? "Démarrer" : "Préparation…"
                            font.family: Theme.fontFamily; font.pixelSize: 21; font.weight: Font.DemiBold
                            color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Icon {
                            visible: VehicleData.systemReady
                            name: "ph-caret-right"; size: 20; color: Theme.textPrimary
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea { id: startHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: AppState.go("dash") }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                topPadding: 12
                Repeater {
                    model: 4
                    delegate: Rectangle {
                        required property int index
                        width: 9; height: 9; radius: 4.5
                        color: index === 0 ? Theme.blue : Theme.dotInactive
                    }
                }
            }
        }

        Column {
            width: 290
            anchors.verticalCenter: parent.verticalCenter
            spacing: 24
            Repeater {
                model: root.rightCards
                delegate: FeatureCard {
                    width: 290
                    iconName: modelData.icon; label: modelData.label; desc: modelData.desc; accentColor: modelData.color
                }
            }
        }
    }
}

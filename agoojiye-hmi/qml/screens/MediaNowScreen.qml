import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property var sideItems: [
        { label: "Lecture en cours", icon: "ph-music-note", active: true, go: "" },
        { label: "Ma bibliothèque", icon: "ph-books", active: false, go: "media" },
        { label: "Playlists", icon: "ph-queue", active: false, go: "" },
        { label: "Radio", icon: "ph-radio", active: false, go: "" },
        { label: "Bluetooth", icon: "ph-bluetooth", active: false, go: "" },
        { label: "USB", icon: "ph-usb", active: false, go: "" },
        { label: "Sources", icon: "ph-squares-four", active: false, go: "" },
        { label: "Paramètres audio", icon: "ph-gear-six", active: false, go: "" }
    ]

    readonly property var queue: [
        { t: "Midnight Drive", a: "Eclipse", d: "03:47", now: true },
        { t: "Nightfall", a: "Eclipse", d: "04:12", now: false },
        { t: "Future Lights", a: "Nova", d: "03:35", now: false },
        { t: "Lost in Motion", a: "Aurora Road", d: "04:01", now: false },
        { t: "Starlight", a: "Eclipse", d: "03:28", now: false }
    ]

    Column {
        id: layout
        anchors.fill: parent
        anchors.topMargin: 20; anchors.bottomMargin: 20
        anchors.leftMargin: 32; anchors.rightMargin: 32
        spacing: 18

        Row {
            width: parent.width
            height: parent.height - 92 - 18
            spacing: 18

            Column {
                width: 280
                height: parent.height
                spacing: 6
                Text { text: "MÉDIA"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; bottomPadding: 14; topPadding: 6 }
                Repeater {
                    model: root.sideItems
                    delegate: SidebarItem {
                        width: 280
                        iconName: modelData.icon; label: modelData.label; active: modelData.active
                        accentColor: Theme.purple; tintColor: Theme.alpha(Theme.purple, 0.09)
                        onClicked: if (modelData.go) AppState.go(modelData.go)
                    }
                }
            }

            PanelCard {
                width: parent.width - 280 - 430 - 36
                height: parent.height
                radius: 18
                color: "transparent"
                border.color: Theme.alpha(Theme.purple, 0.18)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha("#181026", 0.8) }
                    GradientStop { position: 1.0; color: Theme.alpha("#0c0914", 0.9) }
                }

                Column {
                    x: 26; y: 26
                    width: parent.width - 52
                    height: parent.height - 52
                    spacing: 16

                    Row {
                        width: parent.width
                        height: parent.height - 16 - 78 - 60
                        spacing: 26
                        ImageAsset {
                            width: 240; height: 240; radius: 14
                            source: "qrc:/AgoojiyeHMI/assets/images/album-purple.jpg"
                        }
                        Column {
                            width: parent.width - 240 - 26
                            spacing: 6
                            Row {
                                width: parent.width
                                Text { text: "Midnight Drive"; font.family: Theme.fontFamily; font.pixelSize: 34; font.weight: Font.Bold; color: Theme.textPrimary }
                                Item { width: parent.width - 260 - 26; height: 1 }
                                Icon { name: "ph-heart"; fill: true; size: 26; color: Theme.purple }
                            }
                            Text { text: "Eclipse"; font.family: Theme.fontFamily; font.pixelSize: 18; color: Theme.textSecondary }
                            Text { text: "Neon Horizon"; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.purple }
                            Row {
                                topPadding: 8
                                spacing: 10
                                Rectangle {
                                    radius: 6
                                    border.width: 1; border.color: Theme.alpha(Theme.purple, 0.4)
                                    color: "transparent"
                                    width: flacLbl.implicitWidth + 20; height: flacLbl.implicitHeight + 6
                                    Text { id: flacLbl; anchors.centerIn: parent; text: "FLAC"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; color: "#c4b5fd" }
                                }
                                Text { text: "44.1 kHz"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            }
                            Item { width: 1; height: 6 }
                            Rectangle {
                                width: parent.width; height: 5; radius: 3; color: "#171227"
                                Rectangle { width: parent.width * 0.37; height: parent.height; radius: 3; color: Theme.purple }
                                Rectangle { x: parent.width * 0.37 - 7; y: -4.5; width: 14; height: 14; radius: 7; color: "#c4b5fd" }
                            }
                            Row {
                                width: parent.width
                                Text { text: "01:24"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                                Item { width: parent.width - 90; height: 1 }
                                Text { text: "03:47"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                            }
                        }
                    }

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 34
                        Icon { name: "ph-shuffle"; size: 24; color: Theme.purple; anchors.verticalCenter: parent.verticalCenter }
                        Icon { name: "ph-skip-back"; fill: true; size: 28; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: 72; height: 72; radius: 36
                            color: playHover.containsMouse ? Theme.alpha(Theme.purple, 0.12) : "transparent"
                            border.width: 2; border.color: Theme.purple
                            Icon { anchors.centerIn: parent; name: AppState.playing ? "ph-pause" : "ph-play"; fill: true; size: 28; color: Theme.textPrimary }
                            MouseArea { id: playHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: AppState.togglePlay() }
                        }
                        Icon { name: "ph-skip-forward"; fill: true; size: 28; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        Icon { name: "ph-repeat"; size: 24; color: Theme.purple; anchors.verticalCenter: parent.verticalCenter }
                    }

                    Rectangle {
                        width: parent.width; height: 46; radius: 12
                        color: Theme.alpha("#100c1c", 0.8)
                        border.width: 1; border.color: Theme.alpha(Theme.purple, 0.15)
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 18; anchors.rightMargin: 18
                            spacing: 14
                            Icon { name: "ph-speaker-high"; size: 20; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: parent.width - 20 - 14 - 30 - 14
                                height: 5; radius: 3; color: "#171227"
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: parent.width * 0.32; height: parent.height; radius: 3; color: Theme.purple }
                                Rectangle { x: parent.width * 0.32 - 6.5; y: -4; width: 13; height: 13; radius: 6.5; color: "#c4b5fd" }
                            }
                            Text { text: "18"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }

            Column {
                width: 430
                height: parent.height
                Row {
                    width: parent.width
                    bottomPadding: 14
                    Item {
                        width: qLbl.implicitWidth
                        height: qLbl.implicitHeight + 8
                        Text { id: qLbl; text: "FILE D'ATTENTE"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary }
                        Rectangle { anchors.left: parent.left; width: 34; anchors.bottom: parent.bottom; height: 3; radius: 2; color: Theme.purple }
                    }
                    Item { width: parent.width - qLbl.implicitWidth - 21; height: 1 }
                    Icon { name: "ph-queue"; size: 21; color: Theme.textMuted }
                }
                Column {
                    width: parent.width
                    topPadding: 6
                    spacing: 9
                    Repeater {
                        model: root.queue
                        delegate: Rectangle {
                            width: parent.width
                            height: 66
                            radius: 12
                            color: modelData.now ? Theme.alpha(Theme.purple, 0.1) : (qHover.containsMouse ? Theme.alpha("#141020", 0.9) : "transparent")
                            border.width: 1
                            border.color: modelData.now ? Theme.alpha(Theme.purple, 0.5) : Theme.alpha(Theme.purple, 0.08)
                            Row {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 14
                                Rectangle { width: 46; height: 46; radius: 8; color: Theme.alpha(Theme.purple, modelData.now ? 0.35 : 0.15); anchors.verticalCenter: parent.verticalCenter }
                                Column {
                                    width: parent.width - 46 - 14 - 50 - 30
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: modelData.t; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary }
                                    Text { text: modelData.a; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                                }
                                Icon { visible: modelData.now; name: "ph-chart-bar"; fill: true; size: 16; color: Theme.purple; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: modelData.d; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: qHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                        }
                    }
                    Text { text: "12 morceaux  •  45:30"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; topPadding: 8; leftPadding: 6 }
                }
            }
        }

        // mini player bar
        Row {
            x: 280 + 18
            width: layout.width - 280 - 18
            height: 92
            Rectangle {
                width: parent.width; height: parent.height; radius: 14
                border.width: 1; border.color: Theme.alpha(Theme.purple, 0.15)
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha("#141022", 0.9) }
                    GradientStop { position: 1.0; color: Theme.alpha("#0c0914", 0.95) }
                }

                Row {
                    id: miniLeft
                    anchors.left: parent.left
                    anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 24

                    Rectangle {
                        width: 52; height: 52; radius: 8
                        anchors.verticalCenter: parent.verticalCenter
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#3b1d5e" }
                            GradientStop { position: 1.0; color: "#c084fc" }
                        }
                    }
                    Column {
                        width: 170
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Midnight Drive"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Text { text: "Eclipse"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                    }
                    Rectangle { width: 1; height: parent.height - 28; color: Theme.alpha(Theme.textMuted, 0.2); anchors.verticalCenter: parent.verticalCenter }
                    Row {
                        spacing: 20
                        anchors.verticalCenter: parent.verticalCenter
                        Icon { name: "ph-skip-back"; fill: true; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: 46; height: 46; radius: 23
                            border.width: 2; border.color: Theme.purple
                            Icon { anchors.centerIn: parent; name: AppState.playing ? "ph-pause" : "ph-play"; fill: true; size: 18; color: Theme.textPrimary }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AppState.togglePlay() }
                        }
                        Icon { name: "ph-skip-forward"; fill: true; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        Icon { name: "ph-speaker-high"; size: 19; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "18"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Rectangle { width: 1; height: parent.height - 28; color: Theme.alpha(Theme.textMuted, 0.2); anchors.verticalCenter: parent.verticalCenter }
                    Row {
                        spacing: 12
                        anchors.verticalCenter: parent.verticalCenter
                        Icon { name: "ph-faders"; size: 22; color: Theme.purple; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            Text { text: "Égaliseur"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                            Text { text: "Personnalisé"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Icon { name: "ph-arrows-out-cardinal"; size: 22; color: Theme.purple; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Balance"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Text { text: "Centré"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                    }
                }
            }
        }
    }
}

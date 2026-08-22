import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property int section: AppState.section("media")

    readonly property var sideItems: [
        { label: "Musique", icon: "ph-music-notes" },
        { label: "Radio", icon: "ph-radio" },
        { label: "Bluetooth", icon: "ph-bluetooth" },
        { label: "USB", icon: "ph-usb" },
        { label: "Apple CarPlay", icon: "ph-play-circle" },
        { label: "Android Auto", icon: "ph-android-logo" }
    ]

    readonly property var stations: [
        { name: "Radio Bénin", freq: "93.5", genre: "Généraliste", fav: true },
        { name: "Cotonou FM", freq: "98.2", genre: "Musique", fav: true },
        { name: "Océan FM", freq: "101.7", genre: "Actualités", fav: false },
        { name: "Tokpa FM", freq: "104.3", genre: "Culture", fav: false },
        { name: "Golfe FM", freq: "105.7", genre: "Musique", fav: true },
        { name: "Radio Nostalgie", freq: "107.1", genre: "Rétro", fav: false }
    ]

    readonly property var tracks: [
        { t: "Better Tomorrow", a: "Kendrick Lamar", d: "4:21", now: true },
        { t: "Snooze", a: "SZA", d: "3:21", now: false },
        { t: "Die For You", a: "The Weeknd", d: "4:20", now: false },
        { t: "Levitating", a: "Dua Lipa", d: "3:23", now: false },
        { t: "Calm Down", a: "Rema", d: "3:41", now: false },
        { t: "Mon Soleil", a: "Aya Nakamura", d: "3:28", now: false }
    ]

    Row {
        id: layout
        anchors.fill: parent
        anchors.topMargin: 20; anchors.bottomMargin: 20
        anchors.leftMargin: 32; anchors.rightMargin: 32
        spacing: 20

        Column {
            width: 280
            height: layout.height
            spacing: 6
            Row {
                spacing: 14
                bottomPadding: 12
                Rectangle {
                    width: 42; height: 42; radius: 21
                    color: Theme.alpha(Theme.panelBgTop, 0.9)
                    border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.16)
                    Icon { anchors.centerIn: parent; name: "ph-arrow-left"; size: 19; color: Theme.textPrimary }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AppState.back() }
                }
                Text { text: "MÉDIA"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
            }
            Repeater {
                model: root.sideItems
                delegate: SidebarItem {
                    required property var modelData
                    required property int index
                    width: 280
                    iconName: modelData.icon; label: modelData.label
                    active: index === root.section
                    accentColor: Theme.purple; tintColor: Theme.alpha(Theme.purple, 0.1)
                    onClicked: AppState.selectSection("media", index)
                }
            }
        }

        // ---- panneau de la section ---------------------------------------
        Item {
            id: pane
            width: layout.width - 280 - 20
            height: layout.height

            // ---- 0 · Musique ---------------------------------------------
            Row {
                anchors.fill: parent
                spacing: 20
                visible: root.section === 0

            Column {
                width: layout.width - 280 - 430 - 40
                height: layout.height
                spacing: 16

                PanelCard {
                    width: parent.width
                    height: parent.height - 14 - 84
                    radius: 18
                    Column {
                        x: 26; y: 26
                        width: parent.width - 52
                        spacing: 18
                        Row {
                            width: parent.width
                            spacing: 26
                            ImageAsset {
                                width: 250; height: 250; radius: 14
                                source: "qrc:/AgoojiyeHMI/assets/images/album-blue.jpg"
                            }
                            Column {
                                width: parent.width - 250 - 26
                                spacing: 8
                                topPadding: 8
                                Rectangle {
                                    radius: 8
                                    color: Theme.alpha(Theme.blue, 0.12)
                                    border.width: 1; border.color: Theme.alpha(Theme.blue, 0.35)
                                    width: nowLbl.implicitWidth + 28; height: nowLbl.implicitHeight + 10
                                    Text { id: nowLbl; anchors.centerIn: parent; text: "Lecture en cours"; font.family: Theme.fontFamily; font.pixelSize: 13; color: "#93c5fd" }
                                }
                                Text { text: "Better Tomorrow"; topPadding: 8; font.family: Theme.fontFamily; font.pixelSize: 32; font.weight: Font.Bold; color: Theme.textPrimary }
                                Text { text: "Kendrick Lamar"; font.family: Theme.fontFamily; font.pixelSize: 19; color: Theme.textSecondary }
                                Text { text: "Mr. Morale & The Big Steppers"; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textMuted }
                                Item { width: 1; height: 8 }
                                Rectangle {
                                    width: parent.width; height: 5; radius: 3; color: "#0d1a2e"
                                    Rectangle { width: parent.width * 0.4; height: parent.height; radius: 3; color: Theme.blue }
                                    Rectangle { x: parent.width * 0.4 - 7; y: -4.5; width: 14; height: 14; radius: 7; color: "#e6ebf4" }
                                }
                                Row {
                                    width: parent.width
                                    Text { text: "1:42"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                                    Item { width: parent.width - 80; height: 1 }
                                    Text { text: "4:21"; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                                }
                            }
                        }
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 34
                            Icon { name: "ph-shuffle"; size: 24; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            Icon { name: "ph-skip-back"; fill: true; size: 28; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: 74; height: 74; radius: 37
                                color: playHover.containsMouse ? Theme.alpha(Theme.blue, 0.12) : "transparent"
                                border.width: 2; border.color: Theme.blue
                                Icon { anchors.centerIn: parent; name: VehicleData.mediaPlaying ? "ph-pause" : "ph-play"; fill: true; size: 30; color: Theme.textPrimary }
                                MouseArea { id: playHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: AppState.togglePlay() }
                            }
                            Icon { name: "ph-skip-forward"; fill: true; size: 28; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                            Icon { name: "ph-repeat"; size: 24; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }

                Row {
                    width: parent.width
                    height: 84
                    spacing: 14
                    PanelCard {
                        width: (parent.width - 28) / 3; height: 84; radius: 14
                        Row {
                            anchors.fill: parent; anchors.margins: 15
                            spacing: 12
                            Icon { name: "ph-faders"; size: 24; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                width: parent.width - 24 - 12 - 20
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "Égaliseur"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                                Text { text: "Personnaliser le son"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                            }
                            Icon { name: "ph-caret-right"; size: 15; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                    PanelCard {
                        width: (parent.width - 28) / 3; height: 84; radius: 14
                        Row {
                            anchors.fill: parent; anchors.margins: 15
                            spacing: 12
                            Icon { name: "ph-speaker-high"; size: 24; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                width: parent.width - 24 - 12 - 60
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "Son spatial"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                                Text { text: "Son immersif"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                            }
                            ToggleSwitch { checked: AppState.spatial; accentColor: Theme.blue; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.toggleSpatial() }
                        }
                    }
                    PanelCard {
                        width: (parent.width - 28) / 3; height: 84; radius: 14
                        Row {
                            anchors.fill: parent; anchors.margins: 15
                            spacing: 12
                            Icon { name: "ph-gear-six"; size: 24; color: Theme.blue; anchors.verticalCenter: parent.verticalCenter }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: "Paramètres média"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary }
                                Text { text: "Sources, affichage…"; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                            }
                        }
                    }
                }
            }

            Column {
                width: 430
                height: layout.height

                Row {
                    width: parent.width
                    spacing: 28
                    bottomPadding: 14
                    Item {
                        width: tabActive.implicitWidth
                        height: tabActive.implicitHeight + 15
                        Text { id: tabActive; text: "Ma musique"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.textBright }
                        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 3; radius: 2; color: Theme.blue }
                    }
                    Text { text: "Favoris"; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.textMuted }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.blue, 0.12) }

                Column {
                    width: parent.width
                    topPadding: 12
                    spacing: 10
                    Repeater {
                        model: root.tracks
                        delegate: Rectangle {
                            width: parent.width
                            height: 68
                            radius: 12
                            color: modelData.now ? Theme.alpha(Theme.blue, 0.1) : (trackHover.containsMouse ? Theme.alpha(Theme.panelBgTop, 0.9) : "transparent")
                            border.width: 1
                            border.color: modelData.now ? Theme.alpha(Theme.blue, 0.5) : Theme.alpha(Theme.panelBorder, 0.1)

                            Row {
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 14
                                Rectangle {
                                    width: 48; height: 48; radius: 8
                                    color: modelData.now ? Theme.alpha(Theme.blue, 0.18) : Theme.alpha(Theme.textMuted, 0.15)
                                    anchors.verticalCenter: parent.verticalCenter
                                    Icon { anchors.centerIn: parent; name: modelData.now ? "ph-chart-bar" : "ph-music-note"; fill: modelData.now; size: 18; color: modelData.now ? "#93c5fd" : Theme.textPrimary }
                                }
                                Column {
                                    width: parent.width - 48 - 14 - 60 - 20
                                    anchors.verticalCenter: parent.verticalCenter
                                    Text { text: modelData.t; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.textPrimary }
                                    Text { text: modelData.a; font.family: Theme.fontFamily; font.pixelSize: 13; color: modelData.now ? "#93c5fd" : Theme.textMuted }
                                }
                                Text { text: modelData.d; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                                Icon { name: "ph-dots-three-vertical"; size: 17; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea { id: trackHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: AppState.go("mediaNow") }
                        }
                    }
                }
            }
            }

            // ---- 1 · Radio -------------------------------------------------
            Column {
                id: radioPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 1

                Text { text: "RADIO FM"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                PanelCard {
                    width: parent.width * 0.55; height: 110; radius: 16
                    Row {
                        anchors.fill: parent
                        anchors.margins: 22
                        spacing: 20
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Row {
                                spacing: 8
                                Text { id: freqTxt; text: root.stations[0].freq; font.family: Theme.fontFamily; font.pixelSize: 38; font.weight: Font.Bold; color: Theme.purple }
                                Text { text: "MHz"; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textMuted; anchors.baseline: freqTxt.baseline }
                            }
                            Text { text: root.stations[0].name; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.textSecondary }
                        }
                        Item { width: 1; height: 1 }
                    }
                }

                Text { text: "STATIONS"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted; topPadding: 6 }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    Repeater {
                        model: root.stations
                        delegate: SettingRow {
                            required property var modelData
                            width: (radioPane.width - 18) / 2
                            iconName: modelData.fav ? "ph-star" : "ph-radio"
                            accentColor: modelData.fav ? Theme.orange : Theme.purple
                            label: modelData.name
                            sub: modelData.genre
                            value: modelData.freq + " MHz"
                            chevron: "ph-caret-right"
                        }
                    }
                }
            }

            // ---- 2 · Bluetooth ----------------------------------------------
            Column {
                id: btPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 2

                Text { text: "BLUETOOTH"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                SettingRow {
                    width: parent.width * 0.55
                    iconName: "ph-bluetooth"; accentColor: Theme.blue
                    label: "Bluetooth"; sub: VehicleData.bluetoothConnected ? "Activé" : "Désactivé"
                    ToggleSwitch { checked: VehicleData.bluetoothConnected; accentColor: Theme.blue; anchors.verticalCenter: parent.verticalCenter; onToggled: VehicleData.bluetoothConnected = !VehicleData.bluetoothConnected }
                }

                Text { text: "APPAREILS APPAIRÉS"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted; topPadding: 6 }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    Repeater {
                        model: [
                            { n: "iPhone de David", s: "Connecté — Audio et appels", i: "ph-phone", c: true },
                            { n: "Galaxy A54", s: "Appairé", i: "ph-phone", c: false },
                            { n: "Casque JBL", s: "Appairé", i: "ph-speaker-high", c: false }
                        ]
                        delegate: SettingRow {
                            required property var modelData
                            width: (btPane.width - 18) / 2
                            iconName: modelData.i
                            accentColor: modelData.c ? Theme.blue : Theme.textMuted
                            label: modelData.n
                            sub: modelData.s
                            chevron: "ph-caret-right"
                        }
                    }
                }
            }

            // ---- 3 · USB -----------------------------------------------------
            Column {
                id: usbPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 3

                Text { text: "USB"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                Text { text: "Aucune clé n'est branchée. Les prises se trouvent sous l'accoudoir central."; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    topPadding: 6
                    SettingRow { width: (usbPane.width - 18) / 2; iconName: "ph-usb"; accentColor: Theme.textMuted; label: "Port avant"; value: "Vide" }
                    SettingRow { width: (usbPane.width - 18) / 2; iconName: "ph-usb"; accentColor: Theme.textMuted; label: "Port arrière"; value: "Vide" }
                    SettingRow { width: (usbPane.width - 18) / 2; iconName: "ph-lightning"; accentColor: Theme.green; label: "Charge rapide"; value: "18 W" }
                    SettingRow { width: (usbPane.width - 18) / 2; iconName: "ph-cube"; accentColor: Theme.blue; label: "Formats reconnus"; value: "MP3, FLAC, WAV" }
                }
            }

            // ---- 4 · Apple CarPlay --------------------------------------------
            Column {
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 4

                Text { text: "APPLE CARPLAY"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                Text { text: "Branchez un iPhone en USB ou appairez-le en Bluetooth pour projeter son écran ici."; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }

                SettingRow { width: parent.width * 0.55; iconName: "ph-play-circle"; accentColor: Theme.textMuted; label: "État"; value: "Aucun appareil" }
                SettingRow { width: parent.width * 0.55; iconName: "ph-phone"; accentColor: Theme.blue; label: "iPhone de David"; sub: "Appairé en Bluetooth"; chevron: "ph-caret-right" }
            }

            // ---- 5 · Android Auto ---------------------------------------------
            Column {
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 5

                Text { text: "ANDROID AUTO"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                Text { text: "Branchez un téléphone Android en USB pour projeter son écran ici."; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }

                SettingRow { width: parent.width * 0.55; iconName: "ph-android-logo"; accentColor: Theme.textMuted; label: "État"; value: "Aucun appareil" }
                SettingRow { width: parent.width * 0.55; iconName: "ph-phone"; accentColor: Theme.green; label: "Galaxy A54"; sub: "Appairé en Bluetooth"; chevron: "ph-caret-right" }
            }
        }
    }
}

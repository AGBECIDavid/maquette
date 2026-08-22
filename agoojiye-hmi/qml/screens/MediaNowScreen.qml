import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property int section: AppState.section("mediaNow")

    // `sec` = une section de cet écran. `jump` = une section de l'écran Média,
    // où ces contenus vivent déjà : les dupliquer ici donnerait deux écrans à
    // maintenir pour la même chose.
    readonly property var sideItems: [
        { label: "Lecture en cours", icon: "ph-music-note", sec: 0 },
        { label: "Ma bibliothèque", icon: "ph-books", jump: 0 },
        { label: "Playlists", icon: "ph-queue", sec: 1 },
        { label: "Radio", icon: "ph-radio", jump: 1 },
        { label: "Bluetooth", icon: "ph-bluetooth", jump: 2 },
        { label: "USB", icon: "ph-usb", jump: 3 },
        { label: "Sources", icon: "ph-squares-four", sec: 2 },
        { label: "Paramètres audio", icon: "ph-gear-six", sec: 3 }
    ]

    readonly property var playlists: [
        { n: "Trajets du matin", c: 24, d: "1 h 32" },
        { n: "Route de nuit", c: 18, d: "1 h 07" },
        { n: "Afrobeat", c: 42, d: "2 h 48" },
        { n: "Calme", c: 15, d: "58 min" },
        { n: "Favoris", c: 63, d: "4 h 12" },
        { n: "Découvertes", c: 30, d: "1 h 55" }
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
                        required property var modelData
                        width: 280
                        iconName: modelData.icon; label: modelData.label
                        active: modelData.sec !== undefined && modelData.sec === root.section
                        accentColor: Theme.purple; tintColor: Theme.alpha(Theme.purple, 0.09)
                        onClicked: {
                            if (modelData.jump !== undefined) {
                                AppState.selectSection("media", modelData.jump)
                                AppState.go("media")
                            } else {
                                AppState.selectSection("mediaNow", modelData.sec)
                            }
                        }
                    }
                }
            }

            // ---- panneau de la section -----------------------------------
            Item {
                id: pane
                width: parent.width - 280 - 18
                height: parent.height

                // ---- 0 · Lecture en cours --------------------------------
                Row {
                    anchors.fill: parent
                    spacing: 18
                    visible: root.section === 0

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
                                    Text { text: VehicleData.trackTitle; font.family: Theme.fontFamily; font.pixelSize: 34; font.weight: Font.Bold; color: Theme.textPrimary }
                                    Item { width: parent.width - 260 - 26; height: 1 }
                                    Icon { name: "ph-heart"; fill: true; size: 26; color: Theme.purple }
                                }
                                Text { text: VehicleData.trackArtist; font.family: Theme.fontFamily; font.pixelSize: 18; color: Theme.textSecondary }
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
                                Icon { anchors.centerIn: parent; name: VehicleData.mediaPlaying ? "ph-pause" : "ph-play"; fill: true; size: 28; color: Theme.textPrimary }
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
                                Text { text: Math.round(AppState.mediaVolume * 100); font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
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

                // ---- 1 · Playlists ----------------------------------------
                Column {
                    id: plPane
                    anchors.fill: parent
                    spacing: 14
                    visible: root.section === 1

                    Text { text: "PLAYLISTS"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                    Grid {
                        width: parent.width
                        columns: 3
                        columnSpacing: 16
                        rowSpacing: 16
                        Repeater {
                            model: root.playlists
                            delegate: PanelCard {
                                required property var modelData
                                width: (plPane.width - 32) / 3
                                height: 150
                                radius: 16
                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 20
                                    spacing: 12
                                    Rectangle {
                                        width: 52; height: 52; radius: 14
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: Theme.alpha(Theme.purple, 0.55) }
                                            GradientStop { position: 1.0; color: Theme.alpha(Theme.blueDeep, 0.5) }
                                        }
                                        Icon { anchors.centerIn: parent; name: "ph-queue"; size: 24; color: "#ffffff" }
                                    }
                                    Text { text: modelData.n; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.textPrimary }
                                    Text { text: modelData.c + " morceaux  •  " + modelData.d; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor }
                            }
                        }
                    }
                }

                // ---- 2 · Sources -------------------------------------------
                Column {
                    id: srcPane
                    anchors.fill: parent
                    spacing: 14
                    visible: root.section === 2

                    Text { text: "SOURCES"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                    Grid {
                        width: parent.width
                        columns: 2
                        columnSpacing: 18
                        rowSpacing: 11
                        Repeater {
                            model: [
                                { l: "Bluetooth", s: "iPhone de David", i: "ph-bluetooth", on: true, j: 2 },
                                { l: "Radio FM", s: "93.5 MHz — Radio Bénin", i: "ph-radio", on: false, j: 1 },
                                { l: "USB", s: "Aucune clé branchée", i: "ph-usb", on: false, j: 3 },
                                { l: "Apple CarPlay", s: "Aucun appareil", i: "ph-play-circle", on: false, j: 4 },
                                { l: "Android Auto", s: "Aucun appareil", i: "ph-android-logo", on: false, j: 5 },
                                { l: "Bibliothèque", s: "128 morceaux hors ligne", i: "ph-books", on: false, j: 0 }
                            ]
                            delegate: SettingRow {
                                required property var modelData
                                width: (srcPane.width - 18) / 2
                                iconName: modelData.i
                                accentColor: modelData.on ? Theme.purple : Theme.textMuted
                                label: modelData.l
                                sub: modelData.s
                                value: modelData.on ? "Active" : ""
                                chevron: "ph-caret-right"
                                onClicked: {
                                    AppState.selectSection("media", modelData.j)
                                    AppState.go("media")
                                }
                            }
                        }
                    }
                }

                // ---- 3 · Paramètres audio -----------------------------------
                Column {
                    id: audioPane
                    anchors.fill: parent
                    spacing: 14
                    visible: root.section === 3

                    Text { text: "PARAMÈTRES AUDIO"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                    PanelCard {
                        width: parent.width * 0.62; height: 104; radius: 13
                        Column {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12
                            Item {
                                width: parent.width; height: 20
                                Text { anchors.left: parent.left; text: "VOLUME MÉDIA"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted }
                                Text { anchors.right: parent.right; text: Math.round(AppState.mediaVolume * 100) + " %"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.purple }
                            }
                            LevelBar {
                                width: parent.width
                                value: AppState.mediaVolume
                                accentColor: Theme.purple
                                onMoved: (v) => AppState.mediaVolume = v
                            }
                        }
                    }

                    Text { text: "ÉGALISEUR"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted; topPadding: 4 }
                    SegmentedControl {
                        width: parent.width * 0.62
                        options: ["Plat", "Grave", "Vocal", "Personnalisé"]
                        accentColor: Theme.purple
                        currentIndex: 3
                    }

                    Text { text: "BALANCE"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted; topPadding: 4 }
                    SegmentedControl {
                        width: parent.width * 0.62
                        options: ["Avant", "Centré", "Arrière"]
                        accentColor: Theme.purple
                        currentIndex: Math.max(0, ["Avant", "Centré", "Arrière"].indexOf(AppState.balance))
                        onSelected: (i) => AppState.balance = ["Avant", "Centré", "Arrière"][i]
                    }

                    SettingRow {
                        width: parent.width * 0.62
                        iconName: "ph-speaker-high"; accentColor: Theme.purple
                        label: "Son spatial"; sub: "Restitution enveloppante"
                        ToggleSwitch { checked: AppState.spatial; accentColor: Theme.purple; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.spatial = !AppState.spatial }
                    }
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
                        Text { text: VehicleData.trackTitle; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Text { text: VehicleData.trackArtist; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                    }
                    Rectangle { width: 1; height: parent.height - 28; color: Theme.alpha(Theme.textMuted, 0.2); anchors.verticalCenter: parent.verticalCenter }
                    Row {
                        spacing: 20
                        anchors.verticalCenter: parent.verticalCenter
                        Icon { name: "ph-skip-back"; fill: true; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                            width: 46; height: 46; radius: 23
                            border.width: 2; border.color: Theme.purple
                            Icon { anchors.centerIn: parent; name: VehicleData.mediaPlaying ? "ph-pause" : "ph-play"; fill: true; size: 18; color: Theme.textPrimary }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AppState.togglePlay() }
                        }
                        Icon { name: "ph-skip-forward"; fill: true; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Row {
                        spacing: 10
                        anchors.verticalCenter: parent.verticalCenter
                        Icon { name: "ph-speaker-high"; size: 19; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: Math.round(AppState.mediaVolume * 100); font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
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

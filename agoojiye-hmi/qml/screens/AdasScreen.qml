import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property int section: AppState.section("adas")

    readonly property var sideItems: [
        { label: "Aides à la conduite", icon: "ph-road-horizon" },
        { label: "Régulateur de vitesse", icon: "ph-gauge" },
        { label: "Sécurité", icon: "ph-shield-check" },
        { label: "Stationnement", icon: "ph-letter-circle-p" },
        { label: "Vision", icon: "ph-eye" },
        { label: "Alerte conducteur", icon: "ph-coffee" }
    ]
    readonly property var chips: [
        { label: "Voie détectée", icon: "ph-road-horizon", hot: false },
        { label: "Véhicule détecté", icon: "ph-car-simple", hot: true },
        { label: "Distance sûre", icon: "ph-arrows-out-line-horizontal", hot: false },
        { label: VehicleData.speedLimit + " km/h — Limite", icon: "ph-gauge", hot: false }
    ]
    readonly property var items: [
        { key: "acc", label: "Régulateur de vitesse adaptatif (ACC)", sub: "Maintient la distance avec le véhicule devant", icon: "ph-gauge" },
        { key: "lka", label: "Aide au maintien dans la voie (LKA)", sub: "Corrige la trajectoire si nécessaire", icon: "ph-road-horizon" },
        { key: "ldw", label: "Alerte de sortie de voie (LDW)", sub: "Alerte en cas de franchissement de ligne", icon: "ph-warning-diamond" },
        { key: "fcw", label: "Alerte collision avant (FCW)", sub: "Alerte en cas de risque de collision", icon: "ph-car-profile" },
        { key: "aeb", label: "Freinage d'urgence automatique (AEB)", sub: "Freine automatiquement si nécessaire", icon: "ph-record" },
        { key: "bsd", label: "Détection des angles morts (BSD)", sub: "Alerte en cas de véhicule dans l'angle mort", icon: "ph-eye" }
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
                Text { text: "ADAS"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
            }
            Repeater {
                model: root.sideItems
                delegate: SidebarItem {
                    required property var modelData
                    required property int index
                    width: 280
                    iconName: modelData.icon; label: modelData.label
                    active: index === root.section
                    accentColor: Theme.green; tintColor: Theme.alpha(Theme.green, 0.09)
                    onClicked: AppState.selectSection("adas", index)
                }
            }
        }

        // ---- panneau de la section ---------------------------------------
        Item {
            id: pane
            width: layout.width - 280 - 20
            height: layout.height

            // ---- 0 · Aides à la conduite ---------------------------------
            Row {
                anchors.fill: parent
                spacing: 20
                visible: root.section === 0

            Column {
                width: layout.width - 280 - 460 - 40
                height: layout.height
                spacing: 14

                Row {
                    spacing: 10
                    Text { text: "AIDES À LA CONDUITE"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    Icon { name: "ph-info"; size: 19; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
                Row {
                    width: parent.width
                    spacing: 14
                    Repeater {
                        model: root.chips
                        delegate: Rectangle {
                            width: (parent.width - 14 * 3) / 4
                            height: 84
                            radius: 12
                            color: modelData.hot ? Theme.alpha(Theme.green, 0.12) : Theme.alpha(Theme.navBg, 0.7)
                            border.width: 1
                            border.color: modelData.hot ? Theme.green : Theme.alpha(Theme.green, 0.25)
                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: modelData.icon; size: 26; color: Theme.green }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 12; color: "#a7e8bd" }
                            }
                        }
                    }
                }

                PanelCard {
                    width: parent.width
                    height: parent.height - 19 - 14 - 84 - 14 - 76 - 14
                    radius: 16
                    color: "transparent"
                    border.color: Theme.alpha(Theme.green, 0.2)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.alpha(Theme.panelBgTop, 0.6) }
                        GradientStop { position: 1.0; color: Theme.alpha(Theme.panelBgBottom, 0.8) }
                    }
                    ImageAsset {
                        anchors.fill: parent
                        radius: 16
                        source: "qrc:/AgoojiyeHMI/assets/images/adas-road.png"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 76
                    radius: 14
                    color: Theme.alpha(Theme.navBg, 0.9)
                    border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.14)
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 20; anchors.rightMargin: 20
                        spacing: 14
                        Icon { name: "ph-check-circle"; fill: true; size: 26; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: "Système activé"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.textPrimary }
                            Text { text: "Les aides à la conduite sont actives et opérationnelles."; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }
                        }
                    }
                }
            }

            Column {
                width: 460
                height: layout.height
                spacing: 11
                Text { text: "SYSTÈMES ADAS"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary; topPadding: 8; bottomPadding: 4 }
                Repeater {
                    model: root.items
                    delegate: PanelCard {
                        width: parent.width
                        height: 68
                        radius: 13
                        border.color: Theme.alpha(Theme.panelBorder, 0.12)
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 16; anchors.rightMargin: 16
                            spacing: 14
                            Icon {
                                name: modelData.icon; size: 24
                                color: AppState.adas[modelData.key] ? Theme.green : "#5b6579"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Column {
                                width: parent.width - 24 - 14 - 52 - 14
                                anchors.verticalCenter: parent.verticalCenter
                                Text { text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.DemiBold; color: Theme.textPrimary; wrapMode: Text.WordWrap; width: parent.width }
                                Text { text: modelData.sub; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted; wrapMode: Text.WordWrap; width: parent.width }
                            }
                            ToggleSwitch {
                                checked: AppState.adas[modelData.key]
                                accentColor: Theme.green
                                anchors.verticalCenter: parent.verticalCenter
                                onToggled: AppState.toggleAdas(modelData.key)
                            }
                        }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 52
                    radius: 13
                    color: Theme.alpha(Theme.navBg, 0.9)
                    border.width: 1
                    border.color: settingsHover.containsMouse ? Theme.alpha(Theme.panelBorder, 0.4) : Theme.alpha(Theme.panelBorder, 0.14)
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 18; anchors.rightMargin: 18
                        Text { text: "Paramètres des alertes"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        Item { width: parent.width - 220; height: 1 }
                        Icon { name: "ph-caret-right"; size: 16; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: settingsHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                }
            }
            }

            // ---- 1 · Régulateur de vitesse --------------------------------
            Column {
                id: accPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 1

                Text { text: "RÉGULATEUR DE VITESSE"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: 14
                    StatTile { width: (accPane.width - 28) / 3; iconName: "ph-gauge"; label: "CONSIGNE"; value: String(VehicleData.cruiseSpeed); unit: "km/h"; valueColor: Theme.green }
                    StatTile { width: (accPane.width - 28) / 3; iconName: "ph-car-simple"; label: "VITESSE ACTUELLE"; value: String(Math.round(VehicleData.speed)); unit: "km/h" }
                    StatTile { width: (accPane.width - 28) / 3; iconName: "ph-road-horizon"; label: "LIMITE EN VIGUEUR"; value: String(VehicleData.speedLimit); unit: "km/h"; valueColor: Theme.blue }
                }

                Text { text: "DISTANCE DE SUIVI"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted; topPadding: 8 }
                SegmentedControl {
                    width: parent.width * 0.5
                    options: ["Courte", "Moyenne", "Longue"]
                    accentColor: Theme.green
                    currentIndex: AppState.accGap - 1
                    onSelected: (i) => AppState.accGap = i + 1
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    topPadding: 6
                    SettingRow {
                        width: (accPane.width - 18) / 2
                        iconName: "ph-gauge"; accentColor: Theme.green
                        label: "Régulateur adaptatif"; sub: "Maintient la distance automatiquement"
                        ToggleSwitch { checked: AppState.adas.acc; accentColor: Theme.green; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.toggleAdas("acc") }
                    }
                    SettingRow { width: (accPane.width - 18) / 2; iconName: "ph-road-horizon"; accentColor: Theme.blue; label: "Adaptation à la limite"; value: "Automatique" }
                }
            }

            // ---- 2 · Sécurité ----------------------------------------------
            Column {
                id: safePane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 2

                Text { text: "SÉCURITÉ"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                Text { text: "Systèmes qui interviennent d'eux-mêmes en cas de danger. Les couper reste possible, mais ils se réactivent au prochain démarrage."; width: parent.width * 0.75; wrapMode: Text.WordWrap; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    Repeater {
                        model: [
                            { k: "aeb", l: "Freinage d'urgence (AEB)", s: "Freine seul en cas de risque", i: "ph-record" },
                            { k: "fcw", l: "Alerte collision avant (FCW)", s: "Prévient avant l'obstacle", i: "ph-car-profile" },
                            { k: "lka", l: "Maintien dans la voie (LKA)", s: "Corrige la trajectoire", i: "ph-road-horizon" },
                            { k: "ldw", l: "Sortie de voie (LDW)", s: "Alerte au franchissement", i: "ph-warning-diamond" },
                            { k: "bsd", l: "Angles morts (BSD)", s: "Surveille les côtés", i: "ph-eye" }
                        ]
                        delegate: SettingRow {
                            required property var modelData
                            width: (safePane.width - 18) / 2
                            iconName: modelData.i
                            accentColor: Theme.green
                            label: modelData.l
                            sub: modelData.s
                            ToggleSwitch {
                                checked: AppState.adas[modelData.k]
                                accentColor: Theme.green
                                anchors.verticalCenter: parent.verticalCenter
                                onToggled: AppState.toggleAdas(modelData.k)
                            }
                        }
                    }
                }
            }

            // ---- 3 · Stationnement -------------------------------------------
            Column {
                id: parkPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 3

                Text { text: "STATIONNEMENT"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    SettingRow {
                        width: (parkPane.width - 18) / 2
                        iconName: "ph-crosshair-simple"; accentColor: Theme.green
                        label: "Capteurs de proximité"; sub: "Avant et arrière"
                        ToggleSwitch { checked: AppState.parkSensors; accentColor: Theme.green; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.parkSensors = !AppState.parkSensors }
                    }
                    SettingRow {
                        width: (parkPane.width - 18) / 2
                        iconName: "ph-eye"; accentColor: Theme.blue
                        label: "Caméra de recul"; sub: "S'affiche en marche arrière"
                        ToggleSwitch { checked: AppState.rearCamera; accentColor: Theme.blue; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.rearCamera = !AppState.rearCamera }
                    }
                    SettingRow {
                        width: (parkPane.width - 18) / 2
                        iconName: "ph-steering-wheel"; accentColor: Theme.purple
                        label: "Stationnement assisté"; sub: "Manœuvre guidée"
                        ToggleSwitch { checked: AppState.autoPark; accentColor: Theme.purple; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.autoPark = !AppState.autoPark }
                    }
                    SettingRow {
                        width: (parkPane.width - 18) / 2
                        iconName: "ph-speaker-high"; accentColor: Theme.orange
                        label: "Bip de recul"; sub: "Signal sonore"
                        ToggleSwitch { checked: AppState.reverseBeep; accentColor: Theme.orange; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.reverseBeep = !AppState.reverseBeep }
                    }
                }

                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: 14
                    topPadding: 6
                    StatTile { width: (parkPane.width - 28) / 3; iconName: "ph-crosshair-simple"; label: "OBSTACLE AVANT"; value: "Aucun"; valueColor: Theme.green }
                    StatTile { width: (parkPane.width - 28) / 3; iconName: "ph-crosshair-simple"; label: "OBSTACLE ARRIÈRE"; value: "1,4"; unit: "m"; valueColor: Theme.yellow }
                    StatTile { width: (parkPane.width - 28) / 3; iconName: "ph-letter-circle-p"; label: "FREIN DE PARC"; value: VehicleData.parkingBrake ? "Serré" : "Desserré"; valueColor: VehicleData.parkingBrake ? Theme.red : Theme.green }
                }
            }

            // ---- 4 · Vision ---------------------------------------------------
            Column {
                id: visionPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 4

                Text { text: "VISION"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                ImageAsset {
                    width: parent.width * 0.62; height: 240; radius: 16
                    source: "qrc:/AgoojiyeHMI/assets/images/adas-road.png"
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    SettingRow { width: (visionPane.width - 18) / 2; iconName: "ph-eye"; accentColor: Theme.green; label: "Caméra frontale"; value: "Opérationnelle" }
                    SettingRow { width: (visionPane.width - 18) / 2; iconName: "ph-eye"; accentColor: Theme.green; label: "Caméra de recul"; value: AppState.rearCamera ? "Opérationnelle" : "Désactivée" }
                    SettingRow { width: (visionPane.width - 18) / 2; iconName: "ph-crosshair-simple"; accentColor: Theme.green; label: "Radar avant"; value: "Opérationnel" }
                    SettingRow { width: (visionPane.width - 18) / 2; iconName: "ph-headlights"; accentColor: Theme.blue; label: "Feux adaptatifs"; value: VehicleData.headlightsAuto ? "Auto" : "Manuel" }
                }
            }

            // ---- 5 · Alerte conducteur ----------------------------------------
            Column {
                id: alertPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 5

                Text { text: "ALERTE CONDUCTEUR"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                Text { text: "Surveille les signes de fatigue à partir des corrections de trajectoire et de la durée de conduite, et propose une pause."; width: parent.width * 0.75; wrapMode: Text.WordWrap; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }

                SettingRow {
                    width: parent.width * 0.55
                    iconName: "ph-coffee"; accentColor: Theme.green
                    label: "Détection de fatigue"; sub: "Propose une pause après 2 heures"
                    ToggleSwitch { checked: AppState.driverAlert; accentColor: Theme.green; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.driverAlert = !AppState.driverAlert }
                }

                Text { text: "SENSIBILITÉ"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted; topPadding: 8 }
                SegmentedControl {
                    width: parent.width * 0.5
                    options: ["Basse", "Normale", "Haute"]
                    accentColor: Theme.green
                    currentIndex: AppState.driverAlertLevel
                    onSelected: (i) => AppState.driverAlertLevel = i
                }

                Grid {
                    width: parent.width
                    columns: 3
                    columnSpacing: 14
                    topPadding: 6
                    StatTile { width: (alertPane.width - 28) / 3; iconName: "ph-clock"; label: "TEMPS DE CONDUITE"; value: "0 h 42"; valueColor: Theme.green }
                    StatTile { width: (alertPane.width - 28) / 3; iconName: "ph-coffee"; label: "PROCHAINE PAUSE"; value: "1 h 18"; valueColor: Theme.blue }
                    StatTile { width: (alertPane.width - 28) / 3; iconName: "ph-check-circle"; label: "VIGILANCE"; value: "Normale"; valueColor: Theme.green }
                }
            }
        }
    }
}

import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property int section: AppState.section("conduite")

    readonly property var sideItems: [
        { label: "Modes de conduite", icon: "ph-car-simple" },
        { label: "Régénération", icon: "ph-lightning" },
        { label: "Traction", icon: "ph-steering-wheel" },
        { label: "Direction", icon: "ph-arrows-left-right" },
        { label: "Suspension", icon: "ph-arrows-vertical" },
        { label: "Freinage", icon: "ph-record" }
    ]
    readonly property var modes: [
        { key: "eco", label: "ECO", icon: "ph-leaf", c: Theme.green, desc: "Optimise l'efficacité énergétique pour maximiser l'autonomie. Idéal pour une conduite économique au quotidien." },
        { key: "normal", label: "NORMAL", icon: "ph-car-simple", c: Theme.blue, desc: "Équilibre entre performance et consommation pour tous les trajets." },
        { key: "sport", label: "SPORT", icon: "ph-flag-checkered", c: Theme.orange, desc: "Réponse immédiate de l'accélérateur et direction plus ferme." },
        { key: "comfort", label: "COMFORT", icon: "ph-armchair", c: Theme.purple, desc: "Souplesse et silence privilégiés pour les longs trajets." }
    ]
    function currentMode() {
        for (var i = 0; i < modes.length; i++) if (modes[i].key.toUpperCase() === VehicleData.driveMode) return modes[i]
        return modes[0]
    }

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
            Text { text: "CONDUITE"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; bottomPadding: 14; topPadding: 6 }
            Repeater {
                model: root.sideItems
                delegate: SidebarItem {
                    required property var modelData
                    required property int index
                    width: 280
                    iconName: modelData.icon; label: modelData.label
                    active: index === root.section
                    accentColor: Theme.green; tintColor: Theme.alpha(Theme.green, 0.09)
                    onClicked: AppState.selectSection("conduite", index)
                }
            }
        }

        // ---- panneau de la section ---------------------------------------
        Item {
            id: pane
            width: layout.width - 280 - 20
            height: layout.height

            // ---- 0 · Modes de conduite -----------------------------------
            Row {
                anchors.fill: parent
                spacing: 20
                visible: root.section === 0

            Column {
                width: layout.width - 280 - 460 - 40
                height: layout.height
                spacing: 14

                Text { text: "MODE DE CONDUITE"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                Grid {
                    width: parent.width
                    columns: 4
                    columnSpacing: 12
                    Repeater {
                        model: root.modes
                        delegate: Rectangle {
                            readonly property bool active: modelData.key.toUpperCase() === VehicleData.driveMode
                            width: (parent.width - 12 * 3) / 4
                            height: 100
                            radius: 14
                            color: "transparent"
                            border.width: 1
                            border.color: active ? modelData.c : Theme.alpha(Theme.panelBorder, 0.14)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: active ? Theme.alpha(modelData.c, 0.08) : Theme.panelGradTop }
                                GradientStop { position: 1.0; color: active ? Theme.alpha(modelData.c, 0.08) : Theme.panelGradBottom }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: modelData.icon; size: 30; color: modelData.c }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; font.letterSpacing: 1; color: active ? Theme.textPrimary : Theme.textDim }
                                Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 34; height: 3; radius: 2; color: active ? modelData.c : "transparent" }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: AppState.setDriveMode(modelData.key) }
                        }
                    }
                }

                PanelCard {
                    width: parent.width
                    height: parent.height - 19 - 14 - 100 - 14 - 90 - 14
                    radius: 16
                    ImageAsset {
                        anchors.fill: parent
                        anchors.margins: 26
                        radius: 16
                        // A transparent cut-out has to be fitted, not cropped, or
                        // the panel zooms into the middle of the vehicle.
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AgoojiyeHMI/assets/images/conduite-car.png"
                    }
                }

                Column {
                    width: parent.width
                    spacing: 6
                    Row {
                        spacing: 10
                        Icon { name: root.currentMode().icon; size: 22; color: root.currentMode().c; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: root.currentMode().label; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: root.currentMode().c; anchors.verticalCenter: parent.verticalCenter }
                    }
                    Text { width: parent.width; text: root.currentMode().desc; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textDim; wrapMode: Text.WordWrap; lineHeight: 1.55; lineHeightMode: Text.ProportionalHeight }
                    Row {
                        topPadding: 6
                        spacing: 8
                        Repeater {
                            model: root.modes
                            delegate: Rectangle { width: 8; height: 8; radius: 4; color: modelData.key.toUpperCase() === VehicleData.driveMode ? root.currentMode().c : Theme.dotInactive }
                        }
                    }
                }
            }

            PanelCard {
                width: 460
                height: layout.height
                radius: 16
                border.color: Theme.alpha(Theme.panelBorder, 0.12)
                color: "transparent"
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.alpha(Theme.panelBgTop, 0.7) }
                    GradientStop { position: 1.0; color: Theme.alpha(Theme.panelBgBottom, 0.85) }
                }

                Column {
                    x: 22; y: 22
                    width: parent.width - 44
                    spacing: 22
                    Text { text: "PARAMÈTRES DE CONDUITE"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }

                    Column {
                        width: parent.width
                        spacing: 9
                        Text { text: "RÉGÉNÉRATION D'ÉNERGIE"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted }
                        SegmentedControl {
                            width: parent.width
                            options: ["Faible", "Moyenne", "Forte", "Auto"]
                            currentIndex: options.indexOf(AppState.regen)
                            accentColor: Theme.green
                            onSelected: (i) => AppState.setRegen(options[i])
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 12
                        Text { text: "RÉPONSE DE L'ACCÉLÉRATEUR"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted }
                        Row {
                            width: parent.width
                            spacing: 14
                            Text { text: "Douce"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                            Rectangle {
                                width: parent.width - 14 * 2 - 46 - 62
                                height: 5; radius: 3; color: "#0d1a2e"
                                anchors.verticalCenter: parent.verticalCenter
                                Rectangle { width: parent.width * 0.62; height: parent.height; radius: 3; color: Theme.green }
                                Rectangle { x: parent.width * 0.62 - 8; y: -5.5; width: 16; height: 16; radius: 8; color: "#4ade80" }
                            }
                            Text { text: "Réactive"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textDim; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 9
                        Text { text: "DIRECTION"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted }
                        SegmentedControl {
                            width: parent.width
                            options: ["Légère", "Standard", "Ferme"]
                            currentIndex: options.indexOf(AppState.dir)
                            accentColor: Theme.green
                            onSelected: (i) => AppState.setDir(options[i])
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 9
                        Text { text: "TRACTION"; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.DemiBold; font.letterSpacing: 1; color: Theme.textMuted }
                        SegmentedControl {
                            width: parent.width
                            options: ["Eco", "Standard", "Sport"]
                            currentIndex: options.indexOf(AppState.trac)
                            accentColor: Theme.green
                            onSelected: (i) => AppState.setTrac(options[i])
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 52
                        radius: 13
                        color: Theme.alpha(Theme.navBg, 0.85)
                        border.width: 1
                        border.color: customHover.containsMouse ? Theme.alpha(Theme.panelBorder, 0.4) : Theme.alpha(Theme.panelBorder, 0.14)
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 18; anchors.rightMargin: 18
                            Text { text: "Personnaliser le mode"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                            Item { width: parent.width - 220; height: 1 }
                            Icon { name: "ph-caret-right"; size: 16; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: customHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
            }

            // ---- 1 · Régénération -----------------------------------------
            Column {
                id: regenPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 1

                Text { text: "RÉGÉNÉRATION D'ÉNERGIE"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                Text { text: "Règle la force du freinage récupératif au lever de pied. Plus elle est forte, plus la navette ralentit seule et recharge la batterie."; width: parent.width * 0.7; wrapMode: Text.WordWrap; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }

                SegmentedControl {
                    width: parent.width * 0.55
                    options: ["Faible", "Moyenne", "Forte", "Auto"]
                    accentColor: Theme.green
                    currentIndex: Math.max(0, ["Faible", "Moyenne", "Forte", "Auto"].indexOf(AppState.regen))
                    onSelected: (i) => AppState.setRegen(["Faible", "Moyenne", "Forte", "Auto"][i])
                }

                Grid {
                    width: parent.width
                    columns: 4
                    columnSpacing: 14
                    topPadding: 6
                    StatTile { width: (regenPane.width - 42) / 4; iconName: "ph-lightning"; label: "RÉCUPÉRÉ"; value: VehicleData.regenPower.toFixed(1); unit: "kW"; valueColor: Theme.green }
                    StatTile { width: (regenPane.width - 42) / 4; iconName: "ph-battery-charging"; label: "GAIN ESTIMÉ"; value: "6"; unit: "km/jour"; valueColor: Theme.green }
                    StatTile { width: (regenPane.width - 42) / 4; iconName: "ph-chart-bar"; label: "CONSOMMATION"; value: VehicleData.consumption.toFixed(1); unit: "kWh/100km" }
                    StatTile { width: (regenPane.width - 42) / 4; iconName: "ph-road-horizon"; label: "AUTONOMIE"; value: String(VehicleData.range); unit: "km" }
                }

                SettingRow {
                    width: parent.width * 0.55
                    iconName: "ph-hand-tap"; accentColor: Theme.green
                    label: "Conduite à une pédale"; sub: "S'arrête complètement au lever de pied"
                    ToggleSwitch { checked: AppState.onePedal; accentColor: Theme.green; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.onePedal = !AppState.onePedal }
                }
            }

            // ---- 2 · Traction ----------------------------------------------
            Column {
                id: tracPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 2

                Text { text: "TRACTION"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                Text { text: "Répartit le couple et règle le seuil d'intervention de l'antipatinage."; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }

                SegmentedControl {
                    width: parent.width * 0.55
                    options: ["Eco", "Standard", "Sport"]
                    accentColor: Theme.green
                    currentIndex: Math.max(0, ["Eco", "Standard", "Sport"].indexOf(AppState.trac))
                    onSelected: (i) => AppState.setTrac(["Eco", "Standard", "Sport"][i])
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    topPadding: 6
                    SettingRow {
                        width: (tracPane.width - 18) / 2
                        iconName: "ph-arrows-vertical"; accentColor: Theme.green
                        label: "Aide au démarrage en côte"; sub: "Retient le véhicule 2 secondes"
                        ToggleSwitch { checked: AppState.hillHold; accentColor: Theme.green; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.hillHold = !AppState.hillHold }
                    }
                    SettingRow { width: (tracPane.width - 18) / 2; iconName: "ph-tire"; accentColor: Theme.blue; label: "Antipatinage"; value: "Actif" }
                    SettingRow { width: (tracPane.width - 18) / 2; iconName: "ph-gauge"; accentColor: Theme.blue; label: "Couple maximal"; value: "180 Nm" }
                    SettingRow { width: (tracPane.width - 18) / 2; iconName: "ph-crosshair-simple"; accentColor: Theme.purple; label: "Contrôle de stabilité"; value: "Actif" }
                }
            }

            // ---- 3 · Direction ----------------------------------------------
            Column {
                id: dirPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 3

                Text { text: "DIRECTION"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                Text { text: "Règle la fermeté de l'assistance. Une direction légère facilite les manœuvres, une direction ferme rassure à vitesse établie."; width: parent.width * 0.7; wrapMode: Text.WordWrap; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }

                SegmentedControl {
                    width: parent.width * 0.55
                    options: ["Légère", "Standard", "Ferme"]
                    accentColor: Theme.green
                    currentIndex: Math.max(0, ["Légère", "Standard", "Ferme"].indexOf(AppState.dir))
                    onSelected: (i) => AppState.setDir(["Légère", "Standard", "Ferme"][i])
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    topPadding: 6
                    SettingRow { width: (dirPane.width - 18) / 2; iconName: "ph-steering-wheel"; accentColor: Theme.green; label: "Assistance"; value: AppState.dir }
                    SettingRow { width: (dirPane.width - 18) / 2; iconName: "ph-arrows-clockwise"; accentColor: Theme.blue; label: "Rappel au centre"; value: "Progressif" }
                    SettingRow { width: (dirPane.width - 18) / 2; iconName: "ph-arrows-out-cardinal"; accentColor: Theme.blue; label: "Diamètre de braquage"; value: "6,4 m" }
                    SettingRow { width: (dirPane.width - 18) / 2; iconName: "ph-crosshair-simple"; accentColor: Theme.purple; label: "Alignement"; value: "Correct" }
                }
            }

            // ---- 4 · Suspension ----------------------------------------------
            Column {
                id: suspPane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 4

                Text { text: "SUSPENSION"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                Text { text: "Une navette qui transporte des passagers debout privilégie le confort : le réglage souple limite le tangage aux arrêts."; width: parent.width * 0.7; wrapMode: Text.WordWrap; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }

                SegmentedControl {
                    width: parent.width * 0.55
                    options: ["Souple", "Confort", "Ferme"]
                    accentColor: Theme.green
                    currentIndex: Math.max(0, ["Souple", "Confort", "Ferme"].indexOf(AppState.suspension))
                    onSelected: (i) => AppState.suspension = ["Souple", "Confort", "Ferme"][i]
                }

                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 11
                    topPadding: 6
                    SettingRow { width: (suspPane.width - 18) / 2; iconName: "ph-arrows-vertical"; accentColor: Theme.green; label: "Réglage"; value: AppState.suspension }
                    SettingRow { width: (suspPane.width - 18) / 2; iconName: "ph-armchair"; accentColor: Theme.purple; label: "Charge détectée"; value: "4 passagers" }
                    SettingRow { width: (suspPane.width - 18) / 2; iconName: "ph-ruler"; accentColor: Theme.blue; label: "Garde au sol"; value: "17 cm" }
                    SettingRow { width: (suspPane.width - 18) / 2; iconName: "ph-check-circle"; accentColor: Theme.green; label: "État des amortisseurs"; value: "Normal" }
                }
            }

            // ---- 5 · Freinage ------------------------------------------------
            Column {
                id: brakePane
                anchors.fill: parent
                anchors.topMargin: 8
                spacing: 14
                visible: root.section === 5

                Text { text: "FREINAGE"; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary }
                Text { text: "Le freinage combine récupération et freins mécaniques. Le ressenti règle le dosage de la pédale, pas la distance d'arrêt."; width: parent.width * 0.7; wrapMode: Text.WordWrap; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }

                SegmentedControl {
                    width: parent.width * 0.55
                    options: ["Souple", "Standard", "Mordant"]
                    accentColor: Theme.green
                    currentIndex: Math.max(0, ["Souple", "Standard", "Mordant"].indexOf(AppState.brakeFeel))
                    onSelected: (i) => AppState.brakeFeel = ["Souple", "Standard", "Mordant"][i]
                }

                Grid {
                    width: parent.width
                    columns: 4
                    columnSpacing: 14
                    topPadding: 6
                    StatTile { width: (brakePane.width - 42) / 4; iconName: "ph-record"; label: "PLAQUETTES AV"; value: "92"; unit: "%"; valueColor: Theme.green }
                    StatTile { width: (brakePane.width - 42) / 4; iconName: "ph-record"; label: "PLAQUETTES AR"; value: "88"; unit: "%"; valueColor: Theme.green }
                    StatTile { width: (brakePane.width - 42) / 4; iconName: "ph-drop"; label: "LIQUIDE"; value: "OK"; valueColor: Theme.green }
                    StatTile { width: (brakePane.width - 42) / 4; iconName: "ph-brake-warning"; label: "FREIN DE PARC"; value: VehicleData.parkingBrake ? "Serré" : "Desserré"; valueColor: VehicleData.parkingBrake ? Theme.red : Theme.green }
                }

                SettingRow {
                    width: parent.width * 0.55
                    iconName: "ph-arrows-vertical"; accentColor: Theme.green
                    label: "Maintien à l'arrêt"; sub: "Garde le frein serré au feu rouge"
                    ToggleSwitch { checked: AppState.hillHold; accentColor: Theme.green; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.hillHold = !AppState.hillHold }
                }
            }
        }
    }
}

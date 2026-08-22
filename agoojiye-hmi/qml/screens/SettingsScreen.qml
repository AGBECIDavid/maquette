import QtQuick
import AgoojiyeHMI

// Paramètres : rail de sections à gauche, contenu de la section à droite.
//
// Le rail pilote `AppState.sections.parametres` ; chaque panneau n'est qu'un
// Item rendu visible par cet index. Rien de plus — pas de pile d'écrans à
// gérer, et l'état survit à une sortie vers un autre écran.
Item {
    id: root

    readonly property int section: AppState.section("parametres")

    readonly property var sideItems: [
        { label: "Général", sub: "Langue, unités, date, heure", icon: "ph-gear-six", c: Theme.blue },
        { label: "Affichage", sub: "Luminosité, thème, mode", icon: "ph-sun", c: Theme.orange },
        { label: "Son", sub: "Volume, balance, notifications", icon: "ph-speaker-high", c: Theme.purple },
        { label: "Véhicule", sub: "Préférences, conduite", icon: "ph-car-simple", c: Theme.green },
        { label: "Système", sub: "Infos système, mises à jour", icon: "ph-cube", c: Theme.blue }
    ]
    readonly property var aboutRows: [
        { k: "Nom du système", v: VehicleData.vehicleName + " V1" },
        { k: "Version logicielle", v: VehicleData.softwareVersion },
        { k: "Version UI", v: VehicleData.uiVersion },
        { k: "ID du véhicule (VIN)", v: VehicleData.vin },
        { k: "Espace de stockage", v: VehicleData.storageUsed }
    ]

    Row {
        id: layout
        anchors.fill: parent
        anchors.topMargin: 20; anchors.bottomMargin: 20
        anchors.leftMargin: 32; anchors.rightMargin: 32
        spacing: 22

        // ---- rail des sections -------------------------------------------
        Column {
            width: 330
            height: layout.height
            spacing: 10
            Text { text: "PARAMÈTRES"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; bottomPadding: 8; topPadding: 6 }
            Repeater {
                model: root.sideItems
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    readonly property bool active: index === root.section
                    width: 330; height: 78; radius: 13
                    color: "transparent"
                    border.width: 1
                    border.color: active ? modelData.c : Theme.alpha(Theme.panelBorder, 0.14)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: active ? Theme.alpha(modelData.c, 0.1) : (settHover.containsMouse ? Theme.alpha(Theme.panelBgTop, 0.95) : Theme.panelGradTop) }
                        GradientStop { position: 1.0; color: active ? Theme.alpha(modelData.c, 0.1) : (settHover.containsMouse ? Theme.alpha(Theme.panelBgTop, 0.95) : Theme.panelGradBottom) }
                    }
                    Rectangle { width: 3; height: parent.height; radius: 1.5; color: parent.active ? modelData.c : "transparent" }
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        spacing: 15
                        Rectangle {
                            width: 46; height: 46; radius: 23
                            color: Theme.alpha(modelData.c, 0.12)
                            anchors.verticalCenter: parent.verticalCenter
                            Icon { anchors.centerIn: parent; name: modelData.icon; size: 22; color: modelData.c }
                        }
                        Column {
                            width: parent.width - 46 - 15 - 15 - 20
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.label; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.textPrimary }
                            Text { text: modelData.sub; font.family: Theme.fontFamily; font.pixelSize: 12; color: Theme.textMuted }
                        }
                        Icon { name: "ph-caret-right"; size: 15; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea {
                        id: settHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AppState.selectSection("parametres", parent.index)
                    }
                }
            }
        }

        // ---- contenu de la section ---------------------------------------
        Item {
            id: content
            width: layout.width - 330 - 22
            height: layout.height

            Text {
                id: sectionTitle
                text: root.sideItems[root.section].label.toUpperCase()
                font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold
                font.letterSpacing: 1; color: Theme.textPrimary
                y: 8
            }

            // Deux colonnes : les panneaux longs respirent au lieu de
            // s'étirer sur toute la largeur.
            readonly property real colW: (content.width - 22) / 2

            // ---- 0 · Général ---------------------------------------------
            Row {
                anchors.top: sectionTitle.bottom; anchors.topMargin: 14
                width: content.width
                spacing: 22
                visible: root.section === 0

                Column {
                    width: content.colW
                    spacing: 11
                    SettingRow { width: parent.width; iconName: "ph-globe-simple"; accentColor: Theme.purple; label: "Langue"; value: "Français"; chevron: "ph-caret-down" }
                    SettingRow { width: parent.width; iconName: "ph-ruler"; accentColor: Theme.blue; label: "Unités"; value: "Métrique"; chevron: "ph-caret-down" }
                    SettingRow { width: parent.width; iconName: "ph-clock"; accentColor: Theme.orange; label: "Heure"; value: AppState.time; chevron: "ph-caret-down" }
                    SettingRow { width: parent.width; iconName: "ph-calendar-blank"; accentColor: Theme.green; label: "Date"; value: "24 / 05 / 2026"; chevron: "ph-caret-right" }
                }
                Column {
                    width: content.colW
                    spacing: 11
                    SettingRow {
                        width: parent.width; iconName: "ph-clock-clockwise"; accentColor: Theme.blue
                        label: "Heure automatique"; sub: "Synchroniser l'heure avec le réseau"
                        ToggleSwitch { checked: AppState.autoTime; accentColor: Theme.blue; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.autoTime = !AppState.autoTime }
                    }
                    SettingRow { width: parent.width; iconName: "ph-globe-hemisphere-west"; accentColor: Theme.purple; label: "Fuseau horaire"; value: "GMT+01:00"; chevron: "ph-caret-right" }
                    SettingRow { width: parent.width; iconName: "ph-hand-tap"; accentColor: Theme.orange; label: "Retour tactile"; sub: "Vibration à l'appui"
                        ToggleSwitch { checked: AppState.spatial; accentColor: Theme.orange; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.spatial = !AppState.spatial }
                    }
                }
            }

            // ---- 1 · Affichage -------------------------------------------
            Row {
                anchors.top: sectionTitle.bottom; anchors.topMargin: 14
                width: content.width
                spacing: 22
                visible: root.section === 1

                Column {
                    width: content.colW
                    spacing: 11
                    PanelCard {
                        width: parent.width; height: 104; radius: 13
                        Column {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12
                            Item {
                                width: parent.width; height: 20
                                Text { anchors.left: parent.left; text: "LUMINOSITÉ"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted }
                                Text { anchors.right: parent.right; text: Math.round(AppState.brightness * 100) + " %"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.orange }
                            }
                            LevelBar {
                                width: parent.width
                                value: AppState.brightness
                                accentColor: Theme.orange
                                onMoved: (v) => AppState.brightness = v
                            }
                        }
                    }
                    SettingRow {
                        width: parent.width; iconName: "ph-sun"; accentColor: Theme.orange
                        label: "Luminosité automatique"; sub: "S'adapte à la lumière ambiante"
                        ToggleSwitch { checked: AppState.autoBrightness; accentColor: Theme.orange; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.autoBrightness = !AppState.autoBrightness }
                    }
                    SettingRow {
                        width: parent.width; iconName: "ph-eye"; accentColor: Theme.blue
                        label: "Mode nuit"; sub: "Assombrit l'écran après le coucher du soleil"
                        ToggleSwitch { checked: AppState.nightMode; accentColor: Theme.blue; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.nightMode = !AppState.nightMode }
                    }
                }
                Column {
                    width: content.colW
                    spacing: 11
                    Text { text: "THÈME"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted; topPadding: 4 }
                    SegmentedControl {
                        width: parent.width
                        options: ["Sombre", "Clair", "Auto"]
                        accentColor: Theme.blue
                        currentIndex: ["Sombre", "Clair", "Auto"].indexOf(AppState.uiTheme)
                        onSelected: (i) => AppState.uiTheme = ["Sombre", "Clair", "Auto"][i]
                    }
                    Text { text: "TAILLE DU TEXTE"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted; topPadding: 8 }
                    SegmentedControl {
                        width: parent.width
                        options: ["Petit", "Normal", "Grand"]
                        accentColor: Theme.blue
                        currentIndex: ["Petit", "Normal", "Grand"].indexOf(AppState.textSize)
                        onSelected: (i) => AppState.textSize = ["Petit", "Normal", "Grand"][i]
                    }
                    SettingRow { width: parent.width; iconName: "ph-clock-counter-clockwise"; accentColor: Theme.purple; label: "Mise en veille"; value: AppState.screenTimeout; chevron: "ph-caret-down" }
                }
            }

            // ---- 2 · Son --------------------------------------------------
            Row {
                anchors.top: sectionTitle.bottom; anchors.topMargin: 14
                width: content.width
                spacing: 22
                visible: root.section === 2

                Column {
                    width: content.colW
                    spacing: 11
                    PanelCard {
                        width: parent.width; height: 104; radius: 13
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
                    PanelCard {
                        width: parent.width; height: 104; radius: 13
                        Column {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 12
                            Item {
                                width: parent.width; height: 20
                                Text { anchors.left: parent.left; text: "VOLUME SONNERIE"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted }
                                Text { anchors.right: parent.right; text: Math.round(AppState.ringVolume * 100) + " %"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.DemiBold; color: Theme.blue }
                            }
                            LevelBar {
                                width: parent.width
                                value: AppState.ringVolume
                                accentColor: Theme.blue
                                onMoved: (v) => AppState.ringVolume = v
                            }
                        }
                    }
                    Text { text: "BALANCE"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted; topPadding: 4 }
                    SegmentedControl {
                        width: parent.width
                        options: ["Avant", "Centré", "Arrière"]
                        accentColor: Theme.purple
                        currentIndex: ["Avant", "Centré", "Arrière"].indexOf(AppState.balance)
                        onSelected: (i) => AppState.balance = ["Avant", "Centré", "Arrière"][i]
                    }
                }
                Column {
                    width: content.colW
                    spacing: 11
                    SettingRow {
                        width: parent.width; iconName: "ph-speaker-high"; accentColor: Theme.purple
                        label: "Son spatial"; sub: "Restitution enveloppante"
                        ToggleSwitch { checked: AppState.spatial; accentColor: Theme.purple; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.spatial = !AppState.spatial }
                    }
                    SettingRow {
                        width: parent.width; iconName: "ph-chat-circle-dots"; accentColor: Theme.blue
                        label: "Sons d'alerte"; sub: "Avertissements et notifications"
                        ToggleSwitch { checked: AppState.alertSounds; accentColor: Theme.blue; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.alertSounds = !AppState.alertSounds }
                    }
                    SettingRow {
                        width: parent.width; iconName: "ph-arrows-left-right"; accentColor: Theme.orange
                        label: "Bip de recul"; sub: "Signal sonore en marche arrière"
                        ToggleSwitch { checked: AppState.reverseBeep; accentColor: Theme.orange; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.reverseBeep = !AppState.reverseBeep }
                    }
                    SettingRow {
                        width: parent.width; iconName: "ph-navigation-arrow"; accentColor: Theme.green
                        label: "Guidage vocal"; sub: "Annonces de navigation"
                        ToggleSwitch { checked: AppState.voiceGuidance; accentColor: Theme.green; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.voiceGuidance = !AppState.voiceGuidance }
                    }
                    SettingRow { width: parent.width; iconName: "ph-faders"; accentColor: Theme.purple; label: "Égaliseur"; value: "Personnalisé"; chevron: "ph-caret-right" }
                }
            }

            // ---- 3 · Véhicule ---------------------------------------------
            Row {
                anchors.top: sectionTitle.bottom; anchors.topMargin: 14
                width: content.width
                spacing: 22
                visible: root.section === 3

                Column {
                    width: content.colW
                    spacing: 11
                    Text { text: "MODE DE CONDUITE PAR DÉFAUT"; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 1.4; color: Theme.textMuted; topPadding: 4 }
                    SegmentedControl {
                        width: parent.width
                        options: ["ECO", "NORMAL", "SPORT"]
                        accentColor: Theme.green
                        currentIndex: Math.max(0, ["ECO", "NORMAL", "SPORT"].indexOf(VehicleData.driveMode))
                        onSelected: (i) => VehicleData.driveMode = ["ECO", "NORMAL", "SPORT"][i]
                    }
                    SettingRow { width: parent.width; iconName: "ph-gauge"; accentColor: Theme.green; label: "Limite de vitesse"; value: VehicleData.speedLimit + " km/h"; chevron: "ph-caret-down" }
                    SettingRow { width: parent.width; iconName: "ph-tire"; accentColor: Theme.orange; label: "Unité de pression"; value: AppState.pressureUnit; chevron: "ph-caret-down" }
                }
                Column {
                    width: content.colW
                    spacing: 11
                    SettingRow {
                        width: parent.width; iconName: "ph-lock-simple-open"; accentColor: Theme.blue
                        label: "Verrouillage automatique"; sub: "Au démarrage du véhicule"
                        ToggleSwitch { checked: AppState.autoLock; accentColor: Theme.blue; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.autoLock = !AppState.autoLock }
                    }
                    SettingRow {
                        width: parent.width; iconName: "ph-headlights"; accentColor: Theme.orange
                        label: "Éclairage d'accueil"; sub: "S'allume à l'approche"
                        ToggleSwitch { checked: AppState.welcomeLighting; accentColor: Theme.orange; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.welcomeLighting = !AppState.welcomeLighting }
                    }
                    SettingRow {
                        width: parent.width; iconName: "ph-arrows-out-line-horizontal"; accentColor: Theme.purple
                        label: "Rétroviseurs rabattables"; sub: "Au verrouillage"
                        ToggleSwitch { checked: AppState.foldingMirrors; accentColor: Theme.purple; anchors.verticalCenter: parent.verticalCenter; onToggled: AppState.foldingMirrors = !AppState.foldingMirrors }
                    }
                    SettingRow { width: parent.width; iconName: "ph-wrench"; accentColor: Theme.green; label: "Entretien"; value: "Dans " + VehicleData.serviceDueIn + " km"; chevron: "ph-caret-right"; onClicked: AppState.go("entretien") }
                }
            }

            // ---- 4 · Système ----------------------------------------------
            Row {
                anchors.top: sectionTitle.bottom; anchors.topMargin: 14
                width: content.width
                spacing: 22
                visible: root.section === 4

                Column {
                    width: content.colW
                    spacing: 12
                    ImageAsset {
                        width: parent.width; height: 190; radius: 14
                        fillMode: Image.PreserveAspectFit
                        source: "qrc:/AgoojiyeHMI/assets/images/settings-car.png"
                    }
                    PanelCard {
                        width: parent.width
                        height: aboutCol.implicitHeight + 12
                        radius: 14
                        Column {
                            id: aboutCol
                            x: 18; y: 6
                            width: parent.width - 36
                            Repeater {
                                model: root.aboutRows
                                delegate: Column {
                                    required property var modelData
                                    width: aboutCol.width
                                    Item {
                                        width: parent.width
                                        height: 45
                                        Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: modelData.k; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }
                                        Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: modelData.v; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium; color: Theme.textPrimary }
                                    }
                                    Rectangle { width: parent.width; height: 1; color: Theme.alpha(Theme.textMuted, 0.12) }
                                }
                            }
                        }
                    }
                }
                Column {
                    width: content.colW
                    spacing: 11
                    SettingRow { width: parent.width; iconName: "ph-cube"; accentColor: Theme.blue; label: "Stockage"; value: VehicleData.storageUsed; chevron: "ph-caret-right" }
                    SettingRow { width: parent.width; iconName: "ph-cell-signal-full"; accentColor: Theme.green; label: "Réseau"; value: VehicleData.network }
                    SettingRow { width: parent.width; iconName: "ph-wifi-high"; accentColor: Theme.blue; label: "Wi-Fi"; value: VehicleData.wifiConnected ? "Connecté" : "Désactivé"; chevron: "ph-caret-right" }
                    SettingRow { width: parent.width; iconName: "ph-bluetooth"; accentColor: Theme.blue; label: "Bluetooth"; value: VehicleData.bluetoothConnected ? "Connecté" : "Désactivé"; chevron: "ph-caret-right" }
                    Rectangle {
                        width: parent.width; height: 54; radius: 13
                        border.width: 1; border.color: updHover.containsMouse ? Theme.blue : Theme.alpha(Theme.panelBorder, 0.3)
                        color: "transparent"
                        Row {
                            anchors.centerIn: parent
                            spacing: 12
                            Icon { name: "ph-arrows-clockwise"; size: 19; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Vérifier les mises à jour"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Medium; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: updHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                    }
                }
            }
        }
    }
}

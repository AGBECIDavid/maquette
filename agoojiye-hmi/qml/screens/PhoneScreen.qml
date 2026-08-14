import QtQuick
import AgoojiyeHMI

Item {
    id: root

    readonly property var calls: [
        { name: "Alice Martin", when: "Aujourd'hui  •  18:42", init: "AM", c1: "#1d4ed8", c2: "#7c3aed", now: true },
        { name: "Thomas K.", when: "Aujourd'hui  •  15:20", init: "TK", c1: "#0e7490", c2: "#2563eb", now: false },
        { name: "Sarah Johnson", when: "Hier  •  21:14", init: "SJ", c1: "#7c3aed", c2: "#db2777", now: false },
        { name: "David M.", when: "Hier  •  17:03", init: "DM", c1: "#166534", c2: "#0e7490", now: false },
        { name: "Julien Moreau", when: "Hier  •  12:11", init: "JM", c1: "#92400e", c2: "#b91c1c", now: false }
    ]

    Row {
        id: layout
        anchors.fill: parent
        anchors.topMargin: 20; anchors.bottomMargin: 20
        anchors.leftMargin: 32; anchors.rightMargin: 32
        spacing: 20

        Column {
            width: 330
            height: layout.height
            spacing: 12
            Text { text: "TÉLÉPHONE"; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.textPrimary; bottomPadding: 8; topPadding: 6 }

            Rectangle {
                width: parent.width; height: 88; radius: 14
                color: Theme.alpha(Theme.blue, 0.1)
                border.width: 1; border.color: Theme.blue
                Row {
                    anchors.fill: parent; anchors.margins: 18
                    spacing: 16
                    Rectangle {
                        width: 52; height: 52; radius: 26; color: "#2563eb"; anchors.verticalCenter: parent.verticalCenter
                        Icon { anchors.centerIn: parent; name: "ph-user"; fill: true; size: 24; color: "#ffffff" }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Contacts"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Text { text: "245 contacts"; font.family: Theme.fontFamily; font.pixelSize: 14; color: "#93c5fd" }
                    }
                }
                Icon { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; name: "ph-caret-right"; size: 17; color: Theme.textMuted }
            }

            PanelCard {
                width: parent.width; height: 88; radius: 14
                Row {
                    anchors.fill: parent; anchors.margins: 18
                    spacing: 16
                    Rectangle {
                        width: 52; height: 52; radius: 26; anchors.verticalCenter: parent.verticalCenter
                        color: Theme.alpha(Theme.purple, 0.15)
                        border.width: 1; border.color: Theme.alpha(Theme.purple, 0.4)
                        Icon { anchors.centerIn: parent; name: "ph-clock-counter-clockwise"; size: 24; color: Theme.purple }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Récents"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Text { text: "8 appels"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }
                    }
                }
                Icon { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; name: "ph-caret-right"; size: 17; color: Theme.textMuted }
            }

            PanelCard {
                width: parent.width; height: 88; radius: 14
                Row {
                    anchors.fill: parent; anchors.margins: 18
                    spacing: 16
                    Rectangle {
                        width: 52; height: 52; radius: 26; anchors.verticalCenter: parent.verticalCenter
                        color: Theme.alpha(Theme.blue, 0.12)
                        border.width: 1; border.color: Theme.alpha(Theme.blue, 0.4)
                        Icon { anchors.centerIn: parent; name: "ph-bluetooth"; size: 24; color: Theme.blue }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Bluetooth"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.textPrimary }
                        Text { text: "Connecté"; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }
                    }
                }
                Rectangle { anchors.right: parent.right; anchors.rightMargin: 18; anchors.verticalCenter: parent.verticalCenter; width: 11; height: 11; radius: 5.5; color: Theme.blue }
            }
        }

        PanelCard {
            width: layout.width - 330 - 470 - 40
            height: layout.height
            radius: 18
            color: "transparent"
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.alpha(Theme.panelBgTop, 0.7) }
                GradientStop { position: 1.0; color: Theme.alpha(Theme.panelBgBottom, 0.85) }
            }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 40
                spacing: 8

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 150; height: 150
                    ImageAsset {
                        anchors.fill: parent
                        radius: width / 2
                        source: "qrc:/AgoojiyeHMI/assets/images/avatar-alice.jpg"
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.bottom: parent.bottom
                        anchors.rightMargin: 2; anchors.bottomMargin: 2
                        width: 36; height: 36; radius: 18
                        color: "#2563eb"
                        border.width: 3; border.color: "#0a1120"
                        Icon { anchors.centerIn: parent; name: "ph-star"; fill: true; size: 16; color: "#ffffff" }
                    }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Alice Martin"; font.family: Theme.fontFamily; font.pixelSize: 34; font.weight: Font.Bold; color: Theme.textPrimary; topPadding: 10 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "+229 97 45 21 08"; font.family: Theme.fontFamily; font.pixelSize: 20; color: Theme.textSecondary }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 4
                    Text { text: "Mobile  •  "; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.textMuted }
                    Text { text: "Favori"; font.family: Theme.fontFamily; font.pixelSize: 15; color: Theme.blue }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    topPadding: 6
                    Rectangle { width: 9; height: 9; radius: 4.5; color: Theme.green; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "CONNECTÉ"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; font.letterSpacing: 1.2; color: Theme.green }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 14
                    topPadding: 16
                    Rectangle {
                        width: callRow.implicitWidth + 68; height: 56; radius: 14
                        color: callHover.containsMouse ? "#3b82f6" : "#2563eb"
                        Row { id: callRow; anchors.centerIn: parent; spacing: 12
                            Icon { name: "ph-phone"; fill: true; size: 20; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Appeler"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: callHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                    }
                    Rectangle {
                        width: msgRow.implicitWidth + 60; height: 56; radius: 14
                        color: Theme.alpha(Theme.panelBgTop, 0.8)
                        border.width: 1; border.color: msgHover.containsMouse ? Theme.blue : Theme.alpha(Theme.panelBorder, 0.3)
                        Row { id: msgRow; anchors.centerIn: parent; spacing: 12
                            Icon { name: "ph-chat-circle-dots"; size: 20; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Message"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.DemiBold; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: msgHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
                    }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    topPadding: 16
                    Rectangle {
                        width: lastCallRow.implicitWidth + 44; height: 46; radius: 12
                        color: Theme.alpha(Theme.navBg, 0.8)
                        border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.12)
                        Row {
                            id: lastCallRow
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { name: "ph-phone-call"; size: 18; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Dernier appel  •  "; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Aujourd'hui 18:42"; font.family: Theme.fontFamily; font.pixelSize: 14; color: "#93c5fd"; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }

        Column {
            width: 470
            height: layout.height
            spacing: 11
            Text { text: "CONTACTS RÉCENTS"; font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1; color: Theme.textPrimary; topPadding: 8; bottomPadding: 4 }
            Repeater {
                model: root.calls
                delegate: PanelCard {
                    width: parent.width; height: 68; radius: 13
                    border.color: Theme.alpha(Theme.panelBorder, 0.12)
                    Rectangle { width: 3; height: parent.height; radius: 1.5; color: modelData.now ? Theme.blue : "transparent" }
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 16
                        spacing: 14
                        Rectangle {
                            width: 46; height: 46; radius: 23
                            anchors.verticalCenter: parent.verticalCenter
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0.0; color: modelData.c1 }
                                GradientStop { position: 1.0; color: modelData.c2 }
                            }
                            Text { anchors.centerIn: parent; text: modelData.init; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Bold; color: "#ffffff" }
                        }
                        Column {
                            width: parent.width - 46 - 14 - 42 - 14
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.name; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: Theme.textPrimary }
                            Text { text: modelData.when; font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted }
                        }
                        Rectangle {
                            width: 42; height: 42; radius: 21
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.alpha(Theme.green, 0.12)
                            Icon { anchors.centerIn: parent; name: "ph-phone"; fill: true; size: 18; color: Theme.green }
                        }
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 52; radius: 13
                color: Theme.alpha(Theme.navBg, 0.9)
                border.width: 1; border.color: seeAllHover.containsMouse ? Theme.alpha(Theme.panelBorder, 0.4) : Theme.alpha(Theme.panelBorder, 0.14)
                Row {
                    anchors.centerIn: parent
                    spacing: 10
                    Text { text: "Voir tous les récents"; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; color: Theme.textPrimary }
                    Icon { name: "ph-caret-right"; size: 15; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: seeAllHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor }
            }
        }
    }
}

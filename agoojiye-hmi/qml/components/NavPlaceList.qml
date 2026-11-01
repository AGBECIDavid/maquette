import QtQuick
import AgoojiyeHMI

// Liste des lieux de la carte, pour choisir une destination ou un départ.
//
// Pas de clavier sur un écran de bord : on choisit par catégorie, et la liste
// est classée par distance *par la route* depuis la navette — le lieu le plus
// proche en vrai, pas à vol d'oiseau.
PanelCard {
    id: root
    radius: 18
    opaque: true

    // "destination" ou "origin" : le départ propose en plus « Ma position ».
    property string mode: "destination"
    property string category: ""
    property var distances: ({})

    signal picked(string id)
    signal closed()

    function refresh() { distances = Navigation.hasPosition ? Navigation.roadDistances() : ({}) }
    Component.onCompleted: refresh()
    onVisibleChanged: if (visible) { category = ""; refresh() }
    Timer { interval: 10000; running: root.visible; repeat: true; onTriggered: root.refresh() }

    // Catégories présentes dans la carte, dans un ordre utile.
    readonly property var categories: {
        var order = ["entree", "porte", "usine", "service", "sante", "marche", "restauration",
                     "commerce", "carburant", "ecole", "village", "repere"]
        var present = {}
        for (var i = 0; i < Navigation.places.length; i++)
            present[Navigation.places[i].category] = true
        return order.filter(function (c) { return present[c] })
    }

    readonly property var items: {
        var list = Navigation.places.filter(function (p) {
            return root.category === "" || p.category === root.category
        })
        var d = root.distances
        list = list.map(function (p) {
            var copy = {}
            for (var k in p) copy[k] = p[k]
            copy.dist = d[p.id] !== undefined ? d[p.id] : -1
            return copy
        })
        list.sort(function (a, b) {
            if (a.dist < 0 && b.dist < 0) return a.name.localeCompare(b.name)
            if (a.dist < 0) return 1
            if (b.dist < 0) return -1
            return a.dist - b.dist
        })
        return list
    }

    Column {
        id: head
        x: 20; y: 18
        width: parent.width - 40
        spacing: 14

        Row {
            spacing: 12
            Rectangle {
                width: 40; height: 40; radius: 20
                color: backHover.containsMouse ? Theme.alpha(Theme.textMuted, 0.18) : "transparent"
                Icon { anchors.centerIn: parent; name: "ph-arrow-left"; size: 20; color: Theme.textPrimary }
                MouseArea { id: backHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.closed() }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.mode === "origin" ? "Point de départ" : "Où allez-vous ?"
                font.family: Theme.fontFamily; font.pixelSize: 21; font.weight: Font.DemiBold; color: Theme.textPrimary
            }
        }

        // Catégories : une ligne qui défile si elle déborde.
        Flickable {
            width: parent.width
            height: 38
            contentWidth: chips.implicitWidth
            flickableDirection: Flickable.HorizontalFlick
            clip: true
            Row {
                id: chips
                spacing: 8
                Repeater {
                    model: [""].concat(root.categories)
                    delegate: Rectangle {
                        readonly property bool on: root.category === modelData
                        height: 36; radius: 18
                        width: chipRow.implicitWidth + 28
                        color: on ? Theme.alpha(Theme.blue, 0.28) : Theme.alpha("#ffffff", 0.05)
                        border.width: 1
                        border.color: on ? Theme.alpha(Theme.blue, 0.7) : Theme.alpha(Theme.panelBorder, 0.18)
                        Row {
                            id: chipRow
                            anchors.centerIn: parent
                            spacing: 7
                            Icon {
                                visible: modelData !== ""
                                name: modelData !== "" ? Navigation.categoryIcon(modelData) : ""
                                size: 15; color: parent.parent.on ? Theme.blueLighter : Theme.textSecondary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Text {
                                text: modelData === "" ? "Tout" : Navigation.categoryLabel(modelData)
                                font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium
                                color: parent.parent.on ? Theme.textPrimary : Theme.textSecondary
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.category = modelData }
                    }
                }
            }
        }
        Divider { width: parent.width }
    }

    ListView {
        id: list
        x: 12
        anchors.top: head.bottom
        anchors.topMargin: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: parent.width - 24
        clip: true
        spacing: 2
        boundsBehavior: Flickable.StopAtBounds

        header: Item {
            width: list.width
            height: root.mode === "origin" ? 64 : 0
            visible: root.mode === "origin"
            Rectangle {
                anchors.fill: parent
                anchors.bottomMargin: 4
                radius: 12
                color: hereHover.containsMouse ? Theme.alpha(Theme.blue, 0.16) : "transparent"
                Row {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    Rectangle {
                        width: 40; height: 40; radius: 20
                        color: Theme.alpha(Theme.blue, 0.22)
                        Icon { anchors.centerIn: parent; name: "ph-navigation-arrow"; fill: true; size: 18; color: Theme.blueLight }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Ma position"
                        font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Medium; color: Theme.textPrimary
                    }
                }
                MouseArea { id: hereHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked("") }
            }
        }

        model: root.items
        delegate: Rectangle {
            width: list.width
            height: 64
            radius: 12
            color: rowHover.containsMouse ? Theme.alpha(Theme.blue, 0.12) : "transparent"
            readonly property bool recent: Navigation.recents.indexOf(modelData.id) >= 0

            Rectangle {
                id: badge
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 40; height: 40; radius: 20
                color: Theme.alpha(Theme.textMuted, 0.14)
                Icon {
                    anchors.centerIn: parent
                    name: parent.parent.recent ? "ph-clock-counter-clockwise" : modelData.icon
                    size: 18; color: Theme.textSecondary
                }
            }
            Column {
                anchors.left: badge.right
                anchors.leftMargin: 14
                anchors.right: dist.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: modelData.name
                    font.family: Theme.fontFamily; font.pixelSize: 17; font.weight: Font.Medium; color: Theme.textPrimary
                }
                Text {
                    width: parent.width; elide: Text.ElideRight
                    text: modelData.label + (modelData.note ? " · " + modelData.note : "")
                    font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted
                }
            }
            Text {
                id: dist
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.dist >= 0 ? Navigation.formatDistance(modelData.dist) : ""
                font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Medium; color: Theme.textSecondary
            }
            MouseArea { id: rowHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.picked(modelData.id) }
        }
    }
}

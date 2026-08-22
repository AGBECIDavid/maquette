import QtQuick
import AgoojiyeHMI

// Ligne de réglage : pastille d'icône, libellé (sous-titre optionnel), puis à
// droite une valeur, un contrôle fourni par l'appelant, un chevron — ou rien.
//
// C'est le motif qui revient dans presque tous les panneaux ; le sortir ici
// évite de le réécrire trente fois et garde les écrans lisibles.
//
// Tout est ancré plutôt qu'empilé dans un Row : les éléments de droite se
// dimensionnent seuls et la colonne de texte prend ce qui reste, sans que
// personne ait à calculer une largeur en fonction de ses voisins.
PanelCard {
    id: root

    property string iconName: ""
    property color accentColor: Theme.blue
    property string label: ""
    property string sub: ""
    property string value: ""
    property string chevron: ""
    signal clicked()

    // Ce qu'on glisse dans la ligne (interrupteur, sélecteur…) atterrit ici.
    default property alias control: trailing.data

    height: sub === "" ? 60 : 68
    radius: 13
    border.color: rowHover.containsMouse && root.chevron !== ""
                  ? Theme.alpha(root.accentColor, 0.5)
                  : Theme.alpha(Theme.panelBorder, 0.12)

    Item {
        anchors.fill: parent
        anchors.leftMargin: 18
        anchors.rightMargin: 18

        Rectangle {
            id: badge
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 42; height: 42; radius: 21
            color: Theme.alpha(root.accentColor, 0.12)
            Icon { anchors.centerIn: parent; name: root.iconName; size: 20; color: root.accentColor }
        }

        Icon {
            id: chev
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            name: root.chevron
            size: 15
            color: Theme.textMuted
            visible: root.chevron !== ""
            width: visible ? 15 : 0
        }

        Item {
            id: trailing
            anchors.right: chev.left
            anchors.rightMargin: chev.visible ? 12 : 0
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: parent.height
        }

        Text {
            id: valueText
            anchors.right: trailing.left
            anchors.rightMargin: trailing.width > 0 ? 12 : 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.value
            font.family: Theme.fontFamily
            font.pixelSize: 15
            color: Theme.textDim
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: 15
            anchors.right: valueText.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1

            Text {
                width: parent.width
                text: root.label
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 16
                font.weight: Font.Medium
                color: Theme.textPrimary
            }
            Text {
                width: parent.width
                text: root.sub
                visible: root.sub !== ""
                elide: Text.ElideRight
                font.family: Theme.fontFamily
                font.pixelSize: 12
                color: Theme.textMuted
            }
        }
    }

    MouseArea {
        id: rowHover
        anchors.fill: parent
        hoverEnabled: true
        // Seules les lignes qui mènent quelque part se comportent en bouton.
        cursorShape: root.chevron !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: root.chevron !== "" ? Qt.LeftButton : Qt.NoButton
        onClicked: root.clicked()
    }
}

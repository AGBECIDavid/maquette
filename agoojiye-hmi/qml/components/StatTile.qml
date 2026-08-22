import QtQuick
import AgoojiyeHMI

// Tuile de mesure : intitulé discret, valeur en gros, unité à côté. Sert à
// tous les panneaux qui exposent des relevés (énergie, températures, pneus).
PanelCard {
    id: root

    property string label: ""
    property string value: ""
    property string unit: ""
    property color valueColor: Theme.textPrimary
    property string iconName: ""

    height: 96
    radius: 14

    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        spacing: 8

        Row {
            spacing: 8
            Icon {
                name: root.iconName
                visible: root.iconName !== ""
                size: 16
                color: Theme.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.label
                font.family: Theme.fontFamily
                font.pixelSize: 12
                font.weight: Font.DemiBold
                font.letterSpacing: 1.4
                color: Theme.textMuted
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Row {
            spacing: 6
            Text {
                id: valueText
                text: root.value
                font.family: Theme.fontFamily
                font.pixelSize: 27
                font.weight: Font.Bold
                color: root.valueColor
            }
            Text {
                text: root.unit
                font.family: Theme.fontFamily
                font.pixelSize: 14
                color: Theme.textMuted
                anchors.baseline: valueText.baseline
            }
        }
    }
}

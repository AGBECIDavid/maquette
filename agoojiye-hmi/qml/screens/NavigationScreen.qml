import QtQuick
import AgoojiyeHMI

// Navigation : la carte de la zone industrielle de Glo-Djigbé, le choix de la
// destination, les itinéraires, le guidage.
//
// Tout est embarqué — carte, calcul d'itinéraire, consignes. L'écran ne fait
// que montrer `Navigation` et piloter la caméra de la carte :
//
//   · sans destination : la carte suit la navette, nord en haut ;
//   · aperçu : la carte cadre les itinéraires proposés, à côté du panneau ;
//   · guidage : la carte suit la navette, cap en haut, vue placée bas pour
//     voir loin devant. Un glissement du doigt détache la caméra ; le bouton
//     de recentrage la raccroche.
Item {
    id: root
    objectName: "navigationScreen"
    clip: true

    // ---- caméra ------------------------------------------------------------
    property bool follow: true
    property bool headingUp: false
    // Coupé pendant un geste : la carte doit coller au doigt, pas le rattraper.
    property bool animate: true
    // Vrai le temps d'un recadrage : les animations sont alors longues et
    // amorties ; sinon, en suivi, elles durent un pas de position (110 ms).
    property bool glide: false
    readonly property bool guiding: Navigation.state === "guiding" || Navigation.state === "arrived"

    // ---- panneaux ----------------------------------------------------------
    // "" · "search" (choisir la destination) · "origin" (choisir le départ) ·
    // "steps" (détail de l'itinéraire)
    property string panel: ""
    property string selectedId: ""
    readonly property real panelWidth: 440
    readonly property real controlsWidth: 100

    function glideFor(ms) { glide = true; glideTimer.interval = ms; glideTimer.restart() }
    Timer { id: glideTimer; interval: 600; onTriggered: root.glide = false }

    function recenter() {
        glideFor(600)
        follow = true
        if (!guiding)
            map.bearing = 0
    }

    function frameRoutes() {
        // Appelé en différé : entre-temps, le guidage a pu démarrer, et la
        // caméra appartient alors au suivi.
        if (Navigation.state !== "preview")
            return
        var b = map.routeBounds()
        if (b.width <= 0 && b.height <= 0)
            return
        // Sans itinéraire (position inconnue), il ne reste que la destination :
        // on la montre dans son quartier, pas à bout portant.
        if (b.width < 400 && b.height < 400)
            b = Qt.rect(b.x + b.width / 2 - 400, b.y + b.height / 2 - 400, 800, 800)
        follow = false
        headingUp = false
        glideFor(700)
        var f = map.fit(b, 24 + panelWidth + 40, 80, controlsWidth + 40, 70)
        map.bearing = 0
        map.zoom = f.zoom
        map.centerX = f.x
        map.centerY = f.y
    }

    function zoomBy(factor, px, py) {
        if (px === undefined || follow) {
            glideFor(320)
            map.zoom = map.zoom * factor
            return
        }
        // Zoom autour du point visé : ce qui est sous le doigt y reste.
        animate = false
        var before = map.toMap(px, py)
        map.zoom = map.zoom * factor
        var after = map.toMap(px, py)
        map.centerX += before.x - after.x
        map.centerY += before.y - after.y
        animate = true
    }

    function pan(dx, dy) {
        var cx = map.width / 2, cy = map.height / 2
        var a = map.toMap(cx, cy), b = map.toMap(cx - dx, cy - dy)
        map.centerX += b.x - a.x
        map.centerY += b.y - a.y
    }

    Connections {
        target: Navigation
        function onStateChanged() {
            root.selectedId = ""
            if (Navigation.state === "preview") {
                root.panel = ""
                root.framedFor = Navigation.destinationName + "|" + Navigation.originId
                Qt.callLater(root.frameRoutes)
            } else if (Navigation.state === "guiding") {
                root.panel = ""
                root.glideFor(800)
                root.follow = true
                root.headingUp = true
                map.zoom = 1.1
            } else if (Navigation.state === "idle") {
                root.panel = ""
                root.glideFor(800)
                root.follow = true
                root.headingUp = false
                map.zoom = 0.42
            }
        }
        function onRoutesChanged() {
            // Nouvelle destination ou nouveau départ en aperçu : on recadre.
            if (Navigation.state === "preview" && root.framedFor !== Navigation.destinationName + "|" + Navigation.originId) {
                root.framedFor = Navigation.destinationName + "|" + Navigation.originId
                Qt.callLater(root.frameRoutes)
            }
        }
    }
    property string framedFor: ""

    // ---- la carte ------------------------------------------------------------
    MapView {
        id: map
        objectName: "navigationMap"
        anchors.fill: parent
        zoom: 0.42
        selectedPlace: root.selectedId

        // La position arrive dix fois par seconde ; on interpole entre deux
        // mesures pour que la navette glisse au lieu de sautiller.
        vehicleX: Navigation.vehicleX
        vehicleY: Navigation.vehicleY
        vehicleHeading: Navigation.vehicleHeading
        Behavior on vehicleX { NumberAnimation { duration: 110 } }
        Behavior on vehicleY { NumberAnimation { duration: 110 } }
        Behavior on vehicleHeading { RotationAnimation { duration: 220; direction: RotationAnimation.Shortest } }

        // En guidage, la navette se tient bas dans l'écran, décalée vers la
        // droite du panneau de manœuvre : on voit la route devant.
        anchorX: root.follow && root.guiding ? 0.5 + (root.panelWidth / 2) / Math.max(1, width) * 0.6 : 0.5
        anchorY: root.follow && root.guiding ? 0.70 : 0.5
        Behavior on anchorX { enabled: root.animate; NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }
        Behavior on anchorY { enabled: root.animate; NumberAnimation { duration: 600; easing.type: Easing.InOutCubic } }

        Behavior on centerX { enabled: root.animate; NumberAnimation { duration: root.glide ? 600 : 110; easing.type: root.glide ? Easing.InOutCubic : Easing.Linear } }
        Behavior on centerY { enabled: root.animate; NumberAnimation { duration: root.glide ? 600 : 110; easing.type: root.glide ? Easing.InOutCubic : Easing.Linear } }
        Behavior on zoom { enabled: root.animate; NumberAnimation { duration: root.glide ? 600 : 250; easing.type: Easing.InOutCubic } }
        Behavior on bearing { enabled: root.animate; RotationAnimation { duration: root.glide ? 600 : 300; direction: RotationAnimation.Shortest } }

        Component.onCompleted: {
            var e = Navigation.extent
            centerX = Navigation.hasPosition ? Navigation.vehicleX : e.x + e.width / 2
            centerY = Navigation.hasPosition ? Navigation.vehicleY : e.y + e.height / 2
        }
    }

    // Suivi de la navette : la caméra se raccroche à sa position.
    Binding {
        target: map; property: "centerX"; value: Navigation.vehicleX
        when: root.follow && Navigation.hasPosition
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: map; property: "centerY"; value: Navigation.vehicleY
        when: root.follow && Navigation.hasPosition
        restoreMode: Binding.RestoreNone
    }
    Binding {
        target: map; property: "bearing"; value: Navigation.vehicleHeading
        when: root.follow && root.headingUp
        restoreMode: Binding.RestoreNone
    }

    // ---- gestes --------------------------------------------------------------
    // Glisser déplace, pincer ou la molette zoome, toucher un lieu l'ouvre, un
    // appui long pose une destination, un double appui zoome.
    PinchArea {
        anchors.fill: parent
        onPinchStarted: { root.follow = false; root.animate = false }
        onPinchUpdated: function (pinch) {
            root.zoomBy(pinch.scale / pinch.previousScale, pinch.center.x, pinch.center.y)
            root.animate = false
        }
        onPinchFinished: root.animate = true

        MouseArea {
            id: touch
            anchors.fill: parent
            property point last
            property bool dragging: false
            pressAndHoldInterval: 650

            onPressed: function (m) { last = Qt.point(m.x, m.y); dragging = false }
            onPositionChanged: function (m) {
                var dx = m.x - last.x, dy = m.y - last.y
                if (!dragging && Math.abs(dx) + Math.abs(dy) < 8)
                    return
                if (!dragging) {
                    dragging = true
                    root.follow = false
                    root.animate = false
                }
                root.pan(dx, dy)
                last = Qt.point(m.x, m.y)
            }
            onReleased: { if (dragging) root.animate = true }
            onClicked: function (m) {
                if (dragging)
                    return
                var p = map.toMap(m.x, m.y)
                root.selectedId = Navigation.placeAt(p.x, p.y, 26 * map.metersPerPixel)
            }
            onDoubleClicked: function (m) { root.zoomBy(2, m.x, m.y) }
            onPressAndHold: function (m) {
                if (dragging || root.guiding)
                    return
                var p = map.toMap(m.x, m.y)
                root.selectedId = ""
                Navigation.previewPoint(p.x, p.y)
            }
            onWheel: function (w) { root.zoomBy(w.angleDelta.y > 0 ? 1.25 : 0.8, w.x, w.y) }
        }
    }

    // ---- état du GPS -----------------------------------------------------------
    Rectangle {
        id: gpsChip
        readonly property string st: Navigation.positionState
        visible: st !== "ok"
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: (root.panelWidth + 24) / 2 - root.controlsWidth / 2
        y: 20
        height: 44; radius: 22
        width: gpsRow.implicitWidth + 36
        color: Theme.alpha("#0b111c", 0.92)
        border.width: 1
        border.color: st === "estimated" ? Theme.alpha(Theme.orange, 0.7)
                    : st === "lost" ? Theme.alpha(Theme.red, 0.7) : Theme.alpha(Theme.yellow, 0.6)
        Row {
            id: gpsRow
            anchors.centerIn: parent
            spacing: 10
            Icon {
                name: gpsChip.st === "searching" ? "ph-gps" : "ph-gps-slash"
                size: 19
                color: gpsChip.st === "estimated" ? Theme.orange : gpsChip.st === "lost" ? Theme.red : Theme.yellow
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: gpsChip.visible && gpsChip.st === "searching"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 600 }
                    NumberAnimation { to: 1; duration: 600 }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: gpsChip.st === "searching" ? (Navigation.hasPosition ? "Recherche du signal GPS — dernière position connue"
                                                                           : "Recherche du signal GPS…")
                    : gpsChip.st === "estimated" ? "Signal GPS perdu — position estimée"
                    : root.guiding ? "Position perdue — guidage suspendu" : "Position GPS perdue"
                font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium; color: Theme.textPrimary
            }
        }
    }

    // ---- sans destination : la barre de recherche -----------------------------
    PanelCard {
        id: searchCard
        visible: Navigation.state === "idle" && root.panel === ""
        x: 24; y: 20
        width: root.panelWidth
        height: sCol.implicitHeight + 28
        radius: 18
        opaque: true

        Column {
            id: sCol
            x: 14; y: 14
            width: parent.width - 28
            spacing: 10

            Rectangle {
                width: parent.width; height: 56; radius: 14
                color: whereHover.containsMouse ? Theme.alpha("#ffffff", 0.09) : Theme.alpha("#ffffff", 0.05)
                border.width: 1; border.color: Theme.alpha(Theme.panelBorder, 0.2)
                Row {
                    x: 18
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 14
                    Icon { name: "ph-magnifying-glass"; size: 21; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Où allez-vous ?"; font.family: Theme.fontFamily; font.pixelSize: 18; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: whereHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.panel = "search" }
            }

            // Les dernières destinations, à un toucher.
            Repeater {
                model: Navigation.recents.slice(0, 3)
                delegate: Rectangle {
                    readonly property var p: Navigation.place(modelData)
                    width: sCol.width; height: 48; radius: 12
                    color: recHover.containsMouse ? Theme.alpha(Theme.blue, 0.12) : "transparent"
                    Row {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 14
                        Icon { name: "ph-clock-counter-clockwise"; size: 18; color: Theme.textMuted; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: parent.parent.p.name || ""; font.family: Theme.fontFamily; font.pixelSize: 16; color: Theme.textPrimary; anchors.verticalCenter: parent.verticalCenter }
                    }
                    MouseArea { id: recHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Navigation.preview(modelData) }
                }
            }
        }
    }

    // ---- choisir un lieu --------------------------------------------------------
    NavPlaceList {
        visible: root.panel === "search" || root.panel === "origin"
        mode: root.panel === "origin" ? "origin" : "destination"
        x: 24; y: 20
        width: root.panelWidth
        height: parent.height - 40
        onClosed: root.panel = ""
        onPicked: function (id) {
            if (root.panel === "origin") {
                root.panel = ""
                Navigation.setOrigin(id)
            } else {
                root.panel = ""
                Navigation.preview(id)
            }
        }
    }

    // ---- aperçu des itinéraires ---------------------------------------------------
    NavRoutePanel {
        visible: Navigation.state === "preview" && root.panel === ""
        x: 24; y: 20
        width: root.panelWidth
        onChooseOrigin: root.panel = "origin"
        onShowSteps: root.panel = "steps"
    }

    // ---- guidage -------------------------------------------------------------------
    NavGuidancePanel {
        anchors.fill: parent
        visible: root.guiding && root.panel === ""
        rightInset: root.controlsWidth
        onShowSteps: root.panel = "steps"
    }

    NavStepList {
        visible: root.panel === "steps"
        x: 24; y: 20
        width: root.panelWidth
        height: parent.height - 40
        readonly property var route: Navigation.routes.length > 0 ? Navigation.routes[Navigation.selectedRoute] : null
        title: root.guiding ? "Prochaines étapes" : "Étapes"
        subtitle: route ? (root.guiding ? Navigation.formatDistance(Navigation.remainingDistance) + " · " + Navigation.formatDuration(Navigation.remainingTime)
                                        : route.distanceText + " · " + route.durationText + (route.via !== "" ? " · " + route.via : ""))
                        : ""
        steps: root.guiding ? Navigation.upcomingSteps : (route ? route.steps : [])
        onClosed: root.panel = ""
    }

    // ---- fiche d'un lieu touché ----------------------------------------------------
    PanelCard {
        id: placeCard
        readonly property var p: root.selectedId !== "" ? Navigation.place(root.selectedId) : null
        visible: p !== null && root.panel === ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: Navigation.state === "idle" ? 0 : (root.panelWidth + 24) / 2
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.guiding ? 124 : 24
        width: 560
        height: 96
        radius: 18
        opaque: true

        Rectangle {
            id: pBadge
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            width: 52; height: 52; radius: 26
            color: Theme.alpha(Theme.blue, 0.2)
            Icon { anchors.centerIn: parent; name: placeCard.p ? placeCard.p.icon : ""; size: 23; color: Theme.blueLight }
        }
        Column {
            anchors.left: pBadge.right
            anchors.leftMargin: 16
            anchors.right: goBtn.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Text {
                width: parent.width; elide: Text.ElideRight
                text: placeCard.p ? placeCard.p.name : ""
                font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.DemiBold; color: Theme.textPrimary
            }
            Text {
                width: parent.width; elide: Text.ElideRight
                text: placeCard.p ? placeCard.p.label + (placeCard.p.note ? " · " + placeCard.p.note : "") : ""
                font.family: Theme.fontFamily; font.pixelSize: 13; color: Theme.textMuted
            }
        }
        Rectangle {
            id: goBtn
            anchors.right: closeP.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            height: 50; radius: 14
            width: goRow.implicitWidth + 32
            color: goHover.containsMouse ? Theme.blueLight : Theme.blue
            Row {
                id: goRow
                anchors.centerIn: parent
                spacing: 8
                Icon { name: "ph-navigation-arrow"; fill: true; size: 17; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: root.guiding ? "Y aller plutôt" : "Itinéraire"; font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.DemiBold; color: "#ffffff"; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea {
                id: goHover
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: { var id = root.selectedId; root.selectedId = ""; Navigation.preview(id) }
            }
        }
        Rectangle {
            id: closeP
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 20
            color: closeHover.containsMouse ? Theme.alpha(Theme.textMuted, 0.18) : "transparent"
            Icon { anchors.centerIn: parent; name: "ph-x"; size: 17; color: Theme.textMuted }
            MouseArea { id: closeHover; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selectedId = "" }
        }
    }

    // ---- commandes de la carte -------------------------------------------------------
    Column {
        anchors.right: parent.right
        anchors.rightMargin: 24
        y: 20
        spacing: 12

        // Boussole : elle montre où est le nord. Un toucher bascule entre
        // « nord en haut » et « cap en haut » (en suivi), ou remet le nord en
        // haut (carte détachée).
        Rectangle {
            width: 56; height: 56; radius: 28
            color: Theme.alpha("#0b111c", 0.92)
            border.width: 1; border.color: root.headingUp ? Theme.alpha(Theme.blue, 0.7) : Theme.alpha(Theme.panelBorder, 0.22)
            Item {
                anchors.fill: parent
                rotation: -map.bearing
                Icon { anchors.horizontalCenter: parent.horizontalCenter; y: 5; name: "ph-caret-up"; fill: true; size: 15; color: Theme.red }
                Text { anchors.centerIn: parent; anchors.verticalCenterOffset: 5; text: "N"; font.family: Theme.fontFamily; font.pixelSize: 14; font.weight: Font.Bold; color: Theme.textPrimary }
            }
            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.glideFor(500)
                    if (root.follow) {
                        root.headingUp = !root.headingUp
                        if (!root.headingUp)
                            map.bearing = 0
                    } else {
                        map.bearing = 0
                    }
                }
            }
        }
        Repeater {
            model: [
                { icon: "ph-plus", act: "in" },
                { icon: "ph-minus", act: "out" },
                { icon: "ph-crosshair-simple", act: "center" }
            ]
            delegate: Rectangle {
                readonly property bool lit: modelData.act === "center" && !root.follow
                width: 56; height: 56; radius: 28
                color: ctlHover.containsMouse ? Theme.alpha("#1a2333", 0.95) : Theme.alpha("#0b111c", 0.92)
                border.width: 1; border.color: lit ? Theme.alpha(Theme.blue, 0.8) : Theme.alpha(Theme.panelBorder, 0.22)
                Icon { anchors.centerIn: parent; name: modelData.icon; size: 22; color: parent.lit ? Theme.blueLight : Theme.textPrimary }
                MouseArea {
                    id: ctlHover
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (modelData.act === "in") root.zoomBy(1.6)
                        else if (modelData.act === "out") root.zoomBy(1 / 1.6)
                        else root.recenter()
                    }
                }
            }
        }
    }

    // ---- échelle et attribution -------------------------------------------------------
    // L'échelle prend une longueur ronde (1, 2 ou 5 × 10ⁿ m) proche de 110 px.
    Item {
        id: scaleBar
        readonly property real meters: {
            var target = 110 * map.metersPerPixel
            var p = Math.pow(10, Math.floor(Math.log(target) / Math.LN10))
            var m = target / p
            return (m >= 5 ? 5 : m >= 2 ? 2 : 1) * p
        }
        anchors.right: parent.right
        anchors.rightMargin: root.controlsWidth + 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.guiding && root.panel === "" ? 116 : 28
        width: meters / map.metersPerPixel
        height: 26
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: scaleBar.meters >= 1000 ? (scaleBar.meters / 1000) + " km" : scaleBar.meters + " m"
            font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Medium; color: Theme.textSecondary
            style: Text.Outline; styleColor: "#0b111c"
        }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 3; radius: 1.5; color: Theme.textSecondary }
    }

    // Exigée par la licence ODbL : toujours visible, jamais masquée.
    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: Navigation.attribution + (Navigation.mapDate !== "" ? " · carte du " + Navigation.mapDate : "")
        font.family: Theme.fontFamily; font.pixelSize: 11; color: Theme.textMuted
        style: Text.Outline; styleColor: "#0b111c"
    }

    // ---- carte absente ---------------------------------------------------------------
    Column {
        visible: !Navigation.ready
        anchors.centerIn: parent
        spacing: 10
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "ph-map-trifold"; size: 48; color: Theme.textMuted }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Carte indisponible"; font.family: Theme.fontFamily; font.pixelSize: 20; font.weight: Font.DemiBold; color: Theme.textPrimary }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Navigation.loadError; font.family: Theme.fontFamily; font.pixelSize: 14; color: Theme.textMuted }
    }
}

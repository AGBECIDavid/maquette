import QtQuick

// Replaces the design tool's <image-slot> with a real bundled image, clipped to
// a rounded shape. Rendering deliberately avoids shader effects so it looks the
// same on software-rendered embedded targets as it does on a GPU.
//
// Artwork that has to bleed into the page rather than sit in a frame carries a
// baked alpha falloff in the asset itself, so it composites correctly over any
// backdrop without this component having to know the colour behind it.
// Set `radius: width / 2` for a circular slot.
Rectangle {
    property alias source: img.source
    property alias fillMode: img.fillMode

    color: "transparent"
    clip: true

    Image {
        id: img
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        mipmap: true
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects

// Общая отрисовка и окраска иконок trigger-виджетов status bar.
Item {
    id: root

    required property url iconSource
    required property color tintColor
    property real devicePixelRatio: 1

    Image {
        id: sourceImage
        anchors.fill: parent
        source: root.iconSource
        sourceSize.width: Math.ceil(width * root.devicePixelRatio)
        sourceSize.height: Math.ceil(height * root.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
        smooth: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: sourceImage
        colorization: 1.0
        colorizationColor: root.tintColor
    }
}

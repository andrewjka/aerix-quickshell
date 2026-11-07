import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

// RectangularShadow рисует силуэт, а OpacityMask вырезает его середину.
// Поэтому тень не окрашивает полупрозрачную заливку панели.
Item {
    id: shadow
    required property Rectangle sourceItem
    readonly property real extent: Math.max(0, Metrics.panelShadowRadius) + 1

    anchors.fill: sourceItem
    scale: sourceItem.scale
    transformOrigin: sourceItem.transformOrigin

    Item {
        id: shadowSource
        x: -shadow.extent
        y: -shadow.extent
        width: shadow.width + 2 * shadow.extent
        height: shadow.height + 2 * shadow.extent
        visible: false

        RectangularShadow {
            x: shadow.extent
            y: shadow.extent
            width: shadow.width
            height: shadow.height
            topLeftRadius: shadow.sourceItem.topLeftRadius
            topRightRadius: shadow.sourceItem.topRightRadius
            bottomLeftRadius: shadow.sourceItem.bottomLeftRadius
            bottomRightRadius: shadow.sourceItem.bottomRightRadius
            blur: Math.max(0, Metrics.panelShadowRadius)
            color: Metrics.panelShadowColor
        }
    }

    // Маска — непрозрачная форма капсулы; инверсия в OpacityMask вырезает
    // её из тени. Маска и источник скрыты от сцены. Оба буфера включают
    // одинаковый запас вокруг силуэта панели.
    Item {
        id: panelMask
        anchors.fill: shadowSource
        visible: false

        Rectangle {
            x: shadow.extent
            y: shadow.extent
            width: shadow.width
            height: shadow.height
            topLeftRadius: shadow.sourceItem.topLeftRadius
            topRightRadius: shadow.sourceItem.topRightRadius
            bottomLeftRadius: shadow.sourceItem.bottomLeftRadius
            bottomRightRadius: shadow.sourceItem.bottomRightRadius
            color: "white"
            antialiasing: true
        }
    }

    OpacityMask {
        anchors.fill: shadowSource
        source: shadowSource
        maskSource: panelMask
        invert: true
    }
}

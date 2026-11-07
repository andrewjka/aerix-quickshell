import Qt5Compat.GraphicalEffects
import QtQuick

// Общий визуальный эффект для поверхностей панелей. Тень объявляется до
// поверхности, поэтому сама поверхность остаётся поверх размытого силуэта.
DropShadow {
    required property Item sourceItem

    anchors.fill: sourceItem
    source: sourceItem
    radius: Metrics.panelShadowRadius
    samples: Metrics.panelShadowSamples
    color: Metrics.panelShadowColor
    horizontalOffset: 0
    verticalOffset: 0
    spread: 0
    transparentBorder: true
}

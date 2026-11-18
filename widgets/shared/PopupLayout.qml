import QtQuick
import "../../core"

// Геометрия popup без Wayland-окна: её используют также отдельные toast-карточки.
// Запас учитывает полный spring overshoot и тень, а не только конечный размер.
QtObject {
    required property var barWindow
    required property Item anchorItem
    required property real surfaceHeight
    property real preferredWidth: 280
    readonly property real surfaceWidth: Math.min(preferredWidth,
        barWindow.screen.width - 2 * Metrics.statusBarHorizontalMargin)
    readonly property int revealTravel: 24
    readonly property real scaleOverflow: Math.max(0, Metrics.spring.maximumScale - 1)
    readonly property real progressOverflow: Math.max(0, Metrics.spring.maximumProgress - 1)
    readonly property int shadowMargin: Math.ceil(Metrics.panelShadowRadius) + 1
    readonly property int topMargin: shadowMargin + revealTravel
    readonly property int bottomOverflow: Math.ceil(revealTravel * progressOverflow)
    readonly property int bottomMargin: shadowMargin + bottomOverflow
        + Math.ceil(surfaceHeight * scaleOverflow)
    readonly property int horizontalMargin: shadowMargin
        + Math.ceil(surfaceWidth * scaleOverflow / 2)
    readonly property int popupTop: barWindow.height + 2 * Metrics.spacing
    readonly property real surfaceX: {
        // mapToItem не подписывает binding на перемещения якоря.
        const anchorX = anchorItem.x;
        const position = anchorItem.mapToItem(barWindow.contentItem, 0, 0);
        return Math.round(Math.max(Metrics.statusBarHorizontalMargin,
            Math.min(position.x + anchorItem.width / 2 - surfaceWidth / 2,
                barWindow.width - Metrics.statusBarHorizontalMargin - surfaceWidth)));
    }
    readonly property rect windowRect: Qt.rect(surfaceX - horizontalMargin,
        popupTop - topMargin, surfaceWidth + 2 * horizontalMargin,
        surfaceHeight + topMargin + bottomMargin)
}

import QtQuick
import "../core"

// Shadow использует фактическую surface Dock и не дублирует её анимацию.
PanelShadowWindow {
    id: shadowWindow

    required property var modelData
    required property var sourcePanel
    targetScreen: modelData
    shadowSource: shadowSurface
    shadowNamespace: "aerix:dock-shadow"
    shadowVisible: sourceVisible
    shadowOpacity: sourceSurface?.opacity ?? 0

    readonly property Rectangle sourceSurface: sourcePanel?.dockSurface ?? null
    readonly property bool sourceVisible: sourceSurface !== null
        && sourceSurface.y < sourcePanel.height

    anchors.bottom: true
    // Размер layer-window остаётся равен Dock во всех кадрах y-анимации.
    // Это исключает отдельный resize Wayland surface при выезде.
    implicitWidth: Math.ceil(sourcePanel?.width ?? 0)
    implicitHeight: Math.ceil(sourcePanel?.height ?? 0)

    Rectangle {
        id: shadowSurface
        x: shadowWindow.sourceSurface?.x ?? 0
        y: shadowWindow.sourceSurface?.y ?? shadowWindow.height
        width: shadowWindow.sourceSurface?.width ?? 0
        height: shadowWindow.sourceSurface?.height ?? 0
        radius: Metrics.panelRadius
        // Тень повторяет тот же scale и origin, что и фактическая Dock surface.
        scale: shadowWindow.sourceSurface?.scale ?? 1
        transformOrigin: shadowWindow.sourceSurface?.transformOrigin ?? Item.Bottom
        color: "transparent"
        antialiasing: true
    }
}

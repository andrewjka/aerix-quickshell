import QtQuick
import "../core"

// Геометрия Bar задаётся здесь, а общая layer-surface — в PanelShadowWindow.
PanelShadowWindow {
    id: shadowWindow

    required property var modelData
    targetScreen: modelData
    shadowSource: shadowSurface
    shadowNamespace: "aerix:status-bar-shadow"

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Metrics.statusBarHeight + Math.ceil(Metrics.panelShadowRadius) + 1

    Rectangle {
        id: shadowSurface
        x: Metrics.statusBarHorizontalMargin
        width: shadowWindow.width - 2 * Metrics.statusBarHorizontalMargin
        height: Metrics.statusBarHeight
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Metrics.panelRadius
        bottomRightRadius: Metrics.panelRadius
        color: "transparent"
        antialiasing: true
    }
}

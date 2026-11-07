import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Тень вынесена в отдельный layer-surface, исключённый из HyprGlass.
PanelWindow {
    required property var modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Metrics.statusBarHeight + Math.ceil(Metrics.panelShadowRadius) + 1
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aerix:status-bar-shadow"

    mask: Region {
        width: 0
        height: 0
    }

    PanelShadow {
        sourceItem: shadowSurface
    }

    Rectangle {
        id: shadowSurface
        x: Metrics.statusBarHorizontalMargin
        width: parent.width - 2 * Metrics.statusBarHorizontalMargin
        height: Metrics.statusBarHeight
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Metrics.panelRadius
        bottomRightRadius: Metrics.panelRadius
        color: "transparent"
        antialiasing: true
    }
}

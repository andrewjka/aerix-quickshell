import QtQuick
import "../core"
import "../services"

// У Dock своя анимация и ширина, общая layer-surface живёт в PanelShadowWindow.
PanelShadowWindow {
    id: shadowWindow

    required property var modelData
    targetScreen: modelData
    shadowSource: shadowSurface
    shadowNamespace: "aerix:dock-shadow"
    shadowVisible: shadowSurface.y < shadowWindow.height

    readonly property bool isOpen: DockPresentation.isOpen(modelData.name)
    readonly property int renderMargin: Math.max(Metrics.panelHorizontalMargin,
        Math.ceil(Metrics.panelShadowRadius) + 1)
    readonly property real openY: height - Metrics.panelHeight - Metrics.bottomMargin
    readonly property real panelWidth: DockPresentation.widthFor(modelData.name,
        layout.panelWidth)

    DockLayout {
        id: layout
        targetScreen: shadowWindow.modelData
    }

    anchors.bottom: true
    implicitWidth: Math.ceil(panelWidth) + 2 * renderMargin
    implicitHeight: Math.max(92, Metrics.panelHeight + Metrics.bottomMargin
        + Math.ceil(Metrics.panelShadowRadius) + 1)

    Rectangle {
        id: shadowSurface
        x: shadowWindow.renderMargin
        y: shadowWindow.isOpen ? shadowWindow.openY : shadowWindow.height
        width: shadowWindow.panelWidth
        height: Metrics.panelHeight
        radius: Metrics.panelRadius
        color: "transparent"
        antialiasing: true

        Behavior on y {
            StandardAnimation {}
        }
        Behavior on width {
            StandardAnimation {}
        }
    }
}

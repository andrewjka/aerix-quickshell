import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../services"

// Отдельный input-прозрачный layer-surface: HyprGlass его не обрабатывает.
PanelWindow {
    id: shadowWindow

    required property var modelData

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

    screen: modelData
    anchors.bottom: true
    implicitWidth: Math.ceil(panelWidth) + 2 * renderMargin
    implicitHeight: Math.max(92, Metrics.panelHeight + Metrics.bottomMargin
        + Math.ceil(Metrics.panelShadowRadius) + 1)
    color: "transparent"
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aerix:dock-shadow"

    // Тень не участвует в hit testing: события получает только DockPanel.
    mask: Region {
        width: 0
        height: 0
    }

    PanelShadow {
        sourceItem: shadowSurface
        visible: shadowSurface.y < shadowWindow.height
    }

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

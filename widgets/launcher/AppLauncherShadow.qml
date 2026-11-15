import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

// Одна input-прозрачная surface содержит тени обеих панелей launcher.
// Её namespace можно исключить из HyprGlass, не отключая стекло у виджетов.
PanelWindow {
    id: shadowWindow

    required property var targetScreen
    required property Item layoutItem
    required property var sourcePanels

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparentColor
    focusable: false
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aerix:app-launcher-shadow"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { width: 0; height: 0 }

    Repeater {
        model: shadowWindow.sourcePanels

        delegate: Item {
            id: shadowPanel

            required property var modelData
            readonly property Item sourcePanel: modelData ?? null
            readonly property real layoutScale: shadowWindow.layoutItem?.scale ?? 1
            visible: sourcePanel !== null && sourcePanel.visible
            x: (shadowWindow.layoutItem?.x ?? 0)
                + ((shadowWindow.layoutItem?.width ?? 0)
                    * (1 - layoutScale) / 2)
                + (sourcePanel?.x ?? 0) * layoutScale
            y: (shadowWindow.layoutItem?.y ?? 0)
                + ((shadowWindow.layoutItem?.height ?? 0)
                    * (1 - layoutScale) / 2)
                + (sourcePanel?.y ?? 0) * layoutScale
            width: sourcePanel?.width ?? 0
            height: sourcePanel?.height ?? 0
            scale: layoutScale
            transformOrigin: Item.TopLeft
            opacity: (shadowWindow.layoutItem?.opacity ?? 0)
                * (sourcePanel?.opacity ?? 0)

            Rectangle {
                id: shadowSource
                anchors.fill: parent
                radius: Metrics.panelRadius
                color: Theme.transparentColor
                antialiasing: true
            }

            PanelShadow {
                sourceItem: shadowSource
            }
        }
    }
}

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

// Отдельная surface хранит только тени карточек. Её namespace можно исключить
// из HyprGlass, не отключая стекло у самих карточек overview.
PanelWindow {
    id: shadowWindow

    required property var targetScreen
    required property var cardItems
    required property Item gridArea

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparentColor
    focusable: false
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aerix:workspace-overview-shadow"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { width: 0; height: 0 }

    Repeater {
        model: shadowWindow.cardItems

        delegate: Item {
            id: shadowCard

            required property var modelData
            readonly property bool hasCard: modelData !== null
                visible: hasCard
                x: shadowWindow.gridArea.x
                    + (modelData?.x ?? 0) * shadowWindow.gridArea.scale
                y: shadowWindow.gridArea.y
                    + (modelData?.y ?? 0) * shadowWindow.gridArea.scale
                width: modelData?.width ?? 0
                height: modelData?.height ?? 0
                scale: shadowWindow.gridArea.scale
                transformOrigin: Item.TopLeft
                opacity: modelData?.opacity ?? 0

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

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

// Отдельная surface гарантирует, что preview drag остаётся выше стеклянных
// surfaces папок, не отключая их blur на время переноса.
PanelWindow {
    id: window

    required property var targetScreen
    required property point position
    property string iconSource: ""
    property var entries: []
    property bool folderPreview: false
    property bool active: false
    property real contentOpacity: 1

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparentColor
    visible: active
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aerix:app-launcher-drag-preview"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { width: 0; height: 0 }
    BackgroundEffect.blurRegion: Region {
        item: window.folderPreview ? preview : null
        radius: Metrics.panelRadius
    }

    Item {
        id: preview
        x: window.position.x - width / 2
        y: window.position.y - height / 2
        width: Metrics.appLauncherIconSize
        height: width
        opacity: window.contentOpacity

        Image {
            anchors.fill: parent
            visible: !window.folderPreview
            source: window.iconSource
            sourceSize: Qt.size(Math.ceil(width * window.devicePixelRatio),
                Math.ceil(height * window.devicePixelRatio))
            fillMode: Image.PreserveAspectFit
            smooth: true
        }

        Rectangle {
            anchors.fill: parent
            visible: window.folderPreview
            radius: Metrics.panelRadius
            color: Theme.backgroundColor
            border.width: 1
            border.color: Theme.borderColor

            Grid {
                anchors.fill: parent
                anchors.margins: Metrics.spacing / 2
                columns: 2
                spacing: Metrics.spacing / 2

                Repeater {
                    model: window.entries.slice(0, 4)

                    delegate: Image {
                        required property var modelData
                        width: (parent.width - Metrics.spacing / 2) / 2
                        height: width
                        readonly property string iconName: String(modelData?.icon ?? "")
                        source: iconName.startsWith("/") ? "file://" + iconName
                            : iconName && Quickshell.hasThemeIcon(iconName)
                                ? Quickshell.iconPath(iconName) : ""
                        sourceSize: Qt.size(Math.ceil(width * window.devicePixelRatio),
                            Math.ceil(height * window.devicePixelRatio))
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                }
            }
        }
    }
}

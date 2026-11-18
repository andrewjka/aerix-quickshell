pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../shared" as Shared

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

        Shared.IconWidget {
            anchors.centerIn: parent
            height: parent.height
            visible: !window.folderPreview
            iconSource: window.iconSource
            tinted: false
            devicePixelRatio: window.devicePixelRatio
        }

        Rectangle {
            anchors.fill: parent
            visible: window.folderPreview
            radius: Metrics.panelRadius
            color: Theme.backgroundColor
            border.width: 1
            border.color: Theme.borderColor

            Shared.FolderPreview {
                anchors.fill: parent
                anchors.margins: Metrics.spacing / 2
                entries: window.entries
                devicePixelRatio: window.devicePixelRatio
            }
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

// Отдельный буфер значка даёт compositor-у фон панели под ним для blur.
// Ввод остаётся у делегата сетки, включая mouse grab во время drag.
PanelWindow {
    id: window
    required property var targetScreen
    required property Item sourceItem
    required property Item referenceItem
    required property Item viewport
    required property var geometryRevision
    required property var entries
    property bool active: true
    property real contentOpacity: 1

    readonly property rect iconRect: {
        const revision = geometryRevision;
        return sourceItem.mapToItem(referenceItem, 0, 0,
            sourceItem.width, sourceItem.height);
    }
    readonly property rect viewportRect: {
        const revision = geometryRevision;
        return viewport.mapToItem(referenceItem, 0, 0,
            viewport.width, viewport.height);
    }
    readonly property real clipTop: Math.max(iconRect.y, viewportRect.y)
    readonly property real clipLeft: Math.max(iconRect.x, viewportRect.x)
    readonly property real clipWidth: Math.max(0,
        Math.min(iconRect.x + iconRect.width, viewportRect.x + viewportRect.width) - clipLeft)
    readonly property real clipHeight: Math.max(0,
        Math.min(iconRect.y + iconRect.height, viewportRect.y + viewportRect.height) - clipTop)

    screen: targetScreen
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.transparentColor
    visible: active && clipWidth > 0 && clipHeight > 0
    focusable: false
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "aerix:app-launcher-folder-icon"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { width: 0; height: 0 }
    BackgroundEffect.blurRegion: Region {
        item: clippedIcon
        radius: Math.min(Metrics.panelRadius, window.clipHeight / 2)
    }

    Item {
        id: clippedIcon
        x: window.clipLeft
        y: window.clipTop
        width: window.clipWidth
        height: window.clipHeight
        clip: true
        opacity: window.contentOpacity

        Rectangle {
            x: window.iconRect.x - window.clipLeft
            y: window.iconRect.y - window.clipTop
            width: window.iconRect.width
            height: window.iconRect.height
            radius: Metrics.panelRadius
            color: Theme.backgroundColor
            border.width: 1
            border.color: Theme.borderColor
            Grid {
                anchors.fill: parent
                anchors.margins: Math.max(2, Metrics.spacing / 2)
                columns: 2
                spacing: Metrics.spacing / 2
                Repeater {
                    model: window.entries.slice(0, 4)
                    Image {
                        required property var modelData
                        width: (parent.width - Metrics.spacing / 2) / 2
                        height: width
                        readonly property string iconName: String(modelData?.icon ?? "")
                        source: iconName.startsWith("/") ? "file://" + iconName
                            : iconName && Quickshell.hasThemeIcon(iconName)
                                ? Quickshell.iconPath(iconName) : ""
                        // Геометрия surface масштабируется при открытии, но
                        // декодировать миниатюру заново на каждом кадре не нужно.
                        readonly property int rasterSize: Math.ceil(
                            (Metrics.appLauncherIconSize - 1.5 * Metrics.spacing)
                                / 2 * window.devicePixelRatio)
                        asynchronous: true
                        sourceSize: Qt.size(rasterSize, rasterSize)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                    }
                }
            }
        }
    }
}

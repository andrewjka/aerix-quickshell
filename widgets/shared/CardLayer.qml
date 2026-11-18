pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"

// Карточка и её тень в отдельных Wayland-окнах: compositor размывает фон
// каждой карточки. Viewport повторяется в обоих окнах, включая область blur.
Scope {
    id: cardLayer
    required property var targetScreen
    required property string layerNamespace
    required property string shadowNamespace
    required property rect windowRect
    required property rect cardRect
    required property Component content
    property rect viewport: Qt.rect(0, 0, windowRect.width, windowRect.height)
    property real cardScale: 1
    property real cardOpacity: 1
    property bool shown: true
    property bool interactive: true
    readonly property rect clippedRect: {
        const left = Math.max(viewport.x, cardRect.x);
        const top = Math.max(viewport.y, cardRect.y);
        return Qt.rect(left, top,
            Math.max(0, Math.min(viewport.x + viewport.width,
                cardRect.x + cardRect.width * cardScale) - left),
            Math.max(0, Math.min(viewport.y + viewport.height,
                cardRect.y + cardRect.height * cardScale) - top));
    }

    PanelWindow {
        screen: cardLayer.targetScreen
        anchors { top: true; left: true }
        margins.left: cardLayer.windowRect.x
        margins.top: cardLayer.windowRect.y
        implicitWidth: cardLayer.windowRect.width
        implicitHeight: cardLayer.windowRect.height
        visible: cardLayer.shown
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparentColor
        focusable: false
        WlrLayershell.namespace: cardLayer.layerNamespace
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region {
            x: cardLayer.clippedRect.x
            y: cardLayer.clippedRect.y
            width: cardLayer.interactive ? cardLayer.clippedRect.width : 0
            height: cardLayer.interactive ? cardLayer.clippedRect.height : 0
            radius: Metrics.panelRadius
        }
        BackgroundEffect.blurRegion: Region {
            x: cardLayer.clippedRect.x
            y: cardLayer.clippedRect.y
            width: cardLayer.clippedRect.width
            height: cardLayer.clippedRect.height
            radius: Metrics.panelRadius
        }

        Item {
            x: cardLayer.viewport.x
            y: cardLayer.viewport.y
            width: cardLayer.viewport.width
            height: cardLayer.viewport.height
            clip: true
            Loader {
                x: cardLayer.cardRect.x - cardLayer.viewport.x
                y: cardLayer.cardRect.y - cardLayer.viewport.y
                width: cardLayer.cardRect.width
                height: cardLayer.cardRect.height
                scale: cardLayer.cardScale
                opacity: cardLayer.cardOpacity
                transformOrigin: Item.TopLeft
                sourceComponent: cardLayer.content
            }
        }
    }

    PanelWindow {
        screen: cardLayer.targetScreen
        anchors { top: true; left: true }
        margins.left: cardLayer.windowRect.x
        margins.top: cardLayer.windowRect.y
        implicitWidth: cardLayer.windowRect.width
        implicitHeight: cardLayer.windowRect.height
        visible: cardLayer.shown
        exclusionMode: ExclusionMode.Ignore
        color: Theme.transparentColor
        focusable: false
        WlrLayershell.namespace: cardLayer.shadowNamespace
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        mask: Region { width: 0; height: 0 }

        Item {
            x: cardLayer.viewport.x
            y: cardLayer.viewport.y
            width: cardLayer.viewport.width
            height: cardLayer.viewport.height
            clip: true
            opacity: cardLayer.cardOpacity
            PanelShadow { sourceItem: shadowShape }
            Rectangle {
                id: shadowShape
                x: cardLayer.cardRect.x - cardLayer.viewport.x
                y: cardLayer.cardRect.y - cardLayer.viewport.y
                width: cardLayer.cardRect.width
                height: cardLayer.cardRect.height
                radius: Metrics.panelRadius
                scale: cardLayer.cardScale
                transformOrigin: Item.TopLeft
                color: Theme.transparentColor
            }
        }
    }
}

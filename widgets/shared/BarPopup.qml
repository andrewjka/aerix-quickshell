pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../core"

// Общий lifecycle popup: spring, focus grab и отдельная тень.
// Содержимое и высоту задаёт виджет; Loader владельца выгружает окно по dismissed.
PanelWindow {
    id: popup
    required property var barWindow
    required property Item anchorItem
    required property string layerNamespace
    required property real surfaceHeight
    property real preferredWidth: 280
    property bool expanded: false
    property real reveal: expanded ? 1 : 0
    property bool deferredFocus: false
    property bool restartOnReopen: false
    // У истории заливка и тень нужны только заголовку, список рисуется отдельно.
    property real panelHeight: surfaceHeight
    readonly property alias frame: popupFrame
    readonly property alias layout: geometry
    readonly property real surfaceWidth: geometry.surfaceWidth
    default property alias contentData: popupFrame.data

    signal dismissed()
    signal restartRequested()

    function dismiss() {
        expanded = false;
        // Focus grab может закрыть окно ещё до первого кадра. Тогда анимация
        // не стартует и onRunningChanged не придёт, но Loader всё равно нужен reset.
        if (reveal === 0)
            Qt.callLater(finishDismissal);
    }
    function finishDismissal() {
        if (!expanded && reveal === 0) dismissed();
    }
    function toggle() {
        if (!expanded && restartOnReopen)
            restartRequested();
        else
            expanded = !expanded;
    }
    function syncFocusGrab() { focusGrab.active = expanded; }

    Component.onCompleted: expanded = true
    onExpandedChanged: {
        if (deferredFocus)
            Qt.callLater(syncFocusGrab);
        else
            syncFocusGrab();
    }

    screen: barWindow.screen
    anchors { top: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    color: Theme.transparentColor
    margins.left: geometry.windowRect.x
    margins.top: geometry.windowRect.y
    implicitWidth: geometry.windowRect.width
    implicitHeight: geometry.windowRect.height
    WlrLayershell.namespace: layerNamespace
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: popupFrame }

    Behavior on reveal {
        SpringAnimation {
            onRunningChanged: {
                if (!running) popup.finishDismissal();
            }
        }
    }

    // Явный data оставляет служебные объекты вне пользовательского contentData.
    data: [
        PopupLayout {
            id: geometry
            barWindow: popup.barWindow
            anchorItem: popup.anchorItem
            preferredWidth: popup.preferredWidth
            surfaceHeight: popup.surfaceHeight
        },
        HyprlandFocusGrab {
            id: focusGrab
            // Bar остаётся в whitelist для повторного клика по кнопке.
            windows: [popup, popup.barWindow]
            onCleared: popup.dismiss()
        },
        PanelShadowWindow {
            targetScreen: popup.screen
            shadowSource: shadowSurface
            shadowNamespace: popup.layerNamespace + "-shadow"
            shadowOpacity: popupFrame.opacity
            WlrLayershell.layer: WlrLayer.Overlay
            anchors { top: true; left: true }
            margins.left: geometry.windowRect.x
            margins.top: geometry.windowRect.y
            implicitWidth: popup.width
            implicitHeight: popup.height

            Rectangle {
                id: shadowSurface
                x: popupFrame.x
                y: popupFrame.y
                width: popupFrame.width
                height: popup.panelHeight
                radius: Metrics.panelRadius
                scale: popupFrame.scale
                transformOrigin: Item.Top
                color: Theme.transparentColor
                antialiasing: true
            }
        },
        Item {
            id: popupFrame
            x: geometry.horizontalMargin
            y: geometry.topMargin - geometry.revealTravel * (1 - popup.reveal)
            width: popup.surfaceWidth
            height: popup.surfaceHeight
            scale: Metrics.spring.startScale + (1 - Metrics.spring.startScale) * popup.reveal
            transformOrigin: Item.Top
            opacity: Math.max(0, Math.min(1, popup.reveal))

            Rectangle {
                width: parent.width
                height: popup.panelHeight
                radius: Metrics.panelRadius
                color: Theme.backgroundColor
                border.width: 1
                border.color: Theme.borderColor
                antialiasing: true
            }
        }
    ]
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import "../../core"

// Общий lifecycle popup: spring, геометрия и отдельная тень.
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
        // При закрытии до первого кадра анимация не стартует. Loader всё равно
        // должен получить финальный callback, иначе popup останется в памяти.
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

    Component.onCompleted: expanded = true

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
        NumberAnimation {
            duration: Metrics.spring.durationMs
            easing.type: Metrics.spring.easingType
            easing.bezierCurve: Metrics.spring.bezierCurve
            onRunningChanged: {
                if (!running) popup.finishDismissal();
            }
        }
    }

    // Захват ввода остаётся только у самого popup. Клик вне его границ
    // очищает grab в Hyprland и запускает обычное обратное закрытие.
    HyprlandFocusGrab {
        id: outsideClickGrab
        active: popup.expanded
        windows: [popup]
        onCleared: popup.dismiss()
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

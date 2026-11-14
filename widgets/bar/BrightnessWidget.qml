pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "shared" as Shared
import "../../core"
import "../../services"

// Компактный trigger яркости. Popup создаётся только после первого клика.
Item {
    id: widget

    required property var barWindow
    property bool popupOpen: false
    readonly property bool canInteract: BrightnessService.available
    implicitWidth: Math.ceil(brightnessIcon.width)
    implicitHeight: Math.ceil(brightnessIcon.height)
    width: implicitWidth
    height: implicitHeight

    signal popupOpened()

    function closePopup() {
        popupOpen = false;
    }

    function dismissPopup() {
        if (popupLoader.item)
            (popupLoader.item as BrightnessPopup).dismiss();
        else
            closePopup();
    }

    function openPopup() {
        if (!canInteract)
            return;
        BrightnessService.refreshMonitors();
        BrightnessService.refresh();
        popupOpened();
        popupOpen = true;
    }

    Shared.StatusBarIcon {
        id: brightnessIcon
        anchors.centerIn: parent
        width: Metrics.statusBarWidgetIconSize
        height: Metrics.statusBarWidgetIconSize
        iconSource: Qt.resolvedUrl("../../assets/icons/brightness.svg")
        tintColor: widget.canInteract ? Theme.foregroundColor
                                      : Theme.disabledForegroundColor
        devicePixelRatio: widget.barWindow?.devicePixelRatio ?? 1
    }

    MouseArea {
        anchors.fill: parent
        enabled: widget.canInteract
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (widget.popupOpen)
                (popupLoader.item as BrightnessPopup)?.toggle();
            else
                widget.openPopup();
        }
        onWheel: wheel => {
            const direction = Math.sign(wheel.angleDelta.y);
            if (direction !== 0)
                BrightnessService.adjustBrightness(direction);
            wheel.accepted = true;
        }
    }

    LazyLoader {
        id: popupLoader
        active: widget.popupOpen

        component: BrightnessPopup {
            barWindow: widget.barWindow
            anchorItem: widget
            onDismissed: widget.closePopup()
        }
    }
}

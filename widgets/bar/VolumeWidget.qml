pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "shared" as Shared
import "../../core"
import "../../services"

// Компактный trigger громкости. Popup создаётся только после первого клика.
Item {
    id: widget

    required property var barWindow
    property bool popupOpen: false
    readonly property bool canInteract: AudioService.available
    implicitWidth: Math.ceil(volumeIcon.width)
    implicitHeight: Math.ceil(volumeIcon.height)
    width: implicitWidth
    height: implicitHeight

    signal popupOpened()

    function closePopup() {
        popupOpen = false;
    }

    function dismissPopup() {
        if (popupLoader.item)
            (popupLoader.item as VolumePopup).dismiss();
        else
            closePopup();
    }

    function openPopup() {
        if (!canInteract)
            return;
        popupOpened();
        popupOpen = true;
    }

    Shared.StatusBarIcon {
        id: volumeIcon
        anchors.centerIn: parent
        width: Metrics.statusBarWidgetIconSize
        height: Metrics.statusBarWidgetIconSize
        iconSource: Qt.resolvedUrl("../../assets/icons/" + AudioService.iconName)
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
                (popupLoader.item as VolumePopup)?.toggle();
            else
                widget.openPopup();
        }
        onWheel: wheel => {
            const direction = Math.sign(wheel.angleDelta.y);
            if (direction !== 0)
                AudioService.adjustVolume(direction);
            wheel.accepted = true;
        }
    }

    LazyLoader {
        id: popupLoader
        active: widget.popupOpen

        component: VolumePopup {
            barWindow: widget.barWindow
            anchorItem: widget
            onDismissed: widget.closePopup()
        }
    }
}

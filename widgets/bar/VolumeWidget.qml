pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../../core"
import "../../services"

// Компактный trigger громкости. Popup создаётся только после первого клика.
Item {
    id: widget

    required property var barWindow
    property bool popupOpen: false
    readonly property bool canInteract: AudioService.available
    implicitWidth: volumePercent.implicitWidth + 4 + volumeIcon.width
    implicitHeight: Math.max(volumePercent.implicitHeight, volumeIcon.height)
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

    Image {
        id: volumeIcon
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Metrics.statusBarFontSize + 2
        height: width
        source: Qt.resolvedUrl("../../assets/icons/" + AudioService.iconName)
        sourceSize.width: Math.ceil(width * widget.barWindow.devicePixelRatio)
        sourceSize.height: Math.ceil(height * widget.barWindow.devicePixelRatio)
        fillMode: Image.PreserveAspectFit
        smooth: true
        layer.enabled: true
        layer.effect: ColorOverlay {
            color: widget.canInteract ? Theme.foregroundColor
                                     : Theme.disabledForegroundColor
        }
    }

    Text {
        id: volumePercent
        anchors.left: parent.left
        anchors.right: volumeIcon.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: String(AudioService.volumePercent).padStart(2, "0")
        color: widget.canInteract ? Theme.foregroundColor
                                 : Theme.disabledForegroundColor
        font.pixelSize: Metrics.statusBarFontSize
        font.weight: Font.Medium
        horizontalAlignment: Text.AlignRight
        verticalAlignment: Text.AlignVCenter
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

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "shared" as Shared
import "../../core"
import "../../services"

// Trigger истории уведомлений и владелец toast-а на своём мониторе.
Item {
    id: widget

    required property var barWindow
    property bool popupOpen: false
    property bool toastOpen: false
    implicitWidth: Math.ceil(notificationIcon.width)
    implicitHeight: Math.ceil(notificationIcon.height)
    width: implicitWidth
    height: implicitHeight

    signal popupOpened()

    function closePopup() {
        reopenTimer.stop();
        popupOpen = false;
    }

    // При повторном клике во время закрытия сначала уничтожаем старый
    // popup вместе с загрузчиками и таймерами каскада, затем создаём новый.
    function restartPopup() {
        closePopup();
        reopenTimer.start();
    }

    Timer {
        id: reopenTimer
        interval: 0
        onTriggered: widget.openPopup()
    }

    function dismissPopup() {
        if (popupLoader.item)
            (popupLoader.item as NotificationPopup).dismiss();
        else
            closePopup();
    }

    function openPopup() {
        // История уже открыта, поэтому краткие карточки на этом же экране
        // больше не нужны. Сами уведомления остаются в списке.
        NotificationService.clearToastsForScreen(widget.barWindow.screen);
        popupOpened();
        popupOpen = true;
    }

    function closeToast() { toastOpen = false; }

    function dismissToast() {
        if (toastLoader.item)
            (toastLoader.item as NotificationToast).dismiss();
        else
            closeToast();
    }

    function updateToast() {
        if (NotificationService.toastsForScreen(widget.barWindow.screen).length > 0) {
            widget.toastOpen = true;
            (toastLoader.item as NotificationToast)?.show();
        } else {
            widget.dismissToast();
        }
    }

    Item {
        id: iconSurface
        anchors.centerIn: parent
        width: Metrics.statusBarWidgetIconSize
        height: Metrics.statusBarWidgetIconSize

        Shared.StatusBarIcon {
            id: notificationIcon
            anchors.fill: parent
            iconSource: Qt.resolvedUrl("../../assets/icons/notification.svg")
            tintColor: Theme.foregroundColor
            devicePixelRatio: widget.barWindow?.devicePixelRatio ?? 1
        }

        Rectangle {
            visible: NotificationService.notificationCount > 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -2
            anchors.topMargin: -2
            width: 7
            height: 7
            radius: width / 2
            color: "#E53935"
            border.width: 1
            border.color: Theme.backgroundColor
            antialiasing: true
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (widget.popupOpen)
                (popupLoader.item as NotificationPopup)?.toggle();
            else
                widget.openPopup();
        }
    }

    Connections {
        target: NotificationService

        function onToastEntriesChanged() {
            widget.updateToast();
        }
    }

    LazyLoader {
        id: popupLoader
        active: widget.popupOpen

        component: NotificationPopup {
            barWindow: widget.barWindow
            anchorItem: widget
            onDismissed: widget.closePopup()
            onRestartRequested: widget.restartPopup()
        }
    }

    LazyLoader {
        id: toastLoader
        active: widget.toastOpen

        component: NotificationToast {
            barWindow: widget.barWindow
            anchorItem: widget
            onDismissed: widget.closeToast()
        }
    }
}

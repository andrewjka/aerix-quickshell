pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../shared" as Shared
import "../../../services"

// Владелец истории и toast-колоды на одном экране. Оба освобождаются после закрытия.
Shared.BarWidget {
    id: widget
    property bool toastOpen: false
    readonly property var toastEntries: NotificationService.toastsForScreen(barWindow.screen)
    iconSource: Qt.resolvedUrl("../../../assets/icons/notification.svg")
    badgeVisible: NotificationService.notificationCount > 0
    onPopupOpening: NotificationService.clearToastsForScreen(barWindow.screen)

    // Содержимое toast синхронизируется внутри него. Здесь только его lifetime.
    onToastEntriesChanged: {
        if (toastEntries.length > 0) toastOpen = true;
    }
    Component.onCompleted: toastOpen = toastEntries.length > 0

    popupComponent: NotificationPopup {
        barWindow: widget.barWindow
        anchorItem: widget
        onDismissed: widget.closePopup()
        onRestartRequested: widget.restartPopup()
    }
    LazyLoader {
        active: widget.toastOpen
        component: NotificationToast {
            barWindow: widget.barWindow
            anchorItem: widget
            onDismissed: widget.toastOpen = false
        }
    }
}

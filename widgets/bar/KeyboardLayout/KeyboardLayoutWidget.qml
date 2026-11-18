pragma ComponentBehavior: Bound

import QtQuick
import "../../shared" as Shared
import "../../../services"

// Сервисные действия кнопки; отрисовка и lifecycle popup общие для всего bar.
Shared.BarWidget {
    id: widget
    canInteract: KeyboardService.available
    iconSource: Qt.resolvedUrl("../../../assets/icons/language.svg")
    label: KeyboardService.activeLabel
    onPopupOpening: KeyboardService.refresh()

    popupComponent: KeyboardLayoutPopup {
        barWindow: widget.barWindow
        anchorItem: widget
        onDismissed: widget.closePopup()
    }
}

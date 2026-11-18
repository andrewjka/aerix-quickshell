pragma ComponentBehavior: Bound

import QtQuick
import "../../shared" as Shared
import "../../../services"

// Сервисные действия кнопки; отрисовка и lifecycle popup общие для всего bar.
Shared.BarWidget {
    id: widget
    canInteract: BrightnessService.available
    iconSource: Qt.resolvedUrl("../../../assets/icons/brightness.svg")
    onPopupOpenChanged: OsdService.brightnessPopupOpen = popupOpen
    onWheelStep: direction => BrightnessService.adjustBrightness(direction)
    onPopupOpening: {
        OsdService.brightnessPopupOpen = true;
        BrightnessService.refreshMonitors();
        BrightnessService.refresh();
    }

    popupComponent: BrightnessPopup {
        barWindow: widget.barWindow
        anchorItem: widget
        onDismissed: widget.closePopup()
    }
}

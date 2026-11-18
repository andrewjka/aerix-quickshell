pragma ComponentBehavior: Bound

import QtQuick
import "../../shared" as Shared
import "../../../services"

// Сервисные действия кнопки; отрисовка и lifecycle popup общие для всего bar.
Shared.BarWidget {
    id: widget
    canInteract: AudioService.available
    iconSource: Qt.resolvedUrl("../../../assets/icons/" + AudioService.iconName)
    onPopupOpenChanged: OsdService.volumePopupOpen = popupOpen
    onWheelStep: direction => AudioService.adjustVolume(direction)

    popupComponent: VolumePopup {
        barWindow: widget.barWindow
        anchorItem: widget
        onDismissed: widget.closePopup()
    }
}

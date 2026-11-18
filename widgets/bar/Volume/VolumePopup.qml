pragma ComponentBehavior: Bound

import QtQuick
import "../../shared" as Shared
import "../../../core"
import "../../../services"

// Настройки вывода звука; геометрией, фокусом и тенью владеет BarPopup.
Shared.BarPopup {
    id: popup
    layerNamespace: "aerix:volume"
    deferredFocus: true
    readonly property int mixerHeight: 42
    readonly property int rowHeight: 32
    readonly property int visibleRows: Math.min(5, Math.max(1, AudioService.outputDevices.length))
    readonly property int listHeight: visibleRows * rowHeight
        + Math.max(0, visibleRows - 1) * Metrics.popupRowSpacing + 2
    surfaceHeight: 4 * Metrics.spacing + mixerHeight + 1 + 16 + 4 + listHeight

    Shared.ValueSlider {
        id: mixer
        x: Metrics.spacing
        y: Metrics.spacing
        width: parent.width - 2 * Metrics.spacing
        height: popup.mixerHeight
        iconSource: Qt.resolvedUrl("../../../assets/icons/" + AudioService.iconName)
        devicePixelRatio: popup.devicePixelRatio
        text: String(AudioService.volumePercent).padStart(2, "0")
        value: AudioService.volumePercent
        interactive: AudioService.available
        iconInteractive: AudioService.available
        onIconClicked: AudioService.setMuted(!AudioService.muted)
        onValueEdited: value => AudioService.setVolumePercent(value)
    }
    Rectangle {
        x: Metrics.spacing
        y: mixer.y + mixer.height + Metrics.spacing
        width: parent.width - 2 * Metrics.spacing
        height: 1
        color: Theme.borderColor
    }
    Text {
        id: outputLabel
        x: Metrics.spacing
        y: mixer.y + mixer.height + 2 * Metrics.spacing + 1
        width: parent.width - 2 * Metrics.spacing
        height: 16
        text: I18n.tr("audio.devices")
        color: Theme.foregroundColor
        font.pixelSize: 12
        font.weight: Font.Medium
        verticalAlignment: Text.AlignVCenter
    }
    Shared.SelectionList {
        id: deviceList
        x: Metrics.spacing
        y: outputLabel.y + outputLabel.height + 4
        width: parent.width - 2 * Metrics.spacing
        height: popup.listHeight
        rowHeight: popup.rowHeight
        model: AudioService.outputDevices
        visible: count > 0
        labelFor: entry => AudioService.deviceLabel(entry)
        selectedFor: entry => AudioService.isSelectedDevice(entry)
        onChosen: entry => {
            if (AudioService.selectDevice(entry)) popup.dismiss();
        }
    }
    Text {
        anchors.fill: deviceList
        visible: !deviceList.visible
        text: I18n.tr("audio.noDevices")
        color: Theme.disabledForegroundColor
        font.pixelSize: Metrics.statusBarFontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}

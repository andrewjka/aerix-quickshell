pragma ComponentBehavior: Bound

import QtQuick
import "../../shared" as Shared
import "../../../core"
import "../../../services"

// Две шкалы одного экрана: яркость и цветовая температура; ниже выбор монитора.
Shared.BarPopup {
    id: popup
    layerNamespace: "aerix:brightness"
    readonly property int mixerHeight: 42
    readonly property int rowHeight: 32
    readonly property int visibleRows: Math.min(5, Math.max(1, BrightnessService.monitors.length))
    readonly property int listHeight: visibleRows * rowHeight
        + Math.max(0, visibleRows - 1) * Metrics.popupRowSpacing + 2
    surfaceHeight: 5 * Metrics.spacing + 2 * mixerHeight + 1 + 16 + 4 + listHeight

    Shared.ValueSlider {
        id: brightness
        x: Metrics.spacing
        y: Metrics.spacing
        width: parent.width - 2 * Metrics.spacing
        height: popup.mixerHeight
        iconSource: Qt.resolvedUrl("../../../assets/icons/brightness.svg")
        iconColor: "white"
        devicePixelRatio: popup.devicePixelRatio
        text: String(BrightnessService.brightnessPercent).padStart(2, "0")
        value: BrightnessService.brightnessPercent
        interactive: BrightnessService.available
        onValueEdited: value => BrightnessService.setBrightnessPercent(value)
    }
    Shared.ValueSlider {
        id: temperature
        x: Metrics.spacing
        y: brightness.y + brightness.height + Metrics.spacing
        width: parent.width - 2 * Metrics.spacing
        height: popup.mixerHeight
        iconSource: {
            const progress = (value - from) / (to - from);
            const level = progress < 0.25 ? "min" : progress < 0.5 ? "quarter"
                : progress < 0.75 ? "half" : "high";
            return Qt.resolvedUrl("../../../assets/icons/temperature-" + level + ".svg");
        }
        devicePixelRatio: popup.devicePixelRatio
        text: String(BrightnessService.temperatureKelvin) + "K"
        value: BrightnessService.temperatureKelvin
        from: BrightnessService.minimumTemperature
        to: BrightnessService.maximumTemperature
        stepSize: 0
        onValueEdited: value => BrightnessService.setTemperatureKelvin(value)
    }
    Rectangle {
        x: Metrics.spacing
        y: temperature.y + temperature.height + Metrics.spacing
        width: parent.width - 2 * Metrics.spacing
        height: 1
        color: Theme.borderColor
    }
    Text {
        id: monitorsLabel
        x: Metrics.spacing
        y: temperature.y + temperature.height + 2 * Metrics.spacing + 1
        width: parent.width - 2 * Metrics.spacing
        height: 16
        text: I18n.tr("brightness.monitors")
        color: Theme.foregroundColor
        font.pixelSize: 12
        font.weight: Font.Medium
        verticalAlignment: Text.AlignVCenter
    }
    Shared.SelectionList {
        x: Metrics.spacing
        y: monitorsLabel.y + monitorsLabel.height + 4
        width: parent.width - 2 * Metrics.spacing
        height: popup.listHeight
        rowHeight: popup.rowHeight
        model: BrightnessService.monitors
        selectedFor: entry => BrightnessService.isSelectedMonitor(entry)
        onChosen: entry => {
            if (BrightnessService.selectMonitor(entry)) popup.dismiss();
        }
    }
}

import QtQuick
import "../core"
import "../services"

// Виджет только отображает время: источник и частота обновления общие.
Text {
    text: ClockService.timeText
    color: Theme.foregroundColor
    font.pixelSize: Metrics.statusBarFontSize
    font.weight: Font.Medium
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}

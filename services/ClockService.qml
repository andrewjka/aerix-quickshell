pragma Singleton

import QtQml
import Quickshell

// Один источник местного времени для всех мониторов и будущих виджетов.
// SystemClock сам синхронизирует обновления с границей минуты.
SystemClock {
    enabled: Quickshell.screens.length > 0
    precision: SystemClock.Minutes

    readonly property var displayLocale: Qt.locale("en_US")
    readonly property string timeText: date.toLocaleTimeString(displayLocale, "HH:mm")
    readonly property string dateText: date.toLocaleDateString(displayLocale, "MMM d, yyyy")
    readonly property string displayText: timeText + " | " + dateText
}

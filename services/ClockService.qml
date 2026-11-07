pragma Singleton

import QtQml
import Quickshell

// Один источник местного времени для всех мониторов и будущих виджетов.
// SystemClock сам синхронизирует обновления с границей минуты.
SystemClock {
    enabled: Quickshell.screens.length > 0
    precision: SystemClock.Minutes

    readonly property string timeText: Qt.formatTime(date, "HH:mm")
}

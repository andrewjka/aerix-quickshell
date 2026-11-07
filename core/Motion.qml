pragma Singleton

import QtQml

QtObject {
    // Все компоненты используют эти значения, чтобы движения Aeris ощущались
    // одинаково и не плодили локальные bezier-массивы.
    // Базовый переход используется для локальных реакций и появления превью.
    readonly property int defaultDuration: 512
    // Длинный переход оставляет больше времени крупным движениям интерфейса.
    readonly property int longDuration: 768
    // Пауза перед закрытием панели после клика по другому рабочему пространству.
    readonly property int panelCloseDelay: 1128
    readonly property var standardCurve: [0.05, 0.9, 0.1, 1.05, 1, 1]
}

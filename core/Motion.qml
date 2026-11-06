pragma Singleton

import QtQml

QtObject {
    // Все компоненты используют эти значения, чтобы движения Aeris ощущались
    // одинаково и не плодили локальные bezier-массивы.
    // Короткая тактильная реакция: нажатие и один шаг отталкивания капсулы.
    readonly property int pressDuration: 256
    // Основной переход: смена рабочего пространства и появление превью.
    readonly property int transitionDuration: 512
    // Полное устоявшееся движение: 512 + 256 = 768 мс.
    readonly property int settleDuration: transitionDuration + pressDuration
    // Пауза перед закрытием панели после клика по другому рабочему пространству.
    readonly property int panelCloseDelay: 1128
    readonly property var standardCurve: [0.05, 0.9, 0.1, 1.05, 1, 1]
}

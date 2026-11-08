pragma Singleton

import QtQml
import QtQuick

QtObject {
    id: motion

    // Все компоненты используют эти значения, чтобы движения Aeris ощущались
    // одинаково и не плодили локальные bezier-массивы.
    // Базовый переход используется для локальных реакций и появления превью.
    readonly property int defaultDuration: 512
    // Длинный переход оставляет больше времени крупным движениям интерфейса.
    readonly property int longDuration: 768
    // === Редактируемые параметры общей пружины ===
    // Начальный масштаб в первом кадре.
    readonly property real panelSpringInitialScale: 0.16
    // Дополнительный пролёт за конечную точку базовой Bezier-кривой.
    // 0 отключает добавочную пружину, 0.16 соответствует текущему профилю.
    readonly property real panelSpringOvershoot: 0.16

    // Компоненты получают готовый профиль через Motion.panelSpring. Здесь
    // остаётся вся техническая сборка easing, кривой из standardCurve и
    // безопасной границы scale для transient layer-surface.
    readonly property var panelSpring: QtObject {

        readonly property int duration: motion.defaultDuration
        readonly property real initialScale: motion.panelSpringInitialScale
        readonly property int easingType: Easing.BezierSpline
        readonly property var curve: motion.springCurve(motion.panelSpringOvershoot)
        // Граница намеренно консервативна: кубическая кривая всегда остаётся
        // в выпуклой оболочке контрольных точек, поэтому места хватает и
        // для тени, и для пружинного масштаба.
        readonly property real maximumProgress: Math.max(1,
            motion.standardCurve[1], 1 + motion.panelSpringOvershoot)
        readonly property real maximumScale: initialScale
            + (1 - initialScale) * maximumProgress
    }

    function springCurve(overshoot) {
        // BezierSpline Qt требует конечную точку сегмента. Она всегда 1, 1,
        // поэтому пользователю не нужно задавать её вручную. Первые три
        // координаты сохраняют форму standardCurve; изменяется только
        // пролёт за конечную точку.
        return [standardCurve[0], standardCurve[1], standardCurve[2],
            1 + overshoot, 1, 1];
    }
    // Пауза перед закрытием панели после клика по другому рабочему пространству.
    readonly property int panelCloseDelay: 1128
    readonly property var standardCurve: [0.05, 0.9, 0.1, 1.05, 1, 1]
}

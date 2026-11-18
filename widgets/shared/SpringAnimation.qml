import QtQuick
import "../../core"

// Единый профиль появления/закрытия. Отличается от обычного ProfileAnimation
// кривой с overshoot, вычисленной из пользовательских spring-метрик.
NumberAnimation {
    duration: Metrics.spring.durationMs
    easing.type: Metrics.spring.easingType
    easing.bezierCurve: Metrics.spring.bezierCurve
}

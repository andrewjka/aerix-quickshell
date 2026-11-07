import QtQuick
import "."

NumberAnimation {
    // Единая фирменная анимация. Duration можно переопределить в редком
    // специальном случае, сохранив общую кривую движения.
    duration: Motion.longDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.standardCurve
}

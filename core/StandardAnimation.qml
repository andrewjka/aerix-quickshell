import QtQuick
import "."

NumberAnimation {
    duration: Motion.standardDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: Motion.standardCurve
}

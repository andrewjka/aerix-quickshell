import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Одно окно на монитор. Данные виджетов поступают из общих singleton-сервисов.
PanelWindow {
    required property var modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    margins {
        top: 0
        left: Metrics.statusBarHorizontalMargin
        right: Metrics.statusBarHorizontalMargin
    }
    implicitHeight: Metrics.statusBarHeight
    color: "transparent"
    // При наведении забираем клавиатурный фокус у приложения; после ухода
    // освобождаем его. focusable: true задаёт лишь OnDemand и не гарантирует
    // передачу фокуса при наведении в Hyprland.
    WlrLayershell.keyboardFocus: statusBarHover.hovered
                                ? WlrKeyboardFocus.Exclusive
                                : WlrKeyboardFocus.None

    // Постоянная панель резервирует свою высоту, чтобы окна начинались под ней.
    exclusionMode: ExclusionMode.Auto
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aerix:status-bar"

    HoverHandler {
        id: statusBarHover
    }

    // Верхние углы примыкают к границе экрана; скруглены только нижние.
    // Заливка и обводка используют те же значения, что и поверхность Dock.
    PanelShadow {
        sourceItem: surface
    }

    Rectangle {
        id: surface
        anchors.fill: parent
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Metrics.panelRadius
        bottomRightRadius: Metrics.panelRadius
        color: Metrics.panelColor
        border.width: Metrics.panelBorderWidth
        border.color: statusBarHover.hovered
                      ? Metrics.panelBorderColor
                      : Metrics.panelInactiveBorderColor

        Behavior on border.color {
            ColorAnimation {
                duration: Motion.defaultDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.standardCurve
            }
        }
        antialiasing: true

        // Независимое центрирование оставляет часы в центре экрана, когда
        // слева и справа появятся группы разной ширины.
        ClockWidget {
            anchors.centerIn: parent
        }
    }
}

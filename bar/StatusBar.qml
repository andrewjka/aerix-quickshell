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
    implicitHeight: Metrics.statusBarHeight
    color: "transparent"
    // При наведении забираем клавиатурный фокус у приложения; после ухода
    // освобождаем его. focusable: true задаёт лишь OnDemand и не гарантирует
    // передачу фокуса при наведении в Hyprland.
    WlrLayershell.keyboardFocus: statusBarHover.hovered
                                ? WlrKeyboardFocus.Exclusive
                                : WlrKeyboardFocus.None

    // Постоянная панель резервирует свою высоту, чтобы окна начинались под ней.
    exclusiveZone: Metrics.statusBarHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aerix:status-bar"

    mask: Region {
        item: surface
    }

    // Верхние углы примыкают к границе экрана; скруглены только нижние.
    Rectangle {
        id: surface
        x: Metrics.statusBarHorizontalMargin
        width: parent.width - 2 * Metrics.statusBarHorizontalMargin
        height: Metrics.statusBarHeight
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: Metrics.panelRadius
        bottomRightRadius: Metrics.panelRadius
        color: Metrics.panelColor
        antialiasing: true

        HoverHandler {
            id: statusBarHover
        }

        // Независимое центрирование оставляет часы в центре экрана, когда
        // слева и справа появятся группы разной ширины.
        ClockWidget {
            anchors.centerIn: parent
        }
    }
}

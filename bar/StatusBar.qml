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
    // Прозрачная часть буфера нужна лишь для отрисовки внешней тени.
    implicitHeight: Metrics.statusBarHeight + Math.ceil(Metrics.panelShadowRadius) + 1
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

    // HyprGlass обрабатывает только поверхность панели, а внешняя Qt-тень
    // остаётся частью обычной композиции layer-surface.
    BackgroundEffect.blurRegion: Region {
        item: surface
        topLeftRadius: surface.topLeftRadius
        topRightRadius: surface.topRightRadius
        bottomLeftRadius: surface.bottomLeftRadius
        bottomRightRadius: surface.bottomRightRadius
    }

    mask: Region {
        item: surface
    }

    // Верхние углы примыкают к границе экрана; скруглены только нижние.
    // Заливка и обводка используют те же значения, что и поверхность Dock.
    PanelShadow {
        sourceItem: surface
    }

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

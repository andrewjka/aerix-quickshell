import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Одно окно на монитор. Данные виджетов поступают из общих singleton-сервисов.
PanelWindow {
    id: statusBar

    required property var modelData

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Metrics.statusBarHeight
    color: "transparent"
    // Обычная панель не должна забирать клавиатурный фокус у приложения.
    // Интерактивные popup управляют вводом независимо от layer-shell панели.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

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

        // Декоративная подпись скрывается раньше, чем может пересечься с часами.
        Text {
            id: brandLabel
            anchors.left: parent.left
            anchors.leftMargin: Metrics.spacing
            anchors.verticalCenter: parent.verticalCenter
            visible: parent.width >= 2 * (Metrics.spacing + implicitWidth) + clock.implicitWidth
            text: "Aerix"
            color: "#e6ffffff"
            font.pixelSize: Metrics.statusBarFontSize
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
        }

        KeyboardLayoutWidget {
            id: keyboardLayout
            barWindow: statusBar
            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacing
            anchors.verticalCenter: parent.verticalCenter
            visible: parent.width >= 2 * (Metrics.spacing + implicitWidth) + clock.implicitWidth
        }

        // Независимое центрирование оставляет часы в центре экрана, когда
        // слева и справа появятся группы разной ширины.
        ClockWidget {
            id: clock
            anchors.centerIn: parent
        }
    }
}

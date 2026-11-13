import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Одно окно на монитор. Данные виджетов поступают из общих singleton-сервисов.
PanelWindow {
    id: statusBar

    required property var modelData
    property bool overviewOpen: false
    signal overviewRequested(var screen)

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Metrics.statusBarHeight
    color: Theme.transparentColor
    // Обычная панель не должна забирать клавиатурный фокус у приложения.
    // Интерактивные popup управляют вводом независимо от layer-shell панели.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Постоянная панель резервирует свою высоту, чтобы окна начинались под ней.
    exclusiveZone: Metrics.statusBarHeight
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "aerix:status-bar"

    onOverviewOpenChanged: {
        if (overviewOpen)
            keyboardLayout.dismissPopup();
    }

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
        color: Theme.backgroundColor
        antialiasing: true

        // Этот обработчик находится ниже интерактивных виджетов. Пока popup
        // открыт, клик по свободной части именно этого Bar закрывает его через
        // reverse-анимацию; click trigger забирает собственный MouseArea.
        MouseArea {
            anchors.fill: parent
            enabled: keyboardLayout.popupOpen
            acceptedButtons: Qt.AllButtons
            onClicked: keyboardLayout.dismissPopup()
        }

        // Логотип скрывается раньше, чем может пересечься с часами.
        Image {
            id: brandLogo
            anchors.left: parent.left
            anchors.leftMargin: Metrics.spacing
            anchors.verticalCenter: parent.verticalCenter
            width: 96
            height: parent.height
            visible: parent.width >= 2 * (Metrics.spacing + width) + clock.implicitWidth
            source: Qt.resolvedUrl("../media/icons/Aerix-logo.svg")
            sourceSize.width: Math.ceil(width * statusBar.devicePixelRatio)
            sourceSize.height: Math.ceil(height * statusBar.devicePixelRatio)
            fillMode: Image.PreserveAspectFit
            smooth: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: statusBar.overviewRequested(statusBar.modelData)
            }
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

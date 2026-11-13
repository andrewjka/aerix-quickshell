pragma ComponentBehavior: Bound

import QtQuick
import Qt5Compat.GraphicalEffects
import Quickshell
import "../../core"
import "../../services"

// Вся зона виджета открывает список раскладок.
Item {
    id: widget

    required property var barWindow

    property bool popupOpen: false
    readonly property bool canInteract: KeyboardService.available
    implicitWidth: content.width
    implicitHeight: content.height
    width: implicitWidth
    height: implicitHeight

    signal popupOpened()

    function closePopup() {
        popupOpen = false;
    }

    // Внешние поверхности запрашивают закрытие у живого popup, чтобы Loader
    // дождался обратной spring-анимации. `closePopup` остаётся финальным
    // callback-ом `dismissed`, который только выгружает уже закрытый слой.
    function dismissPopup() {
        if (popupLoader.item)
            (popupLoader.item as KeyboardLayoutPopup).dismiss();
        else
            closePopup();
    }

    function openPopup() {
        // На открытии перечитываем devices: Hyprland не предоставляет
        // отдельного надёжного rawEvent для hotplug клавиатуры.
        KeyboardService.refresh();
        popupOpened();
        popupOpen = true;
    }

    Item {
        id: content
        anchors.centerIn: parent
        implicitWidth: layoutLabel.implicitWidth + 4 + languageIcon.width
        implicitHeight: Math.max(layoutLabel.implicitHeight, languageIcon.height)

        Text {
            id: layoutLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: KeyboardService.activeLabel
            color: widget.canInteract ? Theme.foregroundColor : Theme.disabledForegroundColor
            font.pixelSize: Metrics.statusBarFontSize
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            id: languageIcon
            anchors.left: layoutLabel.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: Metrics.statusBarFontSize + 2
            height: width

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("../../assets/icons/language.svg")
                sourceSize.width: Math.ceil(width * widget.barWindow.devicePixelRatio)
                sourceSize.height: Math.ceil(height * widget.barWindow.devicePixelRatio)
                fillMode: Image.PreserveAspectFit
                smooth: true
                // Layer effect получает текстуру Image автоматически и
                // перекрашивает нейтральный SVG в текущий цвет темы.
                layer.enabled: true
                layer.effect: ColorOverlay {
                    color: layoutLabel.color
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: widget.canInteract
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (widget.popupOpen)
                (popupLoader.item as KeyboardLayoutPopup)?.toggle();
            else
                widget.openPopup();
        }
    }

    LazyLoader {
        id: popupLoader
        active: widget.popupOpen

        component: KeyboardLayoutPopup {
            barWindow: widget.barWindow
            anchorItem: widget
            onDismissed: widget.closePopup()
        }
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "shared" as Shared
import "../../core"
import "../../services"

// Вся зона виджета открывает список раскладок.
Item {
    id: widget

    required property var barWindow

    property bool popupOpen: false
    readonly property bool canInteract: KeyboardService.available
    readonly property real dpr: widget.barWindow?.devicePixelRatio ?? 1

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

        // Целые размеры и позиция: дробные значения (ширина текста,
        // centerIn при нечётной разнице) ставят содержимое на доли пикселя
        // и дают мыло или «кривую» иконку.
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        implicitWidth: Math.ceil(layoutLabel.implicitWidth) + 4 + languageIcon.width
        implicitHeight: Math.ceil(Math.max(layoutLabel.implicitHeight, languageIcon.height))

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
            width: Metrics.statusBarWidgetIconSize
            height: Metrics.statusBarWidgetIconSize

            Shared.StatusBarIcon {
                anchors.fill: parent
                iconSource: Qt.resolvedUrl("../../assets/icons/language.svg")
                tintColor: widget.canInteract ? Theme.foregroundColor
                                              : Theme.disabledForegroundColor
                devicePixelRatio: widget.dpr
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

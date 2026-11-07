pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../core"
import "../services"

// Вся зона виджета открывает список раскладок.
Item {
    id: widget

    required property var barWindow

    property bool popupOpen: false
    // Временная модель для ручной проверки прокрутки; 0 возвращает обычный список.
    property int testLayoutCount: 32
    readonly property bool canInteract: KeyboardLayoutService.available || testLayoutCount > 0
    implicitWidth: content.width
    implicitHeight: content.height
    width: implicitWidth
    height: implicitHeight

    function closePopup() {
        popupOpen = false;
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            id: layoutLabel
            text: KeyboardLayoutService.activeLabel
            color: widget.canInteract ? "#e6ffffff" : "#80ffffff"
            font.pixelSize: Metrics.statusBarFontSize
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
        }

        Text {
            text: ""
            color: widget.canInteract ? "#b3ffffff" : "#66ffffff"
            font.family: "Font Awesome 7 Free"
            font.styleName: "Solid"
            font.pixelSize: Metrics.statusBarFontSize - 1
            verticalAlignment: Text.AlignVCenter
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
                widget.popupOpen = true;
        }
    }

    LazyLoader {
        id: popupLoader
        active: widget.popupOpen

        component: KeyboardLayoutPopup {
            barWindow: widget.barWindow
            anchorItem: widget
            testLayoutCount: widget.testLayoutCount
            onDismissed: widget.closePopup()
        }
    }
}

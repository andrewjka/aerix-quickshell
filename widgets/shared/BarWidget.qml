pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../core"

// Кнопка bar и ленивый владелец popup. Сервисные действия задаются сигналами,
// а закрытый popup освобождается только после завершения обратной анимации.
Item {
    id: widget
    required property var barWindow
    required property url iconSource
    required property Component popupComponent
    property bool canInteract: true
    property bool popupOpen: false
    // Loader возвращает фактический дочерний тип (BrightnessPopup и т. п.).
    // `var` избегает хрупкого QML cast к базовому типу при первом кадре загрузки.
    readonly property var popup: popupLoader.item
    property string label: ""
    property bool badgeVisible: false
    implicitWidth: content.width
    implicitHeight: content.height
    signal popupOpening()
    signal popupOpened()
    signal wheelStep(int direction)

    function closePopup() {
        reopenTimer.stop();
        popupOpen = false;
    }
    function dismissPopup() {
        if (popup)
            popup.dismiss();
        else
            closePopup();
    }
    function openPopup() {
        if (!canInteract) return;
        popupOpening();
        popupOpened();
        popupOpen = true;
    }
    // История при быстром повторном открытии должна получить новый каскад.
    function restartPopup() {
        closePopup();
        reopenTimer.start();
    }

    Timer {
        id: reopenTimer
        interval: 0
        onTriggered: widget.openPopup()
    }

    Row {
        id: content
        x: Math.round((parent.width - width) / 2)
        y: Math.round((parent.height - height) / 2)
        spacing: widget.label ? 4 : 0
        Text {
            visible: widget.label.length > 0
            width: Math.ceil(implicitWidth)
            anchors.verticalCenter: parent.verticalCenter
            text: widget.label
            color: widget.canInteract ? Theme.foregroundColor : Theme.disabledForegroundColor
            font.pixelSize: Metrics.statusBarFontSize
            font.weight: Font.Medium
        }
        Item {
            width: Math.ceil(icon.width)
            height: Metrics.statusBarWidgetIconSize
            anchors.verticalCenter: parent.verticalCenter
            IconWidget {
                id: icon
                anchors.centerIn: parent
                height: parent.height
                iconSource: widget.iconSource
                whiteSource: true
                tintColor: widget.canInteract ? Theme.foregroundColor : Theme.disabledForegroundColor
                devicePixelRatio: widget.barWindow?.devicePixelRatio ?? 1
            }
            Rectangle {
                visible: widget.badgeVisible
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -2
                anchors.topMargin: -2
                width: 7
                height: 7
                radius: width / 2
                color: "#E53935"
                border.width: 1
                border.color: Theme.backgroundColor
                antialiasing: true
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: widget.canInteract
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (widget.popup)
                widget.popup.toggle();
            else
                widget.openPopup();
        }
        onWheel: wheel => {
            const direction = Math.sign(wheel.angleDelta.y);
            if (direction) widget.wheelStep(direction);
            wheel.accepted = true;
        }
    }
    LazyLoader {
        id: popupLoader
        active: widget.popupOpen
        component: widget.popupComponent
    }
}

pragma ComponentBehavior: Bound

import QtQuick
import "../../core"

// Строка «иконка — значение — шкала». Системные команды остаются у потребителя.
// Во время drag держим локальное значение, чтобы асинхронный сервис не дёргал бегунок.
Item {
    id: control
    required property url iconSource
    required property string text
    required property real value
    property real from: 0
    property real to: 100
    property real stepSize: 1
    property bool interactive: true
    property bool iconInteractive: false
    property color iconColor: Theme.foregroundColor
    property real devicePixelRatio: 1
    readonly property real currentValue: pointer.pressed ? pointer.draggedValue : value
    readonly property real progress: Math.max(0, Math.min(1,
        (currentValue - from) / Math.max(1, to - from)))
    signal valueEdited(real value)
    signal iconClicked()

    function setFromX(positionX) {
        const fraction = Math.max(0, Math.min(1, positionX / Math.max(1, slider.width)));
        const raw = from + fraction * (to - from);
        const next = stepSize > 0 ? from + Math.round((raw - from) / stepSize) * stepSize : raw;
        pointer.draggedValue = Math.max(from, Math.min(to, next));
        valueEdited(pointer.draggedValue);
    }

    IconWidget {
        id: icon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: Metrics.statusBarFontSize + 6
        iconSource: control.iconSource
        tintColor: control.iconColor
        whiteSource: true
        devicePixelRatio: control.devicePixelRatio

        MouseArea {
            anchors.fill: parent
            enabled: control.iconInteractive
            cursorShape: Qt.PointingHandCursor
            onClicked: control.iconClicked()
        }
    }

    Text {
        id: label
        anchors.left: icon.right
        anchors.leftMargin: Metrics.spacing
        anchors.verticalCenter: parent.verticalCenter
        text: control.text
        color: Theme.foregroundColor
        font.pixelSize: Metrics.statusBarFontSize
        font.weight: Font.Medium
        verticalAlignment: Text.AlignVCenter
    }

    Item {
        id: slider
        anchors.left: label.right
        anchors.leftMargin: Metrics.spacing
        anchors.right: parent.right
        height: parent.height

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: Metrics.panelRadius
            color: Theme.overlayColor

            Rectangle {
                width: control.progress * parent.width
                height: parent.height
                radius: Metrics.panelRadius
                color: Theme.accentColor
            }
        }

        Rectangle {
            x: control.progress * (slider.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: 12
            height: 12
            radius: Metrics.panelRadius
            color: Theme.foregroundColor
            antialiasing: true
        }

        MouseArea {
            id: pointer
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 16
            enabled: control.interactive
            cursorShape: Qt.PointingHandCursor
            property real draggedValue: control.value
            onPressed: mouse => control.setFromX(mouse.x)
            onPositionChanged: mouse => {
                if (pressed)
                    control.setFromX(mouse.x);
            }
            onReleased: mouse => control.setFromX(mouse.x)
        }
    }
}

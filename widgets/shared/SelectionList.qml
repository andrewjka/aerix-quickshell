pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import "../../core"

// Общий список устройств/раскладок. ListView создаёт только видимые строки;
// выбор и подписи задаются снаружи, чтобы компонент не зависел от сервисов.
ListView {
    id: list
    property int rowHeight: 32
    property bool interactiveRows: true
    property var labelFor: entry => entry.label
    property var detailFor: entry => ""
    property var selectedFor: entry => false
    signal chosen(var entry, int index)

    clip: true
    topMargin: 1
    bottomMargin: 1
    spacing: Metrics.popupRowSpacing
    boundsBehavior: Flickable.StopAtBounds
    highlightMoveDuration: 0
    ScrollBar.vertical: ScrollBar {
        parent: list.parent
        x: list.x + list.width + 2
        y: list.y
        height: list.height
        width: 4
        policy: ScrollBar.AsNeeded
    }

    delegate: Item {
        id: row
        required property var modelData
        required property int index
        readonly property bool selected: list.selectedFor(modelData)
        readonly property string detail: list.detailFor(modelData)
        width: list.width
        height: list.rowHeight

        // Hover и выбранное состояние независимы: уход курсора не снимает выбор.
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            radius: Metrics.panelRadius
            color: Theme.hoverColor
            opacity: pointer.containsMouse ? 1 : 0
            antialiasing: true
            Behavior on opacity {
                NumberAnimation { duration: Metrics.quickDurationMs }
            }
        }
        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 1
            anchors.rightMargin: 1
            radius: Metrics.panelRadius
            color: Theme.hoverColor
            opacity: row.selected ? 1 : 0
            border.width: 0.5
            border.pixelAligned: false
            border.color: Theme.borderColor
            antialiasing: true
            Behavior on opacity {
                Metrics.ProfileAnimation { duration: Metrics.quickDurationMs }
            }
        }
        Text {
            id: label
            x: Metrics.spacing
            anchors.verticalCenter: parent.verticalCenter
            width: row.detail ? implicitWidth : parent.width - 2 * Metrics.spacing
            text: list.labelFor(row.modelData)
            color: Theme.foregroundColor
            font.pixelSize: Metrics.statusBarFontSize
            font.weight: row.selected ? Font.DemiBold : Font.Medium
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        Text {
            anchors.left: label.right
            anchors.leftMargin: Metrics.spacing
            anchors.right: parent.right
            anchors.rightMargin: Metrics.spacing
            anchors.verticalCenter: parent.verticalCenter
            visible: row.detail.length > 0
            text: row.detail
            color: Theme.foregroundColor
            font.pixelSize: 13
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }
        MouseArea {
            id: pointer
            anchors.fill: parent
            enabled: list.interactiveRows
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: list.chosen(row.modelData, row.index)
        }
    }
}

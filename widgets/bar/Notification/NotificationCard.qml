pragma ComponentBehavior: Bound

import QtQuick
import "../../../core"
import "../../../services"

// Общая компактная карточка для истории и toast-а.
Item {
    id: card

    required property var notification
    readonly property int outerPadding: Metrics.spacing
    readonly property int maxBodyHeight: Math.max(0, height - bodyLabel.y
        - outerPadding)
    implicitHeight: Metrics.notificationCardHeight
    width: parent?.width ?? 0
    height: implicitHeight

    Rectangle {
        anchors.fill: parent
        radius: Metrics.panelRadius
        // Каждая карточка имеет собственную поверхность общего стиля.
        color: Theme.backgroundColor
        border.width: 1
        border.color: Theme.borderColor
        antialiasing: true
    }

    Text {
        id: appLabel
        x: card.outerPadding
        y: card.outerPadding
        width: parent.width - 2 * card.outerPadding - dismissButton.width
        text: card.notification?.appName || card.notification?.desktopEntry
            || I18n.tr("notifications.title")
        color: Theme.foregroundColor
        font.pixelSize: 12
        font.weight: Font.Medium
        elide: Text.ElideRight
        textFormat: Text.PlainText
        verticalAlignment: Text.AlignVCenter
    }

    Text {
        id: summaryLabel
        x: card.outerPadding
        y: appLabel.y + appLabel.height + 2
        width: parent.width - 2 * card.outerPadding
        text: card.notification?.summary || card.notification?.appName
            || I18n.tr("notifications.title")
        color: Theme.foregroundColor
        font.pixelSize: Metrics.statusBarFontSize
        font.weight: Font.Medium
        wrapMode: Text.Wrap
        maximumLineCount: 1
        textFormat: Text.PlainText
        elide: Text.ElideRight
    }

    Text {
        id: bodyLabel
        x: card.outerPadding
        y: summaryLabel.y + summaryLabel.height + 4
        width: parent.width - 2 * card.outerPadding
        text: card.notification?.body || ""
        visible: text.length > 0
        height: Math.min(implicitHeight, card.maxBodyHeight)
        color: Theme.foregroundColor
        font.pixelSize: 12
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        textFormat: Text.PlainText
        clip: true
    }

    Text {
        id: dismissButton
        anchors.right: parent.right
        anchors.rightMargin: card.outerPadding
        anchors.verticalCenter: appLabel.verticalCenter
        width: 16
        height: 16
        text: "×"
        color: Theme.foregroundColor
        font.pixelSize: 18
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: NotificationService.dismiss(card.notification)
        }
    }
}

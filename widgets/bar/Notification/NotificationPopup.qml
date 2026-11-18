pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../shared" as Shared
import "../../../core"
import "../../../services"

// Заголовок и геометрия колоды. Слот отвечает за каскад, hover и ленивую
// отрисовку карточки; модель сохраняет её идентичность при обновлении текста.
Shared.BarPopup {
    id: historyPopup
    layerNamespace: "aerix:notifications"
    preferredWidth: 320
    restartOnReopen: true
    readonly property int headerHeight: 26
    readonly property int emptyHeight: 42
    readonly property bool hasNotifications: historyCards.count > 0
    readonly property int maximumListHeight: Math.max(0,
        (screen.height - layout.popupTop - 2 * layout.shadowMargin
            - layout.revealTravel * layout.progressOverflow) / (1 + layout.scaleOverflow)
            - panelHeight - Metrics.popupRowSpacing)
    readonly property int listHeight: Math.min(maximumListHeight,
        Math.min(5, historyCards.count) * Metrics.notificationCardHeight
            + Math.max(0, Math.min(5, historyCards.count) - 1) * Metrics.popupRowSpacing)
    panelHeight: headerHeight + 2 * Metrics.spacing
        + (hasNotifications ? 0 : Metrics.spacing + emptyHeight)
    surfaceHeight: panelHeight + (hasNotifications ? Metrics.popupRowSpacing + listHeight : 0)

    // Только заголовок принадлежит этому окну. У каждой карточки свой blur.
    BackgroundEffect.blurRegion: Region {
        item: headerRegion
        radius: Metrics.panelRadius
    }
    Item {
        id: headerRegion
        width: parent.width
        height: historyPopup.panelHeight
    }
    NotificationModel {
        id: historyCards
        entries: NotificationService.notifications
    }

    Text {
        id: title
        x: Metrics.spacing
        y: Metrics.spacing
        width: parent.width - 2 * Metrics.spacing - clearButton.width
        height: historyPopup.headerHeight
        text: I18n.tr("notifications.title")
        color: Theme.foregroundColor
        font.pixelSize: Metrics.statusBarFontSize
        font.weight: Font.Medium
        verticalAlignment: Text.AlignVCenter
    }
    Text {
        id: clearButton
        anchors.right: parent.right
        anchors.rightMargin: Metrics.spacing
        anchors.verticalCenter: title.verticalCenter
        width: implicitWidth
        height: historyPopup.headerHeight
        visible: NotificationService.activeNotificationCount > 0
        text: I18n.tr("notifications.clearAll")
        color: Theme.foregroundColor
        font.pixelSize: 12
        font.weight: Font.Medium
        verticalAlignment: Text.AlignVCenter
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: NotificationService.clearAll()
        }
    }

    Flickable {
        id: historyList
        y: historyPopup.panelHeight + Metrics.popupRowSpacing
        width: parent.width
        height: historyPopup.hasNotifications ? historyPopup.listHeight : 0
        visible: historyPopup.hasNotifications
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        readonly property real cardStep: Math.max(24, Metrics.notificationCardHeight * 0.36)
        readonly property real expandedOffset: Metrics.notificationCardHeight
            + Metrics.popupRowSpacing - cardStep
        property int hoveredIndex: -1
        contentWidth: width
        contentHeight: Math.max(height, Metrics.notificationCardHeight
            + Math.max(0, historyCards.count - 1) * cardStep
            + (hoveredIndex >= 0 ? expandedOffset : 0))
        onContentHeightChanged: contentY = Math.max(0, Math.min(contentY, contentHeight - height))

        ScrollBar.vertical: ScrollBar {
            parent: historyList.parent
            x: historyList.x + historyList.width + 2
            y: historyList.y
            height: historyList.height
            width: 4
            policy: ScrollBar.AsNeeded
        }
        Repeater {
            id: slots
            property int mappingRevision: 0
            onItemAdded: mappingRevision++
            onItemRemoved: mappingRevision++
            model: historyCards

            delegate: NotificationHistoryEntry {
                id: entry
                popup: historyPopup
                list: historyList
                displaced: historyList.hoveredIndex >= 0 && index > historyList.hoveredIndex
                y: index * historyList.cardStep + (displaced ? historyList.expandedOffset : 0)
                // Wayland складывает поверхности в порядке отображения, не по z.
                precedingMapped: {
                    const revision = slots.mappingRevision;
                    return index === 0
                        || ((slots.itemAt(index - 1) as NotificationHistoryEntry)?.entryReveal ?? 0) > 0;
                }
                onHovered: inside => {
                    if (inside) historyList.hoveredIndex = entry.index;
                    else if (historyPopup.expanded && historyList.hoveredIndex === entry.index)
                        historyList.hoveredIndex = -1;
                }
            }
        }
    }

    Text {
        x: Metrics.spacing
        y: title.y + title.height + Metrics.spacing
        width: parent.width - 2 * Metrics.spacing
        height: historyPopup.emptyHeight
        visible: !historyPopup.hasNotifications
        text: I18n.tr("notifications.empty")
        color: Theme.foregroundColor
        font.pixelSize: Metrics.statusBarFontSize
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
}

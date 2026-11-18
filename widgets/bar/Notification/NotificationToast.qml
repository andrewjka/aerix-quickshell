pragma ComponentBehavior: Bound

import QtQuick
import "../../shared" as Shared
import "../../../core"
import "../../../services"

// Координатор не создаёт собственного окна. После пятой карточки уменьшается
// только шаг колоды; размер каждой карточки и занятая высота сохраняются.
Item {
    id: toast
    required property var barWindow
    required property Item anchorItem
    property bool expanded: false
    property real reveal: expanded ? 1 : 0
    readonly property int visibleLimit: 5
    readonly property var entries: NotificationService.toastsForScreen(barWindow.screen)
        .map(entry => entry.notification)
    signal dismissed()

    function updateEntries() {
        if (entries.length) cards.entries = entries;
        expanded = entries.length > 0;
    }
    onEntriesChanged: updateEntries()
    Component.onCompleted: updateEntries()
    implicitWidth: layout.windowRect.width
    implicitHeight: layout.windowRect.height
    Behavior on reveal {
        NumberAnimation {
            duration: Metrics.spring.durationMs
            easing.type: Metrics.spring.easingType
            easing.bezierCurve: Metrics.spring.bezierCurve
            onRunningChanged: {
                if (!running && !toast.expanded && toast.reveal === 0)
                    toast.dismissed();
            }
        }
    }
    Shared.PopupLayout {
        id: layout
        barWindow: toast.barWindow
        anchorItem: toast.anchorItem
        preferredWidth: 320
        surfaceHeight: stack.implicitHeight
    }
    NotificationModel {
        id: cards
        // Последний набор остаётся жив до конца обратного перехода всей колоды.
    }

    Item {
        id: frame
        x: layout.horizontalMargin
        y: layout.topMargin - layout.revealTravel * (1 - toast.reveal)
        width: layout.surfaceWidth
        height: layout.surfaceHeight
        scale: Metrics.spring.startScale + (1 - Metrics.spring.startScale) * toast.reveal
        transformOrigin: Item.Top
        opacity: Math.max(0, Math.min(1, toast.reveal))

        Item {
            id: stack
            width: parent.width
            readonly property real cardHeight: Math.min(Metrics.notificationCardHeight,
                Math.max(1, toast.barWindow.screen.height - layout.popupTop - 2 * layout.shadowMargin))
            readonly property real availableHeight: Math.max(cardHeight,
                (toast.barWindow.screen.height - layout.popupTop - 2 * layout.shadowMargin
                    - layout.revealTravel * layout.progressOverflow) / (1 + layout.scaleOverflow))
            readonly property real occupiedHeight: Math.min(availableHeight,
                Math.min(cards.count, toast.visibleLimit) * cardHeight
                + Math.max(0, Math.min(cards.count, toast.visibleLimit) - 1) * Metrics.popupRowSpacing)
            readonly property real step: Math.max(0, occupiedHeight - cardHeight)
                / Math.max(1, cards.count - 1)
            implicitHeight: occupiedHeight

            Repeater {
                model: cards
                delegate: Item {
                    id: slot
                    required property int index
                    required property int notificationId
                    required property string appName
                    required property string desktopEntry
                    required property string summary
                    required property string body
                    required property bool closing
                    property real insertionReveal: 0
                    property real insertionTravel: 0
                    property real closeReveal: closing ? 0 : 1
                    readonly property real visibilityProgress: insertionReveal * closeReveal
                    readonly property real visualY: y + insertionTravel * (1 - insertionReveal)
                    x: 0
                    y: index * stack.step
                    width: stack.width
                    height: stack.cardHeight
                    z: index
                    scale: Metrics.spring.startScale + (1 - Metrics.spring.startScale) * visibilityProgress
                    opacity: Math.max(0, Math.min(1, visibilityProgress))
                    transformOrigin: Item.Bottom
                    Component.onCompleted: {
                        insertionTravel = index >= toast.visibleLimit ? stack.occupiedHeight - y : 0;
                        insertion.start();
                    }
                    Shared.SpringAnimation {
                        id: insertion
                        target: slot
                        property: "insertionReveal"
                        from: 0
                        to: 1
                    }
                    Behavior on y { Metrics.ProfileAnimation {} }
                    Behavior on closeReveal { Metrics.ProfileAnimation {} }

                    Shared.CardLayer {
                        targetScreen: toast.barWindow.screen
                        layerNamespace: "aerix:notification-toast-card"
                        shadowNamespace: "aerix:notification-toast-shadow"
                        windowRect: layout.windowRect
                        cardRect: Qt.rect(
                            frame.x + slot.width * (1 - slot.scale) / 2 * frame.scale
                                + frame.width * (1 - frame.scale) / 2,
                            frame.y + (slot.visualY + slot.height * (1 - slot.scale)) * frame.scale,
                            slot.width, slot.height)
                        cardScale: frame.scale * slot.scale
                        cardOpacity: frame.opacity * slot.opacity
                        content: NotificationCard {
                            notification: ({ id: slot.notificationId, appName: slot.appName,
                                desktopEntry: slot.desktopEntry, summary: slot.summary, body: slot.body })
                        }
                    }
                }
            }
        }
    }
}

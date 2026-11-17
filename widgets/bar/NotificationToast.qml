pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../core"
import "../../services"

// Карточки сохраняют размер. После пятой уменьшается только шаг между ними,
// поэтому колода занимает ту же высоту, а последнее сообщение целиком видно.
Item {
    id: toast

    required property var barWindow
    required property Item anchorItem
    property bool expanded: false
    property real reveal: expanded ? 1 : 0
    readonly property var entries:
        NotificationService.toastsForScreen(barWindow.screen)
    readonly property int visibleLimit: 5
    ListModel { id: cards }
    readonly property int revealTravel: 24
    readonly property real springScaleOverflow: Math.max(0,
        Metrics.spring.maximumScale - 1)
    readonly property real springProgressOverflow: Math.max(0,
        Metrics.spring.maximumProgress - 1)
    readonly property int shadowMargin: Math.ceil(Metrics.panelShadowRadius) + 1
    readonly property int topRenderMargin: shadowMargin + revealTravel
    readonly property int bottomRenderMargin: shadowMargin + Math.ceil(
        revealTravel * springProgressOverflow) + Math.ceil(
        surfaceHeight * springScaleOverflow)
    readonly property int horizontalRenderMargin: shadowMargin + Math.ceil(
        surfaceWidth * springScaleOverflow / 2)
    readonly property int popupTop: barWindow.height + 2 * Metrics.spacing
    readonly property int surfaceWidth: Math.min(320,
        screen.width - 2 * Metrics.statusBarHorizontalMargin)
    readonly property int surfaceHeight: cardStack.implicitHeight
    readonly property real surfaceX: {
        const position = anchorItem.mapToItem(barWindow.contentItem, 0, 0);
        return Math.round(Math.max(Metrics.statusBarHorizontalMargin,
            Math.min(position.x + anchorItem.width / 2 - surfaceWidth / 2,
                barWindow.width - Metrics.statusBarHorizontalMargin - surfaceWidth)));
    }

    signal dismissed()

    // Координатор геометрии не создаёт собственного Wayland-окна.
    // Поверхности нужны только самим карточкам и их теням.
    readonly property var screen: barWindow.screen
    readonly property real windowLeft: surfaceX - horizontalRenderMargin
    readonly property real windowTop: popupTop - topRenderMargin
    implicitWidth: surfaceWidth + 2 * horizontalRenderMargin
    implicitHeight: surfaceHeight + topRenderMargin + bottomRenderMargin

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

    function show() {
        if (entries.length === 0)
            return;
        // Сохраняем делегаты существующих сообщений: анимация запускается
        // ровно при создании новой карточки, независимо от её индекса.
        for (let i = cards.count - 1; i >= 0; --i) {
            if (!entries.some(entry => entry.notification.id === cards.get(i).notificationId))
                cards.remove(i);
        }
        for (const entry of entries) {
            let foundIndex = -1;
            for (let i = 0; i < cards.count; ++i)
                if (cards.get(i).notificationId === entry.notification.id) foundIndex = i;
            if (foundIndex < 0)
                cards.append({ notificationId: entry.notification.id,
                    appName: entry.notification.appName || "",
                    desktopEntry: entry.notification.desktopEntry || "",
                    summary: entry.notification.summary || "",
                    body: entry.notification.body || "",
                    closing: entry.notification.closing === true });
            else {
                cards.setProperty(foundIndex, "appName", entry.notification.appName || "");
                cards.setProperty(foundIndex, "desktopEntry", entry.notification.desktopEntry || "");
                cards.setProperty(foundIndex, "summary", entry.notification.summary || "");
                cards.setProperty(foundIndex, "body", entry.notification.body || "");
                cards.setProperty(foundIndex, "closing", entry.notification.closing === true);
            }
        }
        expanded = true;
    }

    function dismiss() { expanded = false; }

    Component.onCompleted: show()

    Connections {
        target: NotificationService

        function onToastEntriesChanged() {
            if (toast.entries.length > 0)
                toast.show();
            else
                toast.dismiss();
        }
    }

    Rectangle {
        id: toastFrame
        x: toast.horizontalRenderMargin
        y: toast.topRenderMargin - toast.revealTravel * (1 - toast.reveal)
        width: toast.surfaceWidth
        height: toast.surfaceHeight
        radius: Metrics.panelRadius
        color: Theme.transparentColor
        border.width: 0
        border.color: Theme.borderColor
        antialiasing: true
        scale: Metrics.spring.startScale
            + (1 - Metrics.spring.startScale) * toast.reveal
        transformOrigin: Item.Top
        opacity: Math.max(0, Math.min(1, toast.reveal))

        Item {
            id: cardStack
            width: parent.width
            readonly property real cardHeight: Math.min(Metrics.notificationCardHeight,
                Math.max(1, toast.screen.height - toast.popupTop - 2 * toast.shadowMargin))
            readonly property real availableHeight: Math.max(cardHeight,
                (toast.screen.height - toast.popupTop - 2 * toast.shadowMargin
                    - toast.revealTravel * toast.springProgressOverflow)
                    / (1 + toast.springScaleOverflow))
            readonly property real occupiedHeight: Math.min(availableHeight,
                Math.min(cards.count, toast.visibleLimit) * cardHeight
                + Math.max(0, Math.min(cards.count, toast.visibleLimit) - 1)
                    * Metrics.popupRowSpacing)
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
                    x: 0
                    y: index * cardStack.step
                    width: cardStack.width
                    height: cardStack.cardHeight
                    z: index
                    property real insertionReveal: 0
                    property real insertionTravel: 0
                    property real closeReveal: closing ? 0 : 1
                    readonly property real visualY: y + insertionTravel * (1 - insertionReveal)
                    Component.onCompleted: {
                        insertionTravel = index >= toast.visibleLimit
                            ? cardStack.occupiedHeight - y : 0;
                        insertion.start();
                    }
                    NumberAnimation {
                        id: insertion
                        target: slot
                        property: "insertionReveal"
                        from: 0
                        to: 1
                        duration: Metrics.spring.durationMs
                        easing.type: Metrics.spring.easingType
                        easing.bezierCurve: Metrics.spring.bezierCurve
                    }
                    Behavior on y { Metrics.ProfileAnimation {} }
                    Behavior on closeReveal { Metrics.ProfileAnimation {} }
                    readonly property real visibilityProgress: insertionReveal * closeReveal
                    scale: Metrics.spring.startScale + (1 - Metrics.spring.startScale)
                        * visibilityProgress
                    opacity: Math.max(0, Math.min(1, visibilityProgress))
                    transformOrigin: Item.Bottom

                    // Отдельный буфер позволяет размывать также карточки,
                    // расположенные под новым уведомлением.
                    PanelWindow {
                        screen: toast.screen
                        anchors { top: true; left: true }
                        margins.left: toast.windowLeft
                        margins.top: toast.windowTop
                        implicitWidth: toast.width
                        implicitHeight: toast.height
                        exclusionMode: ExclusionMode.Ignore
                        color: Theme.transparentColor
                        focusable: false
                        WlrLayershell.namespace: "aerix:notification-toast-card"
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                        mask: Region { item: cardSurface; radius: Metrics.panelRadius }
                        BackgroundEffect.blurRegion: Region {
                            item: cardSurface
                            radius: Metrics.panelRadius
                        }
                        NotificationCard {
                            id: cardSurface
                            x: cardShadow.x
                            y: cardShadow.y
                            width: slot.width
                            height: slot.height
                            scale: toastFrame.scale * slot.scale
                            transformOrigin: Item.TopLeft
                            opacity: toastFrame.opacity * slot.opacity
                            animateClosing: false
                            notification: ({ id: slot.notificationId, appName: slot.appName,
                                desktopEntry: slot.desktopEntry, summary: slot.summary, body: slot.body })
                        }
                    }

                    PanelShadowWindow {
                        targetScreen: toast.screen
                        shadowSource: cardShadow
                        shadowNamespace: "aerix:notification-toast-shadow"
                        visible: slot.visible
                        shadowOpacity: toastFrame.opacity * slot.opacity
                        WlrLayershell.layer: WlrLayer.Overlay
                        anchors { top: true; left: true }
                        margins.left: toast.windowLeft
                        margins.top: toast.windowTop
                        implicitWidth: toast.width
                        implicitHeight: toast.height
                        Rectangle {
                            id: cardShadow
                            x: toastFrame.x + slot.width * (1 - slot.scale) / 2 * toastFrame.scale
                                + toastFrame.width * (1 - toastFrame.scale) / 2
                            y: toastFrame.y + (slot.visualY + slot.height * (1 - slot.scale)) * toastFrame.scale
                            width: slot.width * toastFrame.scale * slot.scale
                            height: slot.height * toastFrame.scale * slot.scale
                            radius: Metrics.panelRadius
                            color: Theme.transparentColor
                        }
                    }
                }
            }
        }
    }
}

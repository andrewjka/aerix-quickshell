pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../core"
import "../../services"

// История уведомлений открывается из Bar тем же spring-переходом, что и
// остальные popup-виджеты. Список остаётся прокручиваемым на небольших экранах.
PanelWindow {
    id: popup

    required property var barWindow
    required property Item anchorItem
    property bool expanded: false
    property real reveal: expanded ? 1 : 0
    ListModel { id: historyCards }

    // Обновляем роли по id: замена JS-массива пересоздавала делегаты
    // уже в закрытом состоянии, поэтому Behavior не успевал запуститься.
    function syncHistory() {
        const entries = NotificationService.notifications;
        for (let i = historyCards.count - 1; i >= 0; --i)
            if (!entries.some(entry => entry.id === historyCards.get(i).notificationId))
                historyCards.remove(i);
        for (const entry of entries) {
            let found = -1;
            for (let i = 0; i < historyCards.count; ++i)
                if (historyCards.get(i).notificationId === entry.id) found = i;
            const row = { notificationId: entry.id, appName: entry.appName || "",
                desktopEntry: entry.desktopEntry || "", summary: entry.summary || "",
                body: entry.body || "", isClosing: entry.closing === true };
            if (found < 0) historyCards.append(row);
            else historyCards.set(found, row);
        }
    }
    Connections {
        target: NotificationService
        function onNotificationsChanged() { popup.syncHistory(); }
    }
    readonly property int headerHeight: 26
    readonly property int emptyHeight: 42
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
    // Как у toast: область вмещает до пяти полных карточек. Заголовок
    // и запас для spring учитываются отдельно в доступной высоте экрана.
    readonly property int maximumListHeight: Math.max(0,
        (screen.height - popupTop - 2 * shadowMargin
            - revealTravel * springProgressOverflow) / (1 + springScaleOverflow)
            - headerCardHeight - Metrics.popupRowSpacing)
    readonly property int listHeight: Math.min(maximumListHeight,
        Math.min(5, historyCards.count) * Metrics.notificationCardHeight
            + Math.max(0, Math.min(5, historyCards.count) - 1) * Metrics.popupRowSpacing)
    readonly property bool hasNotifications:
        NotificationService.notificationCount > 0
    readonly property int headerCardHeight: headerHeight + 2 * Metrics.spacing
        + (hasNotifications ? 0 : Metrics.spacing + emptyHeight)
    readonly property int surfaceHeight: headerCardHeight
        + (hasNotifications ? Metrics.popupRowSpacing + listHeight : 0)
    readonly property real surfaceX: {
        const position = anchorItem.mapToItem(barWindow.contentItem, 0, 0);
        return Math.round(Math.max(Metrics.statusBarHorizontalMargin,
            Math.min(position.x + anchorItem.width / 2 - surfaceWidth / 2,
                barWindow.width - Metrics.statusBarHorizontalMargin - surfaceWidth)));
    }

    signal dismissed()
    signal restartRequested()

    screen: barWindow.screen
    anchors { top: true; left: true }
    exclusionMode: ExclusionMode.Ignore
    focusable: false
    margins.left: surfaceX - horizontalRenderMargin
    margins.top: popupTop - topRenderMargin
    implicitWidth: surfaceWidth + 2 * horizontalRenderMargin
    implicitHeight: surfaceHeight + topRenderMargin + bottomRenderMargin
    color: Theme.transparentColor
    WlrLayershell.namespace: "aerix:notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: popupFrame }
    // Заголовок остаётся в основной surface, поэтому запрашивает blur здесь.
    // Карточки истории ниже получают независимые surface, как toast-уведомления.
    BackgroundEffect.blurRegion: Region {
        item: headerCard
        radius: Metrics.panelRadius
    }

    Behavior on reveal {
        NumberAnimation {
            duration: Metrics.spring.durationMs
            easing.type: Metrics.spring.easingType
            easing.bezierCurve: Metrics.spring.bezierCurve
            onRunningChanged: {
                if (!running && !popup.expanded && popup.reveal === 0)
                    popup.dismissed();
            }
        }
    }

    function dismiss() { expanded = false; }
    function toggle() {
        if (expanded) dismiss();
        else restartRequested();
    }

    Component.onCompleted: {
        syncHistory();
        expanded = true;
    }
    onExpandedChanged: {
        focusGrab.active = expanded;
        if (!expanded) {
            for (let i = 0; i < historyRepeater.count; ++i)
                historyRepeater.itemAt(i)?.stopEntry();
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        windows: [popup, popup.barWindow]
        onCleared: popup.dismiss()
    }

    PanelShadowWindow {
        targetScreen: popup.screen
        shadowSource: shadowSurface
        shadowNamespace: "aerix:notifications-shadow"
        shadowOpacity: popupFrame.opacity
        WlrLayershell.layer: WlrLayer.Overlay
        anchors { top: true; left: true }
        margins.left: popup.margins.left
        margins.top: popup.margins.top
        implicitWidth: popup.width
        implicitHeight: popup.height

        Rectangle {
            id: shadowSurface
            x: popupFrame.x
            y: popupFrame.y
            width: popupFrame.width
            height: popup.headerCardHeight
            radius: Metrics.panelRadius
            scale: popupFrame.scale
            transformOrigin: popupFrame.transformOrigin
            color: Theme.transparentColor
            antialiasing: true
        }
    }

    Rectangle {
        id: popupFrame
        x: popup.horizontalRenderMargin
        y: popup.topRenderMargin - popup.revealTravel * (1 - popup.reveal)
        width: popup.surfaceWidth
        height: popup.surfaceHeight
        radius: Metrics.panelRadius
        color: Theme.transparentColor
        border.width: 0
        border.color: Theme.borderColor
        antialiasing: true
        scale: Metrics.spring.startScale
            + (1 - Metrics.spring.startScale) * popup.reveal
        transformOrigin: Item.Top
        opacity: Math.max(0, Math.min(1, popup.reveal))

        Rectangle {
            id: headerCard
            width: parent.width
            height: popup.headerCardHeight
            radius: Metrics.panelRadius
            color: Theme.backgroundColor
            border.width: 1
            border.color: Theme.borderColor
        }

        Text {
            id: title
            x: Metrics.spacing
            y: Metrics.spacing
            width: parent.width - 2 * Metrics.spacing - clearButton.width
            height: popup.headerHeight
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
            height: popup.headerHeight
            visible: NotificationService.activeNotificationCount > 0
            text: I18n.tr("notifications.clearAll")
            color: Theme.foregroundColor
            font.pixelSize: 12
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationService.clearAll()
            }
        }

        Flickable {
            id: notificationList
            x: 0
            y: headerCard.height + Metrics.popupRowSpacing
            width: parent.width
            height: popup.hasNotifications ? popup.listHeight : 0
            visible: popup.hasNotifications
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            readonly property real cardStep: Math.max(24, Metrics.notificationCardHeight * 0.36)
            property int hoveredIndex: -1
            readonly property real expandedOffset: Metrics.notificationCardHeight
                + Metrics.popupRowSpacing - cardStep
            contentWidth: width
            contentHeight: Math.max(height, Metrics.notificationCardHeight
                + Math.max(0, historyCards.count - 1) * cardStep
                + (hoveredIndex >= 0 ? expandedOffset : 0))
            onContentHeightChanged: {
                contentY = Math.max(0, Math.min(contentY, contentHeight - height));
            }

            ScrollBar.vertical: ScrollBar {
                parent: notificationList.parent
                x: notificationList.x + notificationList.width + 2
                y: notificationList.y
                height: notificationList.height
                width: 4
                policy: ScrollBar.AsNeeded
            }

            Repeater {
                id: historyRepeater
                property int mappingRevision: 0
                onItemAdded: mappingRevision++
                onItemRemoved: mappingRevision++
                model: historyCards
                delegate: Item {
                    id: historySlot
                    required property int index
                    required property int notificationId
                    required property string appName
                    required property string desktopEntry
                    required property string summary
                    required property string body
                    required property bool isClosing
                    property real entryReveal: 0
                    property bool entryStarted: false
                    function stopEntry() { entryAnimation.stop(); }
                    // Layer-shell учитывает порядок появления окон, а не z
                    // QML-делегата. Загружаем поверхности строго сверху вниз
                    // и сохраняем до закрытия popup, чтобы scroll не менял стек.
                    property bool loadRequested: false
                    readonly property bool precedingMapped: {
                        const revision = historyRepeater.mappingRevision;
                        return index === 0
                            || (historyRepeater.itemAt(index - 1)?.entryReveal ?? 0) > 0;
                    }
                    readonly property bool withinLoadRange: y <= notificationList.contentY
                        + notificationList.height + height
                    function requestSurface() {
                        if (withinLoadRange && precedingMapped)
                            loadRequested = true;
                    }
                    onWithinLoadRangeChanged: requestSurface()
                    onPrecedingMappedChanged: requestSurface()
                    Component.onCompleted: requestSurface()
                    readonly property real entryScale: Metrics.spring.startScale
                        + (1 - Metrics.spring.startScale) * entryReveal
                    readonly property real surfaceScale: popupFrame.scale * entryScale
                    // Clip отдельной surface должен включать overshoot и тень:
                    // иначе карточка обрезается по бокам во время spring.
                    readonly property real horizontalClipMargin: popup.horizontalRenderMargin
                    readonly property real viewportX: popupFrame.x
                        + popupFrame.width * (1 - popupFrame.scale) / 2
                        + notificationList.x * popupFrame.scale - horizontalClipMargin
                    readonly property real viewportY: popupFrame.y
                        + notificationList.y * popupFrame.scale
                    readonly property real viewportWidth: notificationList.width * popupFrame.scale
                        + 2 * horizontalClipMargin
                    readonly property real viewportHeight: notificationList.height * popupFrame.scale
                    SequentialAnimation {
                        id: entryAnimation
                        PauseAnimation { id: entryDelay }
                        NumberAnimation {
                            target: historySlot
                            property: "entryReveal"
                            from: 0
                            to: 1
                            duration: Metrics.spring.durationMs
                            easing.type: Metrics.spring.easingType
                            easing.bezierCurve: Metrics.spring.bezierCurve
                        }
                    }
                    width: notificationList.width
                    height: Metrics.notificationCardHeight
                    y: index * notificationList.cardStep
                        + (notificationList.hoveredIndex >= 0
                            && index > notificationList.hoveredIndex
                            ? notificationList.expandedOffset : 0)
                    z: index
                    Behavior on y { Metrics.ProfileAnimation {} }
                    // Ввод остаётся в Flickable: отдельные Wayland-поверхности
                    // служат для отрисовки и не перехватывают hover/прокрутку.
                    MouseArea {
                        anchors.fill: parent
                        enabled: popup.expanded && popup.reveal >= 1
                            && historySlot.entryReveal >= 1 && !historySlot.isClosing
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: notificationList.hoveredIndex = historySlot.index
                        onExited: {
                            if (popup.expanded && notificationList.hoveredIndex === historySlot.index)
                                notificationList.hoveredIndex = -1;
                        }
                        onClicked: mouse => {
                            if (mouse.x >= width - Metrics.spacing - 16
                                && mouse.x <= width - Metrics.spacing
                                && mouse.y >= Metrics.spacing - 2
                                && mouse.y <= Metrics.spacing + 18)
                                NotificationService.dismiss({ id: historySlot.notificationId });
                        }
                        onWheel: wheel => {
                            const delta = wheel.pixelDelta.y || wheel.angleDelta.y / 2;
                            notificationList.contentY = Math.max(0, Math.min(
                                notificationList.contentHeight - notificationList.height,
                                notificationList.contentY - delta));
                            wheel.accepted = true;
                        }
                    }

                    // Как и у toast, один буфер на карточку даёт compositor-у
                    // точную область для blur, включая перекрывающуюся колоду.
                    // Окна создаются по мере приближения к viewport. Уже
                    // созданные освобождаются вместе с ленивым popup.
                    Loader {
                        asynchronous: true
                        active: historySlot.loadRequested
                        onLoaded: {
                            if (popup.expanded && !historySlot.entryStarted) {
                                historySlot.entryStarted = true;
                                // Загрузка уже ждёт появления предыдущей карточки.
                                // Повторное умножение на index накапливало задержку.
                                entryDelay.duration = historySlot.index === 0 ? 0
                                    : Metrics.notificationCloseCascadeDelayMs;
                                entryAnimation.start();
                            }
                        }
                        sourceComponent: Item {
                    PanelWindow {
                        screen: popup.screen
                        anchors { top: true; left: true }
                        margins.left: popup.margins.left
                        margins.top: popup.margins.top
                        implicitWidth: popup.width
                        implicitHeight: popup.height
                        exclusionMode: ExclusionMode.Ignore
                        color: Theme.transparentColor
                        focusable: false
                        visible: popup.reveal > 0 && historySlot.entryReveal > 0
                            && historySlot.visible
                        WlrLayershell.namespace: "aerix:notifications"
                        WlrLayershell.layer: WlrLayer.Overlay
                        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                        mask: Region { width: 0; height: 0 }
                        BackgroundEffect.blurRegion: Region {
                            x: historySlot.viewportX + Math.max(0, cardSurface.x)
                            y: historySlot.viewportY + Math.max(0, cardSurface.y)
                            width: Math.max(0, Math.min(historySlot.viewportWidth,
                                cardSurface.x + cardSurface.width * cardSurface.scale)
                                - Math.max(0, cardSurface.x))
                            height: Math.max(0, Math.min(historySlot.viewportHeight,
                                cardSurface.y + cardSurface.height * cardSurface.scale)
                                - Math.max(0, cardSurface.y))
                            radius: Metrics.panelRadius
                        }

                        // clip родительского Flickable не пересекает границу
                        // окна: повторяем его viewport в каждой surface.
                        Item {
                            x: historySlot.viewportX
                            y: historySlot.viewportY
                            width: historySlot.viewportWidth
                            height: historySlot.viewportHeight
                            clip: true
                        NotificationCard {
                            id: cardSurface
                            x: popupFrame.x + popupFrame.width * (1 - historySlot.surfaceScale) / 2
                                + notificationList.x * historySlot.surfaceScale
                                + width * historySlot.surfaceScale * (1 - closeScale) / 2
                                - historySlot.viewportX
                            y: popupFrame.y + (notificationList.y + historySlot.y
                                - notificationList.contentY) * historySlot.surfaceScale
                                + height * historySlot.surfaceScale * (1 - closeScale) / 2
                                - historySlot.viewportY
                            width: historySlot.width
                            height: historySlot.height
                            readonly property real closeScale: Metrics.spring.startScale
                                + (1 - Metrics.spring.startScale) * closeReveal
                            scale: historySlot.surfaceScale * closeScale
                            transformOrigin: Item.TopLeft
                            opacity: popupFrame.opacity * Math.max(0, closeReveal)
                                * Math.max(0, Math.min(1, historySlot.entryReveal))
                            notification: ({ id: historySlot.notificationId,
                                appName: historySlot.appName,
                                desktopEntry: historySlot.desktopEntry,
                                summary: historySlot.summary,
                                body: historySlot.body,
                                closing: historySlot.isClosing })

                        }
                        }
                    }

                    PanelWindow {
                        screen: popup.screen
                        color: Theme.transparentColor
                        exclusionMode: ExclusionMode.Ignore
                        focusable: false
                        mask: Region { width: 0; height: 0 }
                        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                        WlrLayershell.namespace: "aerix:notifications-shadow"
                        visible: popup.reveal > 0 && historySlot.entryReveal > 0
                            && historySlot.visible
                        WlrLayershell.layer: WlrLayer.Overlay
                        anchors { top: true; left: true }
                        margins.left: popup.margins.left
                        margins.top: popup.margins.top
                        implicitWidth: popup.width
                        implicitHeight: popup.height

                        Item {
                            x: historySlot.viewportX
                            y: historySlot.viewportY
                            width: historySlot.viewportWidth
                            height: historySlot.viewportHeight
                            clip: true
                            opacity: cardSurface.opacity
                            PanelShadow { sourceItem: cardShadow }
                        Rectangle {
                            id: cardShadow
                            x: cardSurface.x
                            y: cardSurface.y
                            width: historySlot.width
                            height: historySlot.height
                            radius: Metrics.panelRadius
                            scale: cardSurface.scale
                            transformOrigin: Item.TopLeft
                            color: Theme.transparentColor
                        }
                        }
                    }
                        }
                    }
                }
            }
        }

        Text {
            anchors.left: headerCard.left
            anchors.right: headerCard.right
            anchors.leftMargin: Metrics.spacing
            anchors.rightMargin: Metrics.spacing
            anchors.top: title.bottom
            anchors.topMargin: Metrics.spacing
            height: popup.emptyHeight
            visible: !popup.hasNotifications
            text: I18n.tr("notifications.empty")
            color: Theme.foregroundColor
            font.pixelSize: Metrics.statusBarFontSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}

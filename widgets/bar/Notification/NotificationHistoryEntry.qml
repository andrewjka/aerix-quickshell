pragma ComponentBehavior: Bound

import QtQuick
import "../../shared" as Shared
import "../../../core"
import "../../../services"

// Лёгкий слот колоды: ввод живёт в Flickable, отрисовка — в ленивой CardLayer.
// Поверхности сохраняются до закрытия popup, чтобы прокрутка не меняла их стек.
Item {
    id: slot
    required property int index
    required property int notificationId
    required property string appName
    required property string desktopEntry
    required property string summary
    required property string body
    required property bool closing
    required property Shared.BarPopup popup
    required property Flickable list
    required property bool precedingMapped
    required property bool displaced
    property real entryReveal: 0
    property real closeReveal: closing ? 0 : 1
    property bool loadRequested: false
    readonly property bool withinLoadRange: y <= list.contentY + list.height + height
    readonly property real entryScale: Metrics.spring.startScale
        + (1 - Metrics.spring.startScale) * entryReveal
    readonly property real surfaceScale: popup.frame.scale * entryScale
    readonly property real closeScale: Metrics.spring.startScale
        + (1 - Metrics.spring.startScale) * closeReveal

    signal hovered(bool inside)
    width: list.width
    height: Metrics.notificationCardHeight
    z: index
    Behavior on y { Metrics.ProfileAnimation {} }
    Behavior on closeReveal { Shared.SpringAnimation {} }

    function requestSurface() {
        if (popup.expanded && withinLoadRange && precedingMapped)
            loadRequested = true;
    }
    onWithinLoadRangeChanged: requestSurface()
    onPrecedingMappedChanged: requestSurface()
    Component.onCompleted: requestSurface()
    Connections {
        target: slot.popup
        function onExpandedChanged() {
            if (slot.popup.expanded) slot.requestSurface();
            else entryAnimation.stop();
        }
    }
    SequentialAnimation {
        id: entryAnimation
        // Предыдущая карточка уже появилась: задержка постоянная, не index * delay.
        PauseAnimation {
            duration: slot.index === 0 ? 0 : Metrics.notificationCloseCascadeDelayMs
        }
        Shared.SpringAnimation {
            target: slot
            property: "entryReveal"
            from: 0
            to: 1
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: slot.popup.expanded && slot.popup.reveal >= 1
            && slot.entryReveal >= 1 && !slot.closing
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: slot.hovered(true)
        onExited: slot.hovered(false)
        onClicked: mouse => {
            if (mouse.x >= width - Metrics.spacing - 16 && mouse.x <= width - Metrics.spacing
                && mouse.y >= Metrics.spacing - 2 && mouse.y <= Metrics.spacing + 18)
                NotificationService.dismiss({ id: slot.notificationId });
        }
        onWheel: wheel => {
            const delta = wheel.pixelDelta.y || wheel.angleDelta.y / 2;
            slot.list.contentY = Math.max(0, Math.min(
                slot.list.contentHeight - slot.list.height, slot.list.contentY - delta));
            wheel.accepted = true;
        }
    }

    Loader {
        asynchronous: true
        active: slot.loadRequested
        onLoaded: {
            if (slot.popup.expanded) entryAnimation.start();
        }
        sourceComponent: Shared.CardLayer {
            // Три spring-масштаба перемножаются; окно и тень получают общий
            // запас, ограниченный физическими границами экрана.
            readonly property int animationMargin: Math.ceil(
                Math.max(slot.width, slot.popup.surfaceHeight)
                * Math.max(0, Math.pow(Metrics.spring.maximumScale, 3) - 1))
                + slot.popup.layout.shadowMargin
            readonly property rect baseWindow: slot.popup.layout.windowRect
            readonly property real windowLeft: Math.max(0, baseWindow.x - animationMargin)
            readonly property real windowTop: Math.max(0, baseWindow.y - animationMargin)
            readonly property real offsetX: baseWindow.x - windowLeft
            readonly property real offsetY: baseWindow.y - windowTop
            readonly property bool animating: entryAnimation.running
                || slot.popup.reveal !== 1 || slot.closing
            readonly property bool inViewport: slot.y + slot.height > slot.list.contentY
                && slot.y < slot.list.contentY + slot.list.height
            readonly property real revealPadding: animating && inViewport ? animationMargin : 0
            targetScreen: slot.popup.screen
            layerNamespace: "aerix:notifications"
            shadowNamespace: "aerix:notifications-shadow"
            windowRect: Qt.rect(windowLeft, windowTop,
                Math.min(slot.popup.screen.width, baseWindow.x + baseWindow.width
                    + animationMargin) - windowLeft,
                Math.min(slot.popup.screen.height, baseWindow.y + baseWindow.height
                    + animationMargin) - windowTop)
            interactive: false
            shown: slot.popup.reveal > 0 && slot.entryReveal > 0 && slot.visible
            // Во время spring расширяется viewport видимых слотов; после
            // появления список снова обрезает прокрученные карточки.
            viewport: Qt.rect(
                offsetX + slot.popup.frame.x + slot.popup.frame.width * (1 - slot.popup.frame.scale) / 2
                    + slot.list.x * slot.popup.frame.scale - animationMargin,
                offsetY + slot.popup.frame.y + slot.list.y * slot.popup.frame.scale - revealPadding,
                slot.list.width * slot.popup.frame.scale + 2 * animationMargin,
                slot.list.height * slot.popup.frame.scale + 2 * revealPadding)
            cardRect: Qt.rect(
                offsetX + slot.popup.frame.x + slot.popup.frame.width * (1 - slot.surfaceScale) / 2
                    + slot.list.x * slot.surfaceScale
                    + slot.width * slot.surfaceScale * (1 - slot.closeScale) / 2,
                offsetY + slot.popup.frame.y + (slot.list.y + slot.y - slot.list.contentY) * slot.surfaceScale
                    + slot.height * slot.surfaceScale * (1 - slot.closeScale) / 2,
                slot.width, slot.height)
            cardScale: slot.surfaceScale * slot.closeScale
            cardOpacity: slot.popup.frame.opacity * Math.max(0, slot.closeReveal)
                * Math.max(0, Math.min(1, slot.entryReveal))
            content: NotificationCard {
                notification: ({ id: slot.notificationId, appName: slot.appName,
                    desktopEntry: slot.desktopEntry, summary: slot.summary, body: slot.body })
            }
        }
    }
}

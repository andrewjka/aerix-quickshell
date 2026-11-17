pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import "../core"

// История хранит копии текста: закрытие D-Bus объекта приложением не удаляет
// карточку. Только явное удаление пользователем очищает запись.
QtObject {
    id: service
    property var notifications: []
    readonly property int notificationCount: notifications.length
    readonly property int activeNotificationCount: notifications.filter(entry =>
        !entry.closing).length
    property var toastEntries: []
    property var closeQueue: []

    function focusedScreen() {
        return Quickshell.screens.find(screen =>
            Hyprland.monitorFor(screen)?.name === Hyprland.focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null;
    }

    function snapshot(notification) {
        return { id: notification.id, appName: notification.appName,
            desktopEntry: notification.desktopEntry, summary: notification.summary,
            body: notification.body, closing: false };
    }

    function closingSnapshot(notification) {
        return { id: notification.id, appName: notification.appName,
            desktopEntry: notification.desktopEntry, summary: notification.summary,
            body: notification.body, closing: true };
    }

    function remember(notification) {
        const entry = snapshot(notification);
        notifications = notifications.filter(item => item.id !== entry.id).concat([entry]);
        return entry;
    }

    function markClosing(id, removeNotification) {
        if (removeNotification) {
            notifications = notifications.map(entry => entry.id === id
                ? closingSnapshot(entry) : entry);
        }
        toastEntries = toastEntries.map(entry => entry.notification.id === id
            ? ({ notification: closingSnapshot(entry.notification), screen: entry.screen,
                expiresAt: entry.expiresAt })
            : entry);
    }

    function scheduleClose(notification, removeNotification, delay) {
        if (!notification) return;
        const id = notification.id;
        let queued = closeQueue.find(entry => entry.id === id);
        if (queued) {
            if (removeNotification && !queued.removeNotification) {
                queued.removeNotification = true;
                // История начинает собственное закрытие, даже если toast
                // уже исчезает по таймауту. Даём ей полную длительность.
                queued.started = false;
                queued.startAt = Date.now() + delay;
                queued.removeAt = queued.startAt + Metrics.spring.durationMs;
                processCloseQueue();
            }
            return;
        }

        const startAt = Date.now() + delay;
        closeQueue = closeQueue.concat([{
            id: id, startAt: startAt,
            removeAt: startAt + Metrics.spring.durationMs,
            removeNotification: removeNotification, started: false
        }]);
        processCloseQueue();
    }

    function dismiss(notification) {
        if (!notification || closeQueue.some(entry => entry.id === notification.id
            && entry.removeNotification)) return;
        scheduleClose(notification, true, 0);
        const live = server.trackedNotifications.values.find(entry =>
            entry.id === notification.id);
        if (live) live.dismiss();
    }

    function clearAll() {
        const entries = notifications.filter(entry => !entry.closing
            && !closeQueue.some(queued => queued.id === entry.id && queued.removeNotification));
        const delayStep = Metrics.notificationCloseCascadeDelayMs;
        for (let index = 0; index < entries.length; ++index) {
            const entry = entries[index];
            scheduleClose(entry, true, (entries.length - 1 - index) * delayStep);
            const live = server.trackedNotifications.values.find(item => item.id === entry.id);
            if (live) live.dismiss();
        }
    }

    function processCloseQueue() {
        const now = Date.now();
        const removedIds = [];
        for (const entry of closeQueue) {
            if (!entry.started && now >= entry.startAt) {
                entry.started = true;
                markClosing(entry.id, entry.removeNotification);
            }
            if (entry.started && now >= entry.removeAt)
                removedIds.push(entry.id);
        }
        if (removedIds.length) {
            const removed = new Set(removedIds);
            const removeNotifications = new Set(closeQueue.filter(entry =>
                removed.has(entry.id) && entry.removeNotification).map(entry => entry.id));
            notifications = notifications.filter(entry => !removeNotifications.has(entry.id));
            toastEntries = toastEntries.filter(entry => !removed.has(entry.notification.id));
            closeQueue = closeQueue.filter(entry => !removed.has(entry.id));
        }
        if (closeQueue.length) {
            const next = Math.min(...closeQueue.map(entry => entry.started
                ? entry.removeAt : entry.startAt));
            closeTimer.interval = Math.max(1, next - Date.now());
            closeTimer.restart();
        }
    }

    function showToast(notification) {
        toastEntries = toastEntries.concat([{ notification: notification,
            screen: focusedScreen(), expiresAt: Date.now() + Metrics.notificationTimeoutMs }]);
    }

    function clearToastsForScreen(screen) {
        toastEntries = toastEntries.filter(entry => entry.screen !== screen);
    }

    function toastsForScreen(screen) {
        return toastEntries.filter(entry => entry.screen === screen);
    }

    // Один одноразовый таймер до ближайшего срока. Новое сообщение не
    // продлевает сроки старых; в простое таймер остановлен.
    onToastEntriesChanged: {
        expiry.stop();
        const activeEntries = toastEntries.filter(entry => !entry.notification.closing);
        if (activeEntries.length) {
            expiry.interval = Math.max(1,
                Math.min(...activeEntries.map(entry => entry.expiresAt)) - Date.now());
            expiry.start();
        }
    }
    property Timer expiry: Timer {
        onTriggered: {
            const now = Date.now();
            for (const entry of service.toastEntries)
                if (entry.expiresAt <= now)
                    service.scheduleClose(entry.notification, false, 0);
        }
    }

    property Timer closeTimer: Timer {
        onTriggered: service.processCloseQueue()
    }

    property NotificationServer server: NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodyMarkupSupported: false
        onNotification: notification => {
            notification.tracked = true;
            const entry = service.remember(notification);
            if (!notification.lastGeneration)
                service.showToast(entry);
        }
    }
}

import QtQuick

// Стабильные роли сохраняют экземпляры карточек и незавершённые анимации.
// Одна синхронизация для истории и toast; обновление текста не пересоздаёт окно.
ListModel {
    id: model
    property var entries: []
    onEntriesChanged: sync()
    Component.onCompleted: sync()

    function sync() {
        const ids = new Set(entries.map(entry => entry.id));
        for (let i = count - 1; i >= 0; --i)
            if (!ids.has(get(i).notificationId)) remove(i);
        const positions = new Map();
        for (let i = 0; i < count; ++i)
            positions.set(get(i).notificationId, i);
        for (const entry of entries) {
            const row = { notificationId: entry.id, appName: entry.appName || "",
                desktopEntry: entry.desktopEntry || "", summary: entry.summary || "",
                body: entry.body || "", closing: entry.closing === true };
            const index = positions.get(entry.id);
            if (index === undefined) append(row);
            else set(index, row);
        }
    }
}

pragma Singleton

import QtQml
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Состояние launcher и пользовательская раскладка отделены от visual surface:
// AppLauncher уничтожается LazyLoader-ом при закрытии, а сервис остаётся жить.
QtObject {
    id: service

    property bool open: false
    property var targetScreen: null
    property var layoutItems: []
    property var entriesById: ({})
    property bool layoutLoaded: false
    property int folderSequence: 0
    property bool layoutMigrationPending: false

    // Создаёт сериализуемую ссылку на реальное приложение.
    function applicationItem(entry, key) {
        return {
            type: "application",
            key: key,
            appId: String(entry.id)
        };
    }

    function hasLegacyTestItems(items) {
        for (const item of items) {
            if (item?.type === "application" && typeof item.key === "string"
                && item.key.startsWith("test:"))
                return true;
            if (item?.type === "folder" && Array.isArray(item.children)) {
                if (hasLegacyTestItems(item.children))
                    return true;
            }
        }
        return false;
    }

    function launcherEntries(entries) {
        return entries.filter(entry => !entry.noDisplay && !entry.runInTerminal);
    }

    function initialItems(entries) {
        return entries.map(entry => applicationItem(entry,
            "application:" + String(entry.id)));
    }

    function indexEntries(entries) {
        const index = {};
        for (const entry of entries)
            index[String(entry.id)] = entry;
        return index;
    }

    function cloneApplication(item, available, keys) {
        if (!item || item.type !== "application"
            || typeof item.key !== "string" || item.key.startsWith("test:")
            || typeof item.appId !== "string"
            || !available[item.appId] || keys[item.key])
            return null;
        keys[item.key] = true;
        return {
            type: "application",
            key: item.key,
            appId: item.appId
        };
    }

    function reconcileItems(items, available, defaults) {
        const keys = {};
        const folderIds = {};
        const reconciled = [];
        for (const item of items) {
            if (item?.type === "application") {
                const application = cloneApplication(item, available, keys);
                if (application)
                    reconciled.push(application);
                continue;
            }
            if (item?.type !== "folder" || typeof item.id !== "string"
                || typeof item.name !== "string" || !Array.isArray(item.children)
                || folderIds[item.id])
                continue;
            const children = [];
            for (const child of item.children) {
                const application = cloneApplication(child, available, keys);
                if (application)
                    children.push(application);
            }
            if (children.length > 0) {
                folderIds[item.id] = true;
                reconciled.push({
                    type: "folder",
                    id: item.id,
                    name: item.name,
                    children: children
                });
            }
        }

        // Новые .desktop дополняют сетку, но не меняют выбранную пользователем
        // последовательность существующих элементов.
        for (const item of defaults) {
            if (!keys[item.key]) {
                keys[item.key] = true;
                reconciled.push(item);
            }
        }
        return reconciled;
    }

    function syncApplications() {
        const desktopEntries = DesktopEntries.applications.values;
        // Во время запуска FileView может загрузиться раньше DesktopEntries.
        // Не очищаем пользовательскую раскладку временно пустым индексом.
        if (desktopEntries.length === 0)
            return;
        const entries = launcherEntries(desktopEntries);
        const available = indexEntries(entries);
        const defaults = initialItems(entries);
        entriesById = available;
        layoutItems = reconcileItems(layoutItems, available, defaults);
        if (layoutMigrationPending) {
            layoutMigrationPending = false;
            saveLayout();
        }
    }

    function loadLayout(text) {
        try {
            const document = JSON.parse(text);
            if (document.version !== 1 || !Array.isArray(document.items))
                throw new Error("expected version 1 with an items array");
            layoutItems = document.items;
            layoutMigrationPending = hasLegacyTestItems(layoutItems);
        } catch (error) {
            console.warn("App launcher layout: " + error.message);
            layoutItems = [];
        }
        layoutLoaded = true;
        syncApplications();
    }

    function saveLayout() {
        if (!layoutLoaded)
            return;
        layoutFile.setText(JSON.stringify({
            version: 1,
            items: layoutItems
        }, null, 2) + "\n");
    }

    function presentationItems(folderId) {
        const source = folderId ? layoutItems.find(item =>
            item.type === "folder" && item.id === folderId)?.children ?? []
            : layoutItems;
        return source.map(item => {
            if (item.type === "folder") {
                // Preview is resolved here together with the folder model. This
                // keeps image bindings local to the GridView model and avoids a
                // second lookup through a transient delegate object.
                const previewEntries = item.children.slice(0, 4).map(child =>
                    entriesById[child.appId]).filter(entry => entry);
                return {
                    type: "folder",
                    key: item.id,
                    name: item.name,
                    icon: "folder",
                    folderId: item.id,
                    children: item.children,
                    previewEntries: previewEntries
                };
            }
            return {
                type: "application",
                key: item.key,
                entry: entriesById[item.appId]
            };
        }).filter(item => item.type === "folder" || item.entry);
    }

    // insertionIndex — позиция между элементами в исходной модели, а не индекс
    // плитки-цели. Это сохраняет порядок при drop справа от существующей иконки.
    function moveRootItem(itemKey, insertionIndex) {
        const sourceIndex = layoutItems.findIndex(item =>
            (item.type === "folder" ? item.id : item.key) === itemKey);
        if (sourceIndex < 0 || insertionIndex < 0)
            return;
        const items = layoutItems.slice();
        const source = items.splice(sourceIndex, 1)[0];
        const adjustedIndex = Math.max(0, Math.min(items.length,
            insertionIndex - (sourceIndex < insertionIndex ? 1 : 0)));
        items.splice(adjustedIndex, 0, source);
        layoutItems = items;
        saveLayout();
    }

    function createFolder(firstKey, secondKey) {
        const firstIndex = layoutItems.findIndex(item => item.type === "application"
            && item.key === firstKey);
        const secondIndex = layoutItems.findIndex(item => item.type === "application"
            && item.key === secondKey);
        if (firstIndex < 0 || secondIndex < 0 || firstIndex === secondIndex)
            return;
        const items = layoutItems.slice();
        const first = items[firstIndex];
        const second = items[secondIndex];
        const insertionIndex = Math.min(firstIndex, secondIndex);
        // Удаляем с конца, чтобы первый индекс не сдвинулся.
        items.splice(Math.max(firstIndex, secondIndex), 1);
        items.splice(Math.min(firstIndex, secondIndex), 1);
        const folderId = "folder:" + Date.now() + ":" + folderSequence++;
        items.splice(insertionIndex, 0, {
            type: "folder",
            id: folderId,
            name: "Folder",
            children: [first, second]
        });
        layoutItems = items;
        saveLayout();
    }

    function folderName(folderId) {
        return String(layoutItems.find(item => item.type === "folder"
            && item.id === folderId)?.name ?? "");
    }

    function renameFolder(folderId, name) {
        const index = layoutItems.findIndex(item => item.type === "folder"
            && item.id === folderId);
        const nextName = String(name).trim();
        if (index < 0 || nextName.length === 0 || layoutItems[index].name === nextName)
            return;
        const items = layoutItems.slice();
        const folder = items[index];
        items[index] = {
            type: "folder",
            id: folder.id,
            name: nextName,
            children: folder.children
        };
        layoutItems = items;
        saveLayout();
    }

    // Перестановка внутри папки и вынос приложения обратно в корневую сетку.
    function moveFolderItem(folderId, itemKey, insertionIndex, toRoot) {
        const folderIndex = layoutItems.findIndex(item => item.id === folderId);
        if (folderIndex < 0)
            return;
        const folder = layoutItems[folderIndex];
        const children = folder.children.slice();
        const sourceIndex = children.findIndex(item => item.key === itemKey);
        if (sourceIndex < 0)
            return;
        const item = children.splice(sourceIndex, 1)[0];
        const items = layoutItems.slice();
        if (!toRoot) {
            const destination = insertionIndex - (sourceIndex < insertionIndex ? 1 : 0);
            children.splice(Math.max(0, Math.min(children.length, destination)), 0, item);
        }
        items[folderIndex] = { type: "folder", id: folder.id,
            name: folder.name, children: children };
        if (toRoot) {
            if (children.length === 0) {
                items.splice(folderIndex, 1);
                if (folderIndex < insertionIndex)
                    insertionIndex--;
            }
            items.splice(Math.max(0, Math.min(items.length, insertionIndex)), 0, item);
        }
        layoutItems = items;
        saveLayout();
    }

    function addToFolder(itemKey, folderId) {
        const sourceIndex = layoutItems.findIndex(item => item.type === "application"
            && item.key === itemKey);
        const folderIndex = layoutItems.findIndex(item => item.type === "folder"
            && item.id === folderId);
        if (sourceIndex < 0 || folderIndex < 0)
            return;
        const items = layoutItems.slice();
        const source = items.splice(sourceIndex, 1)[0];
        const adjustedFolderIndex = folderIndex - (sourceIndex < folderIndex ? 1 : 0);
        const folder = items[adjustedFolderIndex];
        items[adjustedFolderIndex] = {
            type: "folder",
            id: folder.id,
            name: folder.name,
            children: folder.children.concat([source])
        };
        layoutItems = items;
        saveLayout();
    }

    property FileView layoutFile: FileView {
        path: Quickshell.statePath("app-launcher-layout.json")
        preload: true
        printErrors: false
        // FileView пишет атомарно: незавершённая запись не испортит раскладку.
        onLoaded: service.loadLayout(text())
        onLoadFailed: {
            service.layoutLoaded = true;
            service.syncApplications();
        }
        onSaveFailed: error => console.warn("App launcher layout: "
            + error.toString())
    }

    property Connections applicationEntries: Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            if (service.layoutLoaded)
                service.syncApplications();
        }
    }

    function openOnFocusedScreen() {
        const focusedMonitor = Hyprland.focusedMonitor;
        targetScreen = Quickshell.screens.find(screen =>
            Hyprland.monitorFor(screen)?.name === focusedMonitor?.name)
            ?? Quickshell.screens[0] ?? null;
        open = targetScreen !== null;
    }

    function toggle() {
        if (open)
            close();
        else
            openOnFocusedScreen();
    }

    function close() {
        open = false;
    }
}

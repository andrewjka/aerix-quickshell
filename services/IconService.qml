pragma Singleton

import QtQml
import QtQuick
import Quickshell

Item {
    id: service

    // Иконки разрешаются редко, поэтому сохраняем результат до изменения
    // desktop entries. Это исключает повторный поиск темы для каждого binding.
    property var pathCache: ({})

    // DesktopEntries watches application directories and emits this signal
    // when installed or removed desktop entries change.
    property int revision: 0
    readonly property int maxCacheEntries: 256

    property var desktopEntriesConnection: Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            service.revision += 1;
            service.pathCache = ({});
        }
    }

    // Единая цепочка поиска: desktop entry, затем имя приложения в icon theme.
    // Возвращается URL или пустая строка для fallback-буквы в DockIcon.
    function resolve(tl) {
        const ipc = tl?.lastIpcObject;
        const names = [
            String(tl?.wayland?.appId ?? ""),
            String(ipc?.class ?? ""),
            String(ipc?.initialClass ?? "")
        ];
        const cacheKey = names.join("\u001f");
        if (Object.prototype.hasOwnProperty.call(service.pathCache, cacheKey))
            return service.pathCache[cacheKey];

        let resolved = "";

        for (const name of names) {
            if (!name)
                continue;

            const entry = DesktopEntries.byId(name) ?? DesktopEntries.heuristicLookup(name);
            const iconName = String(entry?.icon ?? "");
            if (!iconName)
                continue;
            if (iconName.startsWith("/")) {
                resolved = "file://" + iconName;
                break;
            }

            const path = Quickshell.iconPath(iconName, true);
            if (path) {
                resolved = path;
                break;
            }
        }

        if (!resolved) {
            for (const name of names) {
                if (!name)
                    continue;

                const path = Quickshell.iconPath(name, true);
                if (path) {
                    resolved = path;
                    break;
                }
            }
        }

        // Ограничение защищает singleton от роста при большом количестве
        // временных app-id/class, которые могут появляться в течение сессии.
        if (Object.keys(service.pathCache).length >= service.maxCacheEntries)
            service.pathCache = ({});
        service.pathCache[cacheKey] = resolved;
        return resolved;
    }
}

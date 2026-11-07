pragma Singleton

import QtQml
import Quickshell

QtObject {
    id: service

    // Map даёт поиск и проверку лимита без обхода всех записей кэша.
    property var iconCache: new Map()
    readonly property int maxCacheEntries: 256
    readonly property string fallbackIconName: "application-x-executable"

    property Connections desktopEntriesConnection: Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            // Новая ссылка обновляет bindings; очистка по лимиту ниже меняет
            // содержимое Map без повторного вычисления уже показанных иконок.
            service.iconCache = new Map();
        }
    }

    /** Разрешает абсолютный путь или имя иконки из текущей темы. */
    function iconSource(iconName) {
        if (!iconName)
            return "";
        return iconName.startsWith("/")
            ? "file://" + iconName
            : Quickshell.iconPath(iconName, true);
    }

    /** Ищет иконку по desktop entry, затем app-id/class и общему fallback. */
    function resolveIcon(toplevel) {
        const ipc = toplevel?.lastIpcObject;
        const names = [...new Set([
            String(toplevel?.wayland?.appId ?? ""),
            String(ipc?.class ?? ""),
            String(ipc?.initialClass ?? "")
        ].filter(name => name !== ""))];
        const cacheKey = JSON.stringify(names);
        if (service.iconCache.has(cacheKey))
            return service.iconCache.get(cacheKey);

        let source = "";
        for (const name of names) {
            const entry = DesktopEntries.byId(name) ?? DesktopEntries.heuristicLookup(name);
            source = iconSource(String(entry?.icon ?? ""));
            if (source)
                break;
        }

        if (!source) {
            for (const name of names) {
                source = Quickshell.iconPath(name, true);
                if (source)
                    break;
            }
        }

        if (!source)
            source = iconSource(service.fallbackIconName);

        // Временные app-id не должны бесконечно удерживаться singleton-сервисом.
        if (service.iconCache.size >= service.maxCacheEntries)
            service.iconCache.clear();
        service.iconCache.set(cacheKey, source);
        return source;
    }
}

pragma Singleton

import QtQml
import QtQuick
import Quickshell

Item {
    id: service

    // DesktopEntries watches application directories and emits this signal
    // when installed or removed desktop entries change.
    property int revision: 0

    property var desktopEntriesConnection: Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            service.revision += 1;
        }
    }

    function resolve(tl) {
        const ipc = tl?.lastIpcObject;
        const names = [
            String(tl?.wayland?.appId ?? ""),
            String(ipc?.class ?? ""),
            String(ipc?.initialClass ?? "")
        ];

        for (const name of names) {
            if (!name)
                continue;

            const entry = DesktopEntries.byId(name) ?? DesktopEntries.heuristicLookup(name);
            const iconName = String(entry?.icon ?? "");
            if (!iconName)
                continue;
            if (iconName.startsWith("/"))
                return "file://" + iconName;

            const path = Quickshell.iconPath(iconName, true);
            if (path)
                return path;
        }

        for (const name of names) {
            if (!name)
                continue;

            const path = Quickshell.iconPath(name, true);
            if (path)
                return path;
        }

        return "";
    }
}

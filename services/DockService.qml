pragma Singleton

import QtQml
import Quickshell
import Quickshell.Hyprland

/**
 * Единственный источник данных и команд для Dock.
 *
 * Сервис хранит один снимок списка Hyprland toplevel'ов. Визуальные окна
 * дока используют его, вместо того чтобы каждая панель отдельно запрашивала
 * ObjectModel и повторно создавала промежуточные массивы.
 */
QtObject {
    id: service

    // Ссылка на текущий snapshot обновляется самим ObjectModel при IPC-событии.
    // Массив удерживает только ссылки на живые HyprlandToplevel-объекты.
    readonly property var toplevelSnapshot: Hyprland.toplevels.values

    /** Возвращает окна, сгруппированные по workspace и отфильтрованные по монитору. */
    function groupsForScreen(screenName) {
        const result = [];

        for (const toplevel of service.toplevelSnapshot) {
            const monitor = toplevel.monitor ?? toplevel.workspace?.monitor;
            if (!toplevel.address || (monitor && monitor.name !== screenName))
                continue;

            const workspace = toplevel.workspace;
            const key = String(workspace?.name ?? workspace?.id ?? "other");
            let group = result.find(candidate => candidate.key === key);

            if (!group) {
                group = {
                    key: key,
                    id: workspace?.id ?? 0,
                    monitor: monitor,
                    windows: []
                };
                result.push(group);
            }

            group.windows.push(toplevel);
        }

        result.sort((left, right) => left.id - right.id);
        return result;
    }

    /** Находит окно по адресу среди уже подготовленных групп. */
    function findByAddress(groups, address) {
        if (!address)
            return null;

        for (const group of groups) {
            const toplevel = group.windows.find(item => String(item?.address ?? "") === address);
            if (toplevel)
                return toplevel;
        }

        return null;
    }

    /** Активирует окно через нативный Wayland handle или Hyprland IPC. */
    function focusWindow(toplevel) {
        if (toplevel?.wayland) {
            toplevel.wayland.activate();
            return;
        }

        const address = String(toplevel?.address ?? "").replace(/^0x/, "");
        if (!/^[0-9a-fA-F]+$/.test(address))
            return;

        const selector = "address:0x" + address;
        const command = Hyprland.usingLua
            ? `hl.dsp.focus({ window = "${selector}" })`
            : `focuswindow ${selector}`;
        Hyprland.dispatch(command);
    }

    /** Переключает на соседний существующий workspace текущего монитора. */
    function stepWorkspace(screenName, direction) {
        const monitor = Hyprland.monitors.values.find(item => item?.name === screenName);
        const activeWorkspace = monitor?.activeWorkspace;
        if (!activeWorkspace)
            return false;

        const workspaces = Hyprland.workspaces.values
            .filter(item => item?.monitor?.name === screenName)
            .sort((left, right) => left.id - right.id);
        const activeIndex = workspaces.findIndex(item => item.id === activeWorkspace.id);
        if (activeIndex < 0)
            return false;

        const nextIndex = activeIndex + (direction < 0 ? -1 : 1);
        if (nextIndex < 0 || nextIndex >= workspaces.length)
            return false;

        const workspaceId = String(workspaces[nextIndex].id);
        const command = Hyprland.usingLua
            ? `hl.dsp.focus({ workspace = "${workspaceId}" })`
            : "workspace " + workspaceId;
        Hyprland.dispatch(command);
        return true;
    }
}

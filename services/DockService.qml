pragma Singleton

import QtQml
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
    readonly property var toplevels: Hyprland.toplevels.values

    /** Возвращает окна, сгруппированные по workspace и отфильтрованные по монитору. */
    function groupsForScreen(screenName) {
        const groupsByWorkspace = new Map();

        for (const toplevel of service.toplevels) {
            const monitor = toplevel.monitor ?? toplevel.workspace?.monitor;
            if (!toplevel.address || (monitor && monitor.name !== screenName))
                continue;

            const workspace = toplevel.workspace;
            const key = String(workspace?.name ?? workspace?.id ?? "other");
            let group = groupsByWorkspace.get(key);

            if (!group) {
                group = {
                    key: key,
                    // Живая ссылка нужна DockLayout для сравнения identity:
                    // совпадение key не доказывает, что системный workspace
                    // не был заменён новым QObject.
                    workspace: workspace,
                    workspaceId: workspace?.id ?? 0,
                    windows: []
                };
                groupsByWorkspace.set(key, group);
            }

            group.windows.push(toplevel);
        }

        return Array.from(groupsByWorkspace.values())
            .sort((left, right) => left.workspaceId - right.workspaceId);
    }

    /** Монитор определяется независимо от наличия окон в его workspace. */
    function monitorForScreen(screenName) {
        return Hyprland.monitors.values.find(monitor => monitor.name === screenName) ?? null;
    }

    // Quickshell не экспортирует workspace.type отдельным typed-свойством, но
    // сохраняет исходный Hyprland snapshot. Wheel принадлежит обычному ряду
    // рабочих пространств: special workspace является отдельным overlay и не
    // должен стать «соседом» при прокрутке Dock.
    function isNormalWorkspaceOnScreen(workspace, screenName) {
        return workspace?.monitor?.name === screenName
            && workspace?.lastIpcObject?.type === "normal";
    }

    function normalWorkspacesForScreen(screenName) {
        return Hyprland.workspaces.values
            .filter(workspace => isNormalWorkspaceOnScreen(workspace, screenName))
            .sort((left, right) => left.id - right.id);
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

    /**
     * Переключает на одну итоговую цель normal-workspace ряда.
     *
     * Возвращает `atBoundary` только когда полный подтверждённый snapshot
     * показывает реальный край. Отсутствие монитора или неполная модель не
     * выдаёт ложный nudge.
     */
    function switchWorkspace(screenName, offset) {
        const requestedOffset = Math.trunc(offset);
        if (requestedOffset === 0)
            return { dispatched: false, atBoundary: false };

        const activeWorkspace = monitorForScreen(screenName)?.activeWorkspace;
        if (!activeWorkspace)
            return { dispatched: false, atBoundary: false };

        const workspaces = normalWorkspacesForScreen(screenName);
        const activeIndex = workspaces.findIndex(item => item.id === activeWorkspace.id);
        if (activeIndex < 0)
            return { dispatched: false, atBoundary: false };

        const targetIndex = Math.max(0, Math.min(workspaces.length - 1,
            activeIndex + requestedOffset));
        if (targetIndex === activeIndex)
            return { dispatched: false, atBoundary: true,
                boundaryDirection: Math.sign(requestedOffset) };

        const workspaceId = String(workspaces[targetIndex].id);
        const command = Hyprland.usingLua
            ? `hl.dsp.focus({ workspace = "${workspaceId}" })`
            : "workspace " + workspaceId;
        Hyprland.dispatch(command);
        return { dispatched: true, atBoundary: false };
    }
}

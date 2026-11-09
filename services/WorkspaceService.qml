pragma Singleton

import QtQml
import Quickshell.Hyprland

// Модель десяти workspace и подтверждаемая очередь переноса окон.
QtObject {
    id: service

    readonly property var slotDefinitions: [
        { label: "1", workspaceId: 1, slotId: 1 },
        { label: "2", workspaceId: 2, slotId: 2 },
        { label: "3", workspaceId: 3, slotId: 3 },
        { label: "4", workspaceId: 4, slotId: 4 },
        { label: "5", workspaceId: 5, slotId: 5 },
        { label: "6", workspaceId: 6, slotId: 6 },
        { label: "7", workspaceId: 7, slotId: 7 },
        { label: "8", workspaceId: 8, slotId: 8 },
        { label: "9", workspaceId: 9, slotId: 9 },
        { label: "10", workspaceId: 10, slotId: 0 }
    ]

    readonly property var workspaces: Hyprland.workspaces.values
    readonly property var toplevels: Hyprland.toplevels.values

    function monitorGeometry(monitor) {
        const raw = monitor?.lastIpcObject ?? {};
        const scale = Math.max(0.1, Number(raw.scale ?? monitor?.scale ?? 1));
        const rotated = Number(raw.transform ?? 0) % 2 === 1;
        const width = Number(raw.width ?? monitor?.width ?? 1920);
        const height = Number(raw.height ?? monitor?.height ?? 1080);
        return { x: Number(monitor?.x ?? 0), y: Number(monitor?.y ?? 0),
            width: (rotated ? height : width) / scale,
            height: (rotated ? width : height) / scale };
    }

    function isNormalWorkspace(workspace) {
        if (!workspace || workspace.id <= 0)
            return false;
        const type = String(workspace.lastIpcObject?.type ?? "");
        return type.length === 0 || type === "normal";
    }

    function workspaceForId(workspaceId) {
        return workspaces.find(workspace => workspace.id === workspaceId
            && isNormalWorkspace(workspace)) ?? null;
    }

    function slotsForScreen(screenName) {
        return slotDefinitions.map(definition => {
            const workspace = workspaceForId(definition.workspaceId);
            const monitor = workspace?.monitor ?? null;
            const windows = toplevels.filter(toplevel =>
                toplevel.workspace?.id === definition.workspaceId
                && isNormalWorkspace(toplevel.workspace));

            return {
                label: definition.label,
                slotId: definition.slotId,
                workspaceId: definition.workspaceId,
                workspace: workspace,
                monitor: monitor,
                monitorName: String(monitor?.name ?? ""),
                isOnScreen: monitor?.name === screenName,
                isActive: workspace?.active ?? false,
                windows: windows
            };
        });
    }

    /** Запрашивает переход, а UI закрывается только по focusedWorkspaceChanged. */
    function activateWorkspace(workspaceId) {
        if (!Number.isInteger(workspaceId) || workspaceId < 1 || workspaceId > 10)
            return false;
        const workspace = String(workspaceId);
        const command = Hyprland.usingLua
            ? `hl.dsp.focus({ workspace = "${workspace}" })`
            : "workspace " + workspace;
        Hyprland.dispatch(command);
        return true;
    }

    function normalizedAddress(address) {
        const hex = String(address ?? "").replace(/^0x/i, "");
        return /^[0-9a-f]+$/i.test(hex) ? "0x" + hex.toLowerCase() : "";
    }

    function windowForAddress(address) {
        return toplevels.find(window => normalizedAddress(window.address) === address) ?? null;
    }

    property var moveQueue: []
    property var currentMove: null
    property double moveDeadline: 0
    property string operationError: ""
    property var previewRevisions: ({})
    property var affectedWorkspaces: []
    readonly property bool busy: currentMove !== null || moveQueue.length > 0

    function invalidatePreviews() {
        const next = Object.assign({}, previewRevisions);
        for (const id of affectedWorkspaces) next[id] = (next[id] ?? 0) + 1;
        previewRevisions = next;
        affectedWorkspaces = [];
        Hyprland.refreshToplevels();
    }

    function failMove(message) {
        operationError = message;
        moveQueue = [];
        currentMove = null;
        invalidatePreviews();
    }

    function advanceMove() {
        if (!moveQueue.length) {
            currentMove = null;
            invalidatePreviews();
            return;
        }
        const step = moveQueue[0];
        const window = windowForAddress(step.address);
        if (!window || window.workspace?.id !== step.from) {
            failMove("Перенос остановлен: окно закрыто или уже сменило workspace.");
            return;
        }
        moveQueue = moveQueue.slice(1);
        currentMove = step;
        moveDeadline = Date.now() + 3000;
        const selector = "address:" + step.address;
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.window.move({ window = "${selector}", workspace = "${step.to}", follow = false })`
            : "movetoworkspacesilent " + step.to + "," + selector);
        Hyprland.refreshToplevels();
    }

    function startMoves(steps) {
        if (busy || !steps.length)
            return false;
        operationError = "";
        const affected = [];
        for (const step of steps) {
            if (affected.indexOf(step.from) < 0) affected.push(step.from);
            if (affected.indexOf(step.to) < 0) affected.push(step.to);
        }
        affectedWorkspaces = affected;
        moveQueue = steps;
        advanceMove();
        return true;
    }

    function moveWindow(address, workspaceId) {
        const normalized = normalizedAddress(address);
        const window = windowForAddress(normalized);
        if (!normalized || !window || !Number.isInteger(workspaceId)
            || workspaceId < 1 || workspaceId > 10 || window.workspace?.id === workspaceId)
            return false;
        return startMoves([{ address: normalized, from: window.workspace.id, to: workspaceId }]);
    }

    // Составы фиксируются ДО первой команды; каждое окно переносится один раз.
    // При занятой цели обменивается содержимое; на пустой ID — перенос всего состава.
    function swapWorkspaces(sourceSlot, targetSlot) {
        if (!sourceSlot || !targetSlot || sourceSlot.workspaceId === targetSlot.workspaceId)
            return false;
        const from = sourceSlot.workspaceId;
        const to = targetSlot.workspaceId;
        if (![from, to].every(id => Number.isInteger(id) && id >= 1 && id <= 10))
            return false;
        const steps = toplevels.filter(window => window.workspace?.id === from
            || window.workspace?.id === to).map(window => ({
                address: normalizedAddress(window.address), from: window.workspace.id,
                to: window.workspace.id === from ? to : from
            }));
        return startMoves(steps);
    }

    // Подтверждение живой моделью; очередь переживает закрытие overlay.
    property Timer moveCheck: Timer {
        interval: 100
        running: service.currentMove !== null
        repeat: true
        onTriggered: {
            const step = service.currentMove;
            const window = service.windowForAddress(step.address);
            if (window?.workspace?.id === step.to) {
                service.advanceMove();
            } else if (!window || Date.now() >= service.moveDeadline) {
                service.failMove("Hyprland не подтвердил перенос. Выполненная часть обмена сохранена.");
            } else {
                Hyprland.refreshToplevels();
            }
        }
    }
}

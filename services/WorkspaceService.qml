pragma Singleton

import QtQml
import Quickshell.Hyprland

// Модель десяти workspace и подтверждаемая очередь переноса окон.
QtObject {
    id: service

    readonly property var workspaces: Hyprland.workspaces.values
    readonly property var toplevels: Hyprland.toplevels.values

    // Это именно десять долгоживущих объектов, а не новый JS-массив на
    // каждое IPC-обновление. Repeater благодаря этому сохраняет карточки.
    // Снимками окон отдельно владеет overview через Hyprland.toplevels.
    readonly property QtObject slot1: QtObject {
        readonly property string label: "1"; readonly property int workspaceId: 1; readonly property int slotId: 1
        property var workspace: null; property var monitor: null; property string monitorName: ""; property bool isActive: false; property var windows: []
    }
    readonly property QtObject slot2: QtObject {
        readonly property string label: "2"; readonly property int workspaceId: 2; readonly property int slotId: 2
        property var workspace: null; property var monitor: null; property string monitorName: ""; property bool isActive: false; property var windows: []
    }
    readonly property QtObject slot3: QtObject {
        readonly property string label: "3"; readonly property int workspaceId: 3; readonly property int slotId: 3
        property var workspace: null; property var monitor: null; property string monitorName: ""; property bool isActive: false; property var windows: []
    }
    readonly property QtObject slot4: QtObject {
        readonly property string label: "4"; readonly property int workspaceId: 4; readonly property int slotId: 4
        property var workspace: null; property var monitor: null; property string monitorName: ""; property bool isActive: false; property var windows: []
    }
    readonly property QtObject slot5: QtObject {
        readonly property string label: "5"; readonly property int workspaceId: 5; readonly property int slotId: 5
        property var workspace: null; property var monitor: null; property string monitorName: ""; property bool isActive: false; property var windows: []
    }
    readonly property QtObject slot6: QtObject {
        readonly property string label: "6"; readonly property int workspaceId: 6; readonly property int slotId: 6
        property var workspace: null; property var monitor: null; property string monitorName: ""; property bool isActive: false; property var windows: []
    }
    readonly property QtObject slot7: QtObject {
        readonly property string label: "7"; readonly property int workspaceId: 7; readonly property int slotId: 7
        property var workspace: null; property var monitor: null; property string monitorName: ""; property bool isActive: false; property var windows: []
    }
    readonly property QtObject slot8: QtObject {
        readonly property string label: "8"; readonly property int workspaceId: 8; readonly property int slotId: 8
        property var workspace: null; property var monitor: null; property string monitorName: ""; property bool isActive: false; property var windows: []
    }
    readonly property QtObject slot9: QtObject {
        readonly property string label: "9"; readonly property int workspaceId: 9; readonly property int slotId: 9
        property var workspace: null; property var monitor: null; property string monitorName: ""; property bool isActive: false; property var windows: []
    }
    readonly property QtObject slot10: QtObject {
        readonly property string label: "10"; readonly property int workspaceId: 10; readonly property int slotId: 0
        property var workspace: null; property var monitor: null; property string monitorName: ""; property bool isActive: false; property var windows: []
    }

    // Не заменять этот массив: он является стабильной моделью Grid/Reapter.
    readonly property var slots: [slot1, slot2, slot3, slot4, slot5,
                                  slot6, slot7, slot8, slot9, slot10]

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

    // refreshToplevels() вправе заново обернуть все окна в QML-объекты.
    // Сравнение ссылок в таком случае пересоздавало все десять Repeater-
    // delegate, хотя перенос затрагивает лишь source и target. Адрес окна
    // стабилен в течение его жизни и является нужным ключом модели.
    function sameWindows(left, right) {
        return left.length === right.length
            && left.every((window, index) =>
                normalizedAddress(window.address)
                === normalizedAddress(right[index].address)
                // Один адрес может получить новый Wayland export-handle после
                // переноса. В таком случае обновляем только эту карточку.
                && window.wayland === right[index].wayland);
    }

    function refreshSlots() {
        for (const slot of slots) {
            const workspace = workspaceForId(slot.workspaceId);
            const monitor = workspace?.monitor ?? null;
            const monitorName = String(monitor?.name ?? "");
            const windows = toplevels.filter(toplevel =>
                toplevel.workspace?.id === slot.workspaceId
                && isNormalWorkspace(toplevel.workspace));

            // Извещения получает только слот с фактическим изменением:
            // после переноса — исходный и целевой workspace.
            if (slot.workspace !== workspace) slot.workspace = workspace;
            if (slot.monitor !== monitor) slot.monitor = monitor;
            if (slot.monitorName !== monitorName) slot.monitorName = monitorName;
            if (slot.isActive !== Boolean(workspace?.active))
                slot.isActive = Boolean(workspace?.active);
            if (!sameWindows(slot.windows, windows)) {
                slot.windows = windows;
            }
        }
    }

    // Сохранён для существующих вызовов. Экран больше не участвует в
    // построении модели: monitor привязан к каждому стабильному слоту.
    function slotsForScreen(screenName) {
        return slots;
    }

    onWorkspacesChanged: refreshSlots()
    onToplevelsChanged: refreshSlots()
    Component.onCompleted: refreshSlots()

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
    readonly property bool busy: currentMove !== null || moveQueue.length > 0

    function requestToplevelRefresh() {
        // IPC обновляет метаданные, но не гарантирует готовность screencopy.
        Hyprland.refreshToplevels();
    }

    function failMove(message) {
        operationError = message;
        moveQueue = [];
        currentMove = null;
        requestToplevelRefresh();
    }

    function advanceMove() {
        if (!moveQueue.length) {
            currentMove = null;
            requestToplevelRefresh();
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

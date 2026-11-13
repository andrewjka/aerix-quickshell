pragma Singleton

import QtQml
import Quickshell.Hyprland

// Модель десяти workspace и подтверждаемая очередь переноса окон.
QtObject {
    id: service

    // overview берёт сервис на время жизни (acquire/release). Опрос геометрии
    // по событиям Hyprland выполняется только пока есть хотя бы один потребитель.
    property int consumers: 0
    function acquire() { consumers += 1; }
    function release() { consumers = Math.max(0, consumers - 1); }

    readonly property var workspaces: Hyprland.workspaces.values
    readonly property var toplevels: Hyprland.toplevels.values

    // Геометрия окон стабилизирована после переноса или другого изменения
    // раскладки. Подписчики (overview) перезахватывают кадры именно сейчас.
    signal settled()

    // Слот — долгоживущий объект, его поля workspace/monitor/isActive —
    // привязки (bindings), поэтому они не устаревают при переносе workspace
    // на другой монитор или смене активного. Состав окон обновляется
    // отдельно через refreshSlots(), только при реальном изменении.
    component Slot: QtObject {
        required property var owner
        required property string label
        required property int workspaceId
        required property int slotId

        readonly property var workspace: owner.workspaceForId(workspaceId)
        readonly property var monitor: workspace?.monitor ?? null
        readonly property string monitorName: String(monitor?.name ?? "")
        readonly property bool isActive: Boolean(workspace?.active)
        property var windows: []
    }

    readonly property QtObject slot1: Slot { owner: service; label: "1"; workspaceId: 1; slotId: 1 }
    readonly property QtObject slot2: Slot { owner: service; label: "2"; workspaceId: 2; slotId: 2 }
    readonly property QtObject slot3: Slot { owner: service; label: "3"; workspaceId: 3; slotId: 3 }
    readonly property QtObject slot4: Slot { owner: service; label: "4"; workspaceId: 4; slotId: 4 }
    readonly property QtObject slot5: Slot { owner: service; label: "5"; workspaceId: 5; slotId: 5 }
    readonly property QtObject slot6: Slot { owner: service; label: "6"; workspaceId: 6; slotId: 6 }
    readonly property QtObject slot7: Slot { owner: service; label: "7"; workspaceId: 7; slotId: 7 }
    readonly property QtObject slot8: Slot { owner: service; label: "8"; workspaceId: 8; slotId: 8 }
    readonly property QtObject slot9: Slot { owner: service; label: "9"; workspaceId: 9; slotId: 9 }
    readonly property QtObject slot10: Slot { owner: service; label: "10"; workspaceId: 10; slotId: 0 }

    // Не заменять этот массив: он является стабильной моделью Grid/Repeater.
    readonly property var slots: [slot1, slot2, slot3, slot4, slot5,
                                  slot6, slot7, slot8, slot9, slot10]

    // at/size окон у Hyprland — в логических координатах, поэтому ширина и
    // высота монитора делятся на scale; transform с нечётным значением
    // означает поворот на 90°, и стороны меняются местами.
    function monitorGeometry(monitor) {
        const raw = monitor?.lastIpcObject ?? {};
        const scale = Math.max(0.1, Number(raw.scale ?? monitor?.scale ?? 1));
        const rotated = Number(raw.transform ?? 0) % 2 === 1;
        const width = Number(raw.width ?? monitor?.width ?? 1920);
        const height = Number(raw.height ?? monitor?.height ?? 1080);
        return { x: Number(monitor?.x ?? 0), y: Number(monitor?.y ?? 0),
            width: (rotated ? height : width) / scale,
            height: (rotated ? width : height) / scale,
            scale: scale };
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
    // Сравнение ссылок в таком случае пересоздавало бы все десять Repeater-
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

    // Обновляет только состав окон. workspace/monitor/isActive слотов
    // пересчитываются сами через привязки.
    function refreshSlots() {
        for (const slot of slots) {
            const windows = toplevels.filter(toplevel =>
                toplevel.workspace?.id === slot.workspaceId
                && isNormalWorkspace(toplevel.workspace));
            if (!sameWindows(slot.windows, windows))
                slot.windows = windows;
        }
    }

    // Много источников (по одному на окно) сообщают об одном и том же IPC-
    // обновлении. Сворачиваем их в один проход после текущей пачки изменений.
    property bool syncQueued: false
    function scheduleSync() {
        if (syncQueued)
            return;
        syncQueued = true;
        Qt.callLater(() => {
            service.syncQueued = false;
            service.refreshSlots();
            service.checkCurrentMove();
        });
    }

    // Сохранён для существующих вызовов. Экран больше не участвует в
    // построении модели: monitor привязан к каждому стабильному слоту.
    function slotsForScreen(screenName) {
        return slots;
    }

    onWorkspacesChanged: scheduleSync()
    onToplevelsChanged: scheduleSync()
    Component.onCompleted: refreshSlots()

    // --- Стабилизация геометрии --------------------------------------------
    // Hyprland не шлёт событие об изменении размера окна, а `hyprctl clients`
    // может отдавать текущее (анимируемое) значение. Поэтому после переноса
    // ограниченное по времени число раз перечитываем окна, пока at/size не
    // перестанут меняться, и только потом сообщаем об этом через settled().
    readonly property int settleIntervalMs: 80
    readonly property int settleStableTicks: 3
    readonly property int settleMaxTicks: 25
    // true от начала переноса до стабилизации геометрии: миниатюры в это
    // время не перезахватывают кадры по каждому промежуточному размеру.
    property bool moveSettling: false
    property string settleSignature: ""
    property int settleStable: 0
    property int settleTicks: 0

    property Timer settleTimer: Timer {
        interval: service.settleIntervalMs
        repeat: true
        onTriggered: service.settleTick()
    }

    function geometrySignature() {
        return toplevels.map(window => {
            const raw = window.lastIpcObject ?? {};
            const at = raw.at ?? [];
            const size = raw.size ?? [];
            return normalizedAddress(window.address) + "@" + (window.workspace?.id ?? "")
                + ":" + at[0] + "," + at[1] + "," + size[0] + "," + size[1];
        }).join("|");
    }

    function startSettle(isMove) {
        if (isMove)
            moveSettling = true;
        settleSignature = geometrySignature();
        settleStable = 0;
        settleTicks = 0;
        settleTimer.restart();
        Hyprland.refreshToplevels();
    }

    function settleTick() {
        // Пока выполняется очередь переноса, геометрия не показательна.
        if (busy) {
            settleStable = 0;
            Hyprland.refreshToplevels();
            return;
        }
        settleTicks += 1;
        const signature = geometrySignature();
        if (signature === settleSignature) {
            settleStable += 1;
        } else {
            settleStable = 0;
            settleSignature = signature;
        }
        if (settleStable >= settleStableTicks || settleTicks >= settleMaxTicks) {
            finishSettle();
            return;
        }
        Hyprland.refreshToplevels();
    }

    function finishSettle() {
        settleTimer.stop();
        moveSettling = false;
        settled();
    }

    // События, после которых раскладка окон могла измениться.
    readonly property var geometryEvents: ["movewindowv2", "openwindow", "closewindow",
        "changefloatingmode", "fullscreen"]

    property Connections hyprlandEvents: Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (service.consumers <= 0)
                return;
            if (service.geometryEvents.indexOf(String(event?.name ?? "")) >= 0)
                service.startSettle(false);
        }
    }

    // --- Переносы -------------------------------------------------------------
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
    property string operationErrorKey: ""
    readonly property bool busy: currentMove !== null || moveQueue.length > 0

    // Предохранитель: если Hyprland отклонил dispatch (ошибка Lua, закреплённое
    // окно, правило), очередь не должна блокировать интерфейс навсегда. Сервис —
    // синглтон и переживает закрытие overview.
    readonly property int moveStepTimeoutMs: 2500
    property Timer stepTimer: Timer {
        interval: service.moveStepTimeoutMs
        repeat: false
        onTriggered: service.failMove("overview.moveUnconfirmed")
    }

    function requestToplevelRefresh() {
        // IPC обновляет метаданные, но не гарантирует готовность screencopy.
        Hyprland.refreshToplevels();
    }

    function failMove(errorKey) {
        stepTimer.stop();
        operationErrorKey = errorKey;
        moveQueue = [];
        currentMove = null;
        startSettle(true);
    }

    function advanceMove() {
        if (!moveQueue.length) {
            stepTimer.stop();
            currentMove = null;
            startSettle(true);
            return;
        }
        const step = moveQueue[0];
        const window = windowForAddress(step.address);
        if (!window || window.workspace?.id !== step.from) {
            failMove("overview.moveInterrupted");
            return;
        }
        moveQueue = moveQueue.slice(1);
        currentMove = step;
        stepTimer.restart();
        const selector = "address:" + step.address;
        Hyprland.dispatch(Hyprland.usingLua
            ? `hl.dsp.window.move({ window = "${selector}", workspace = "${step.to}", follow = false })`
            : "movetoworkspacesilent " + step.to + "," + selector);
        Hyprland.refreshToplevels();
    }

    // IPC is the completion hook: dispatch requests a toplevel refresh, and
    // this advances the queue only after the refreshed model changed workspace.
    function checkCurrentMove() {
        if (!currentMove)
            return;
        const window = windowForAddress(currentMove.address);
        if (!window) {
            failMove("overview.moveWindowClosed");
        } else if (window.workspace?.id === currentMove.to) {
            advanceMove();
        }
    }

    function startMoves(steps) {
        if (busy || !steps.length)
            return false;
        operationErrorKey = "";
        moveSettling = true;
        moveQueue = steps;
        advanceMove();
        return true;
    }

    function moveWindow(address, workspaceId) {
        const normalized = normalizedAddress(address);
        const window = windowForAddress(normalized);
        const fromId = window?.workspace?.id;
        if (!normalized || !window || !Number.isInteger(fromId)
            || !Number.isInteger(workspaceId)
            || workspaceId < 1 || workspaceId > 10 || fromId === workspaceId)
            return false;
        return startMoves([{ address: normalized, from: fromId, to: workspaceId }]);
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
        const steps = toplevels.filter(window => window.workspace
            && (window.workspace.id === from || window.workspace.id === to))
            .map(window => ({
                address: normalizedAddress(window.address), from: window.workspace.id,
                to: window.workspace.id === from ? to : from
            }))
            .filter(step => step.address.length > 0);
        return startMoves(steps);
    }

}

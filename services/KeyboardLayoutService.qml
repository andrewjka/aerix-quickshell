pragma Singleton

import QtQml
import Quickshell.Hyprland
import Quickshell.Io
import "../utils/KeyboardLayoutParser.js" as KeyboardLayoutParser

// Единый источник подтверждённого Hyprland состояния раскладки для всех Bar.
QtObject {
    id: service

    readonly property var layoutAbbreviations: ({
        "us": "EN",
        "ru": "RU",
        "ua": "UK",
        "gb": "EN",
        "de": "DE",
        "fr": "FR",
        "es": "ES",
        "it": "IT",
        "pt": "PT",
        "pl": "PL",
        "nl": "NL",
        "se": "SV",
        "no": "NO",
        "fi": "FI",
        "dk": "DA",
        "cz": "CS",
        "sk": "SK",
        "tr": "TR",
        "jp": "JA",
        "kr": "KO"
    })

    property string deviceName: ""
    property string deviceId: ""
    property var layouts: []
    property int activeIndex: -1
    property string error: ""
    // Process.running меняется асинхронно; этот флаг закрывает окно между
    // постановкой query на запуск и фактическим стартом дочернего процесса.
    property bool queryActive: false
    // Событие, пришедшее во время query, будет обработано после его завершения.
    property bool refreshQueued: false
    // Номер поколения увеличивается только при фактическом запуске query.
    // Это позволяет отличить старый ответ от проверки после switchxkblayout.
    property int queryGeneration: 0
    // Intent живёт до свежего подтверждения или ошибки команды.
    property var pendingSelection: null
    property int pendingSelectionToken: 0
    readonly property bool commandPending: layoutCommand.running
        || pendingSelection !== null
    // Пока открыт новый snapshot, старый device нельзя использовать для IPC.
    readonly property bool selectionBlocked: queryActive || commandPending
    readonly property bool available: deviceName.length > 0
        && activeIndex >= 0 && activeIndex < layouts.length
    readonly property string activeLabel: available
        ? String(layouts[activeIndex].label)
        : "??"

    signal layoutSelectionResolved(int token, bool confirmed)

    /** Возвращает короткую подпись только для явно известных XKB-кодов. */
    function abbreviation(layout) {
        return layoutAbbreviations[String(layout ?? "").trim().toLowerCase()] ?? "??";
    }

    /**
     * Дополняет raw-снимок IPC представлением, нужным только виджетам.
     *
     * Проверка JSON находится в KeyboardLayoutParser и не меняет состояние.
     */
    function parseDevices(json) {
        const result = KeyboardLayoutParser.parseDevices(json);
        if (!result.ok)
            return result;

        const snapshot = result.value;

        return {
            ok: true,
            value: {
                deviceName: snapshot.deviceName,
                layouts: snapshot.layouts.map(entry => ({
                    index: entry.index,
                    layout: entry.layout,
                    variant: entry.variant,
                    label: abbreviation(entry.layout),
                    name: entry.variant.length > 0
                        ? `${entry.layout} (${entry.variant})`
                        : entry.layout
                })),
                deviceId: snapshot.deviceId,
                activeIndex: snapshot.activeIndex
            }
        };
    }

    /** Сравнивает только структуру модели, не текущее положение в ней. */
    function hasSameLayoutStructure(snapshot) {
        if (deviceId !== snapshot.deviceId || layouts.length !== snapshot.layouts.length)
            return false;

        for (let i = 0; i < layouts.length; ++i) {
            const current = layouts[i];
            const next = snapshot.layouts[i];
            if (current.index !== next.index
                    || current.layout !== next.layout
                    || current.variant !== next.variant) {
                return false;
            }
        }
        return true;
    }

    /** Публикует только полный прошедший валидацию снимок `hyprctl -j devices`. */
    function updateDevices(json) {
        const result = parseDevices(json);
        if (!result.ok) {
            error = result.error;
            return false;
        }

        const snapshot = result.value;
        if (!hasSameLayoutStructure(snapshot)) {
            deviceId = snapshot.deviceId;
            layouts = snapshot.layouts;
        }
        // Имя нужно обновить отдельно: оно является аргументом IPC-команды,
        // но само по себе не должно пересоздавать неизменную модель.
        deviceName = snapshot.deviceName;
        activeIndex = snapshot.activeIndex;
        error = "";
        return true;
    }

    /**
     * Запрашивает снимок только при запуске или событии Hyprland, без polling.
     * Несколько событий во время одного Process схлопываются в один повторный
     * запрос после onExited.
     */
    function refresh() {
        if (queryActive) {
            refreshQueued = true;
            return;
        }

        queryGeneration += 1;
        queryActive = true;
        devicesQuery.running = true;
    }

    /** Завершает intent только свежим снимком, запрошенным после команды. */
    function resolvePendingSelection(snapshotAccepted) {
        if (pendingSelection === null
                || queryGeneration < pendingSelection.requiredQueryGeneration) {
            return;
        }

        const intent = pendingSelection;
        const confirmed = snapshotAccepted
            && deviceId === intent.deviceId
            && deviceName === intent.deviceName
            && activeIndex === intent.index;
        pendingSelection = null;
        if (!confirmed && snapshotAccepted)
            error = "Раскладка не подтвердилась";
        layoutSelectionResolved(intent.token, confirmed);
    }

    /** Выбирает конкретный индекс XKB без оптимистичного изменения интерфейса. */
    function select(index) {
        if (!available || selectionBlocked || !Number.isInteger(index)
                || index < 0 || index >= layouts.length)
            return false;

        if (index === activeIndex)
            return true;

        error = "";
        pendingSelectionToken += 1;
        pendingSelection = {
            token: pendingSelectionToken,
            deviceId: deviceId,
            deviceName: deviceName,
            index: index,
            // До успешного завершения команды ни один текущий query не может
            // подтвердить intent.
            requiredQueryGeneration: 2147483647
        };
        layoutCommand.exec([
            "hyprctl",
            "switchxkblayout",
            deviceName,
            String(index)
        ]);
        return true;
    }

    property Process devicesQuery: Process {
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            id: devicesOutput
            waitForEnd: true
        }

        onExited: (exitCode, exitStatus) => {
            service.queryActive = false;
            const rerun = service.refreshQueued;
            service.refreshQueued = false;

            let snapshotAccepted = false;
            if (exitCode === 0)
                snapshotAccepted = service.updateDevices(devicesOutput.text);
            else
                service.error = service.available
                    ? "Не удалось обновить состояние клавиатуры"
                    : "Не удалось получить состояние клавиатуры";

            service.resolvePendingSelection(snapshotAccepted);

            // Сначала завершаем обработку текущего ответа, затем draining
            // запускает максимум один накопленный запрос.
            if (rerun)
                service.refresh();
        }
    }

    // Команда одна на все Bar. Пока она работает, повторные клики не создают
    // гонку: интерфейс дождётся актуального события Hyprland.
    property Process layoutCommand: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && service.pendingSelection !== null) {
                const intent = service.pendingSelection;
                // Если query уже шёл, его ответ относится к состоянию до
                // команды. Требуем следующее поколение независимо от этого.
                service.pendingSelection = {
                    token: intent.token,
                    deviceId: intent.deviceId,
                    deviceName: intent.deviceName,
                    index: intent.index,
                    requiredQueryGeneration: service.queryGeneration + 1
                };
                service.refresh();
            } else if (exitCode !== 0 && service.pendingSelection !== null) {
                const token = service.pendingSelection.token;
                service.pendingSelection = null;
                service.error = "Не удалось переключить раскладку";
                service.layoutSelectionResolved(token, false);
            }
        }
    }

    property Connections hyprlandEvents: Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded")
                service.refresh();
        }
    }

    Component.onCompleted: refresh()
}

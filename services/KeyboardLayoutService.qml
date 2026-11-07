pragma Singleton

import QtQml
import Quickshell.Hyprland
import Quickshell.Io

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
    property var layouts: []
    property int activeIndex: -1
    property string error: ""
    readonly property bool commandPending: layoutCommand.running
    readonly property bool available: deviceName.length > 0
        && activeIndex >= 0 && activeIndex < layouts.length
    readonly property string activeLabel: available
        ? String(layouts[activeIndex].label)
        : "??"

    /** Возвращает короткую подпись только для явно известных XKB-кодов. */
    function abbreviation(layout) {
        return layoutAbbreviations[String(layout ?? "").trim().toLowerCase()] ?? "??";
    }

    /** Применяет одно целостное состояние, полученное из `hyprctl -j devices`. */
    function updateDevices(json) {
        let devices;
        try {
            devices = JSON.parse(json);
        } catch (parseError) {
            error = "Hyprland вернул некорректные данные устройств";
            return;
        }

        const keyboards = Array.isArray(devices.keyboards) ? devices.keyboards : [];
        const keyboard = keyboards.find(item => item?.main) ?? keyboards[0] ?? null;
        const codes = String(keyboard?.layout ?? "")
            .split(",")
            .map(code => code.trim())
            .filter(code => code.length > 0);
        const variants = String(keyboard?.variant ?? "").split(",");
        const index = Number(keyboard?.active_layout_index);
        const nextLayouts = codes.map((layout, layoutIndex) => {
            const variant = String(variants[layoutIndex] ?? "").trim();
            return {
                index: layoutIndex,
                layout: layout,
                variant: variant,
                label: abbreviation(layout),
                name: variant.length > 0 ? `${layout} (${variant})` : layout
            };
        });

        deviceName = String(keyboard?.name ?? "");
        layouts = nextLayouts;
        activeIndex = Number.isInteger(index) && index >= 0 && index < nextLayouts.length
            ? index
            : -1;
        error = available ? "" : "Активная раскладка недоступна";
    }

    /** Запрашивает снимок только при запуске или событии Hyprland, без polling. */
    function refresh() {
        if (!devicesQuery.running)
            devicesQuery.running = true;
    }

    /** Выбирает конкретный индекс XKB без оптимистичного изменения интерфейса. */
    function select(index) {
        if (!available || commandPending || !Number.isInteger(index)
                || index < 0 || index >= layouts.length)
            return false;

        if (index === activeIndex)
            return true;

        error = "";
        layoutCommand.exec([
            "hyprctl",
            "switchxkblayout",
            deviceName,
            String(index)
        ]);
        return true;
    }

    property Process devicesQuery: Process {
        id: devicesQuery
        command: ["hyprctl", "-j", "devices"]

        stdout: StdioCollector {
            id: devicesOutput
            waitForEnd: true
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                service.updateDevices(devicesOutput.text);
            else if (!service.available)
                service.error = "Не удалось получить состояние клавиатуры";
        }
    }

    // Команда одна на все Bar. Пока она работает, повторные клики не создают
    // гонку: интерфейс дождётся актуального события Hyprland.
    property Process layoutCommand: Process {
        id: layoutCommand

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                service.refresh();
            else
                service.error = "Не удалось переключить раскладку";
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

pragma Singleton

import QtQml
import Quickshell.Io

// Сервис отделяет DDC/CI-команды от виджетов. `detect --brief` даёт имя
// дисплея и его логический номер, который затем передаётся как `--display`.
QtObject {
    id: service

    property var monitors: []
    property var selectedMonitor: null
    property int brightnessPercent: 50
    property var confirmedBrightnessByDisplay: ({})
    readonly property bool available: monitors.length > 0
    property bool detectionActive: false
    property bool queryActive: false
    property bool refreshQueued: false
    property int queriedDisplay: -1
    property bool setActive: false
    property var queuedSet: null
    property var inFlightSet: null

    function isSelectedMonitor(monitor) {
        return monitor !== null && selectedMonitor !== null
            && monitor.display === selectedMonitor.display;
    }

    function selectMonitor(monitor) {
        if (!monitor || !Number.isInteger(monitor.display))
            return false;
        selectedMonitor = monitor;
        brightnessPercent = confirmedBrightnessFor(monitor.display);
        refresh();
        return true;
    }

    function confirmedBrightnessFor(display) {
        const value = confirmedBrightnessByDisplay[display];
        return Number.isFinite(value) ? value : 50;
    }

    function parseMonitors(text) {
        const monitors = [];
        const blocks = text.trim().split(/\r?\n\s*\r?\n/);
        for (const block of blocks) {
            const display = block.match(/^\s*Display\s+(\d+)\s*$/m);
            const monitor = block.match(/^\s*Monitor:\s*(.+?)\s*$/m);
            if (!display || !monitor)
                continue;

            // Brief output: manufacturer:model:serial. Модель — понятное
            // пользователю реальное имя, остальные части нужны ddcutil лишь
            // как диагностические идентификаторы.
            const parts = monitor[1].split(":");
            const label = (parts.length > 1 ? parts[1] : parts[0]).trim();
            const number = Number(display[1]);
            if (Number.isInteger(number) && label.length > 0)
                monitors.push({ display: number, label: label });
        }
        return monitors;
    }

    function refreshMonitors() {
        if (detectionActive)
            return false;
        detectionActive = true;
        monitorDetection.exec(["ddcutil", "detect", "--brief"]);
        return true;
    }

    function parseBrightness(text) {
        // Terse format: `VCP 10 <type> <current> <maximum>`.
        const match = text.match(/VCP\s+10\s+\S+\s+(\d+)\s+(\d+)/i);
        if (!match)
            return null;

        const current = Number(match[1]);
        const maximum = Number(match[2]);
        if (!Number.isFinite(current) || !Number.isFinite(maximum) || maximum <= 0)
            return null;
        return Math.round(Math.max(0, Math.min(1, current / maximum)) * 100);
    }

    function refresh() {
        if (!selectedMonitor)
            return false;
        if (queryActive) {
            refreshQueued = true;
            return true;
        }

        queriedDisplay = selectedMonitor.display;
        queryActive = true;
        brightnessQuery.exec([
            "ddcutil", "getvcp", "10", "--display", String(queriedDisplay), "--terse"
        ]);
        return true;
    }

    function setBrightnessPercent(percent) {
        if (!selectedMonitor || !Number.isFinite(percent))
            return false;

        const next = Math.round(Math.max(0, Math.min(100, percent)));
        brightnessPercent = next;
        queuedSet = {
            display: selectedMonitor.display,
            percent: next
        };
        runQueuedSet();
        return true;
    }

    function adjustBrightness(deltaPercent) {
        if (!Number.isFinite(deltaPercent))
            return false;
        return setBrightnessPercent(brightnessPercent + deltaPercent);
    }

    function runQueuedSet() {
        if (setActive || queuedSet === null)
            return;

        inFlightSet = queuedSet;
        queuedSet = null;
        setActive = true;
        brightnessSet.exec([
            "ddcutil", "setvcp", "10", String(inFlightSet.percent),
            "--display", String(inFlightSet.display)
        ]);
    }

    property Process monitorDetection: Process {
        stdout: StdioCollector {
            id: detectionOutput
            waitForEnd: true
        }

        onExited: (exitCode, exitStatus) => {
            service.detectionActive = false;
            if (exitCode !== 0) {
                console.warn("brightness: could not detect DDC displays (ddcutil exit "
                    + exitCode + ")");
                return;
            }

            const previousDisplay = service.selectedMonitor?.display;
            const detected = service.parseMonitors(detectionOutput.text);
            service.monitors = detected;
            service.selectedMonitor = detected.find(monitor =>
                monitor.display === previousDisplay) ?? detected[0] ?? null;
            if (service.selectedMonitor)
                service.brightnessPercent = service.confirmedBrightnessFor(
                    service.selectedMonitor.display);
        }
    }

    property Process brightnessQuery: Process {
        stdout: StdioCollector {
            id: brightnessOutput
            waitForEnd: true
        }

        onExited: (exitCode, exitStatus) => {
            service.queryActive = false;
            const rerun = service.refreshQueued;
            service.refreshQueued = false;

            if (exitCode === 0) {
                const value = service.parseBrightness(brightnessOutput.text);
                if (value === null) {
                    console.warn("brightness: ddcutil returned an invalid VCP 10 value");
                } else if (service.selectedMonitor
                        && service.selectedMonitor.display === service.queriedDisplay) {
                    service.confirmedBrightnessByDisplay[service.queriedDisplay] = value;
                    service.brightnessPercent = value;
                }
            } else {
                console.warn("brightness: could not read display "
                    + service.queriedDisplay + " (ddcutil exit " + exitCode + ")");
            }

            if (rerun)
                service.refresh();
        }
    }

    property Process brightnessSet: Process {
        onExited: (exitCode, exitStatus) => {
            const request = service.inFlightSet;
            service.inFlightSet = null;
            service.setActive = false;

            if (exitCode !== 0 && request !== null) {
                console.warn("brightness: could not set display " + request.display
                    + " (ddcutil exit " + exitCode + ")");
                if (service.queuedSet === null && service.selectedMonitor
                        && service.selectedMonitor.display === request.display) {
                    service.brightnessPercent = service.confirmedBrightnessFor(request.display);
                }
            }

            if (service.queuedSet !== null) {
                service.runQueuedSet();
            } else if (request !== null && service.selectedMonitor
                    && service.selectedMonitor.display === request.display) {
                service.refresh();
            }
        }
    }

    Component.onCompleted: refreshMonitors()
}

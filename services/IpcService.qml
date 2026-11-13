pragma Singleton

import QtQml
import Quickshell.Io

// Транспортный слой публичных команд оболочки. Он не владеет UI-состоянием
// и передаёт запросы контроллеру соответствующего виджета.
QtObject {
    id: service

    property IpcHandler handler: IpcHandler {
        target: "aerix.shell"

        function toggleWorkspaceOverview(): void {
            OverviewService.toggle();
        }
    }
}

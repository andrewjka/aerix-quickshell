pragma Singleton

import QtQml
import Quickshell.Io

// Транспортный слой публичных команд оболочки. Он не владеет UI-состоянием:
// shell.qml принимает сигнал и применяет его к соответствующему виджету.
QtObject {
    id: service

    signal workspaceOverviewToggleRequested()

    property IpcHandler handler: IpcHandler {
        target: "aerix.shell"

        function toggleWorkspaceOverview(): void {
            service.workspaceOverviewToggleRequested();
        }
    }
}

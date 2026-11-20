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

        function toggleAppLauncher(): void {
            AppLauncherService.toggle();
        }

        function refreshKeyboardState(): void {
            KeyboardService.refresh();
        }

        function toggleKeyboardCapsLock(): void {
            KeyboardService.noteCapsLockToggle();
        }
    }
}
